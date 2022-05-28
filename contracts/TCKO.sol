//SPDX-License-Identifier: MIT
//🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿

pragma solidity ^0.8.14;

import "./DistroStage.sol";
import "./IDAOKasasi.sol";
import "./IERC20.sol";

// dev.kimlikdao.eth
address payable constant DEV_KASASI = payable(
    0x333Bc913264B6E4a10fd38F30264Ff9c9801176D
);
// kimlikdao.eth
address payable constant DAO_KASASI = payable(
    0xC152e02e54CbeaCB51785C174994c2084bd9EF51
);

/**
 * @title TCKO: KimlikDAO governance token
 *
 * Utility
 * =======
 * 1 TCKO represents a share of all assets of the KimlikDAO treasury located
 * at `kimlikdao.eth` and 1 voting right for all treasury investment decisions.
 *
 * Any TCKO holder can redeem their share of the DAO treasury assets by
 * transferring their TCKOs to `kimlikdao.eth` on Avalanche C-chain. Such a
 * transfer burns the transferred TCKOs and sends the redeemer their share of
 * the treasury. The share of the redeemer is `sentAmount / totalSupply()`
 * fraction of all the ERC20 tokens and AVAX the treasury has.
 * Note however that the market value TCKO is ought to be higher than the
 * redemption amount, as TCKO represents a share in KimlikDAO's future cash
 * flow as well. The redemption amount is merely a lower bound on TCKOs value
 * and this functionality should only be used only as a last resort.
 *
 * Investment decisions are made through proposals to swap some treasury assets
 * to other assets on a DEX, which are voted on-chain by all TCKO holders.
 *
 * Combined with a TCKT, TCKO gives a person voting rights for non-financial
 * decisions of KimlikDAO also; however in such decisions the voting weight is
 * not necessarily proportional to one's TCKO holdings (guaranteed to be
 * sub-linear in one's TCKO holdings). Since TCKT is an ID token, it allows us
 * to enforce the sub-linear voting weight.
 *
 * Supply Cap
 * ==========
 * There will be 100M TCKOs minted ever, distributed over 5 rounds of 20M TCKOs
 * each.
 *
 * The current distribution stage is stored at the public variable
 * `distroStage`, which can only be incremented. It can only be incremented
 * by the address `dev.kimlikdao.eth` by calling the `incrementDistroStage()`
 * method of this contract.
 *
 * In distribution stages 3 and 4, 20M TCKOs are minted to `kimlikdao.eth`
 * automatically, to be sold / distributed to the public by `kimlikdao.eth`.
 * In the rest of the stages (1, 2, and 5), the minting is manually managed
 * by `dev.kimlikdao.eth`, however the total minted TCKOs is capped at
 * distroStage * 20M TCKOs at any moment during the lifetime of the contract.
 *
 * Since the `releaseStage` cannot be incremented beyond 5, this ensures that
 * there can be at most 100M TCKOs minted.
 *
 * Further, each manual mint results in some unlocked and some locked TCKOs,
 * and the ratio is fixed globally.
 *
 * Invariants:
 *   (I1) supplyCap() <= 100M * 1M
 *   (I2) sum_a(balances[a]) + totalBurned == totalMinted
 *   (I3) totalMinted <= supplyCap()
 *   (I4) balances[kilitliTCKO] == kilitliTCKO.totalSupply()
 */
contract TCKO is IERC20 {
    // ERC20 contract for locked TCKOs.
    KilitliTCKO kilitliTCKO = new KilitliTCKO();
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    uint256 public totalMinted;
    uint256 public totalBurned;
    DistroStage public distroStage;

    function name() external pure override returns (string memory) {
        return "KimlikDAO Tokeni";
    }

    function symbol() external pure override returns (string memory) {
        return "TCKO";
    }

    function decimals() external pure override returns (uint8) {
        return 6;
    }

    /**
     * Returns the total number of TCKOs in existence, locked or unlocked.
     *
     * Ensures:
     *   totalSupply() == sum_a(balances)
     */
    function totalSupply() external view override returns (uint256) {
        unchecked {
            return totalMinted - totalBurned;
        }
        // (I2) => sum_a(balances) = totalMinted - totalBurned
    }

    /**
     * Returns the max number of TCKOs that can be minted at the current stage.
     *
     * Ensures:
     *   supplyCap() <= 100M * 1M
     */
    function supplyCap() public view returns (uint256) {
        unchecked {
            uint256 stage = uint256(distroStage);
            uint256 cap = 20_000_000 *
                1_000_000 *
                (stage / 2 + (stage == 0 ? 1 : 2));
            return cap;
        }
        //    stage <= 7
        // => (sage / 2 + (stage == 0 ? 1 : 2) <= 5
        // => cap <= 100M * 1M * 5
        // => (I1)
    }

    function balanceOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return balances[account];
    }

    function transfer(address to, uint256 amount)
        external
        override
        returns (bool)
    {
        // Disable sending to the 0 address, which is a common software / ui
        // caused mistake.
        require(to != address(0));
        // We disallow sending to `kilitliTCKO` as we want to enforce (I4)
        // at all times.
        require(to != address(kilitliTCKO));
        uint256 fromBalance = balances[msg.sender];
        require(amount <= fromBalance);

        unchecked {
            balances[msg.sender] = fromBalance - amount;
            // If sent to `DAO_KASASI`, the tokens are burned and the portion
            // of the treasury is sent back to the msg.sender (i.e., redeemed).
            // The redemption amount is `amount / totalSupply()` of all
            // treasury assets.
            if (to == DAO_KASASI) {
                IDAOKasasi(DAO_KASASI).redeem(
                    msg.sender,
                    amount,
                    totalMinted - totalBurned
                );
                totalBurned += amount;
            } else {
                balances[to] += amount;
            }
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {
        require(to != address(0));
        require(to != address(kilitliTCKO));
        uint256 fromBalance = balances[from];
        require(amount <= fromBalance);
        uint256 senderAllowance = allowances[from][msg.sender];
        require(amount <= senderAllowance);

        unchecked {
            balances[from] = fromBalance - amount;
            allowances[from][msg.sender] = senderAllowance - amount;
            if (to == DAO_KASASI) {
                IDAOKasasi(DAO_KASASI).redeem(
                    from,
                    amount,
                    totalMinted - totalBurned
                );
                totalBurned += amount;
            } else {
                balances[to] += amount;
            }
        }
        emit Transfer(from, to, amount);
        return true;
    }

    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        external
        override
        returns (bool)
    {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedAmount)
        external
        returns (bool)
    {
        uint256 newAmount = allowances[msg.sender][spender] + addedAmount; // Checked addition
        allowances[msg.sender][spender] = newAmount;
        emit Approval(msg.sender, spender, newAmount);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedAmount)
        external
        returns (bool)
    {
        uint256 newAmount = allowances[msg.sender][spender] - subtractedAmount; // Checked subtraction
        allowances[msg.sender][spender] = newAmount;
        emit Approval(msg.sender, spender, newAmount);
        return true;
    }

    /**
     * Mints given number of TCKOs, respecting the supply cap
     *
     * A fixed locked / unlocked ratio is used across mints to all external
     * participants.
     *
     * To mint TCKOs to `DAO_KASASI`, a separate code path is used, in which
     * all TCKOs are unlocked.
     */
    function mint(address account, uint256 amount) external {
        require(tx.origin == DEV_KASASI);
        require(totalMinted + amount <= supplyCap()); // Checked addition
        unchecked {
            uint256 unlocked = amount / 4;
            uint256 locked = amount - unlocked;
            totalMinted += amount;
            balances[account] += unlocked;
            balances[address(kilitliTCKO)] += locked;
            emit Transfer(address(this), account, unlocked);
            emit Transfer(address(this), address(kilitliTCKO), locked);
            kilitliTCKO.mint(account, locked, distroStage);
        }
    }

    function whitelistMint(address account, uint256 amount) external {
        require(distroStage == DistroStage.Presale2);
    }

    /**
     * Requires:
     *   (R1) toUnlock <= kilitliTCKO.totalSupply()
     */
    function unlockToAddress(address account, uint256 toUnlock) external {
        require(msg.sender == address(kilitliTCKO));
        unchecked {
            balances[address(kilitliTCKO)] -= toUnlock;
            balances[account] += toUnlock;
        }
        emit Transfer(address(this), account, toUnlock);
    }

    /**
     * Advance the distribution stage.
     *
     * If we've advanced to DAOSaleStart stage or DAOAMMStart stage,
     * automatically mint 20M unlocked TCKOs to `DAO_KASASI`.
     *
     * @param newStage value to double check to prevent user error.
     */
    function incrementDistroStage(DistroStage newStage) external {
        require(tx.origin == DEV_KASASI);
        // When we are already at the final stage, try to get rid of the
        // kilitliTCKO contract, which goes through if all the locked tokens
        // have been unlocked.
        if (distroStage == DistroStage.FinalMint) {
            kilitliTCKO.selfDestruct();
            return;
        }
        // Ensure the user provided round number matches, to prevent user error.
        require(uint8(distroStage) + 1 == uint8(newStage));
        // Make sure all minting has been done for the current stage
        require(
            supplyCap() == totalMinted,
            "TCKO: All allowed cap must be minted."
        );
        // Ensure that we cannot go to FinalUnlock before 2028.
        if (newStage == DistroStage.FinalUnlock) {
            require(block.timestamp > 1832306400);
        }

        distroStage = newStage;

        if (
            distroStage == DistroStage.DAOSaleStart ||
            distroStage == DistroStage.DAOAMMStart
        ) {
            // Mint 20M TCKOs to `DAO_KASASI` bypassing the standard locked
            // ratio.
            unchecked {
                uint256 amount = 20_000_000 * 1_000_000;
                totalMinted += amount;
                balances[DAO_KASASI] += amount;
                emit Transfer(address(this), DAO_KASASI, amount);
            }
        }
        IDAOKasasi(DAO_KASASI).distroStageUpdated(newStage);
    }

    /**
     * @dev Move ERC20 tokens sent to this address by accident to `DAO_KASASI`
     */
    function rescueToken(IERC20 token) external {
        // We restrict this method to `DEV_KASASI` only, as we call a method of an unkown
        // contract, which could potentially be a security risk.
        require(tx.origin == DEV_KASASI);
        token.transfer(DAO_KASASI, token.balanceOf(address(this)));
    }
}

/**
 * A KilitliTCKO represents a locked TCKO, which cannot be redeemed or
 * transferred, but automatically turns into a TCKO at the prescribed
 * `DistroStage`.
 *
 * The unlocking is triggered by the TCKO `incrementDistroStage()`
 * method and the gas is paid by KimlikDAO; the user does not need
 * to take any action to unlock their tokens.
 *
 * Invariants:
 *   (I1) sum_a(balances[a][0]) == total[0]
 *   (I2) sum_a(balances[a][1]) == total[1]
 *   (I3) total[0] < type(uint128).max
 *   (I4) total[1] < type(uint128).max
 *   (I5) balance[a][0] > 0 => addresses[0].includes(a)
 *   (I6) balance[a][1] > 0 => addresses[1].includes(a)
 */
contract KilitliTCKO is IERC20 {
    mapping(address => uint128[2]) private balances;
    address[] private accounts0;
    // Split Presale2 accounts out, so that even if we can't unlock them in
    // one shot due to gas limit, we can still unlock others in one-shot.
    address[] private accounts1;
    uint256 private supply;
    TCKO private tcko = TCKO(msg.sender);

    function name() external pure override returns (string memory) {
        return "KimlikDAO Kilitli Tokeni";
    }

    function symbol() external pure override returns (string memory) {
        return "TCKO-k";
    }

    function decimals() external pure override returns (uint8) {
        return 6;
    }

    function totalSupply() external view override returns (uint256) {
        return supply;
    }

    function balanceOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return balances[account][0] + balances[account][1];
    }

    function transfer(address, uint256) external pure override returns (bool) {
        return false;
    }

    function transferFrom(
        address,
        address,
        uint256
    ) external pure override returns (bool) {
        return false;
    }

    function allowance(address, address)
        external
        pure
        override
        returns (uint256)
    {
        return 0;
    }

    function approve(address, uint256) external pure override returns (bool) {
        return false;
    }

    /**
     * Requires:
     *   (R1) total[0] + total[1] + amount <= 100M * 1M
     * Ensures:
     *   (E1) balance[account][uint8(stage) & 1] ==
     *       old(balance[account][uint8(stage) & 1]) + amount
     */
    function mint(
        address account,
        uint256 amount,
        DistroStage stage
    ) external {
        require(msg.sender == address(tcko));
        unchecked {
            if (uint256(stage) & 1 == 0) {
                accounts0.push(account);
                balances[account][0] += uint128(amount);
            } else {
                accounts1.push(account);
                balances[account][1] += uint128(amount);
            }
            supply += amount;
            emit Transfer(address(this), account, amount);
        }
        // (R1) & (B) & (C) => (I1)
        // (R1) & (C) => (I2)
        // (B) & (A) => (I3) & (I4)
        // (R1) & (B) => (E1)
    }

    /**
     * Unlocks all TCKO-k's minted at a stage of the same parity as `stage`.
     *
     * The parity condition is a result of a gas optimization; this method can
     * only be called from the TCKO contract, which is considerate of this
     * parity optimization.
     *
     * In the unlikely case where this method fails due to gas limit, we'll
     * ask TCKO-k holders to unlock their tokens themselves via the `unlock()`
     * method, which will reduce the gas consumption of the present method.
     *
     * Ensures:
     *   (E2) sum_a(balances[a][uint8(stage) & 1]) == 0
     *   (E3) old(balances[a][uint8(stage) & 1]) + old(tcko.balances[a]) ==
     *       balances[a][uint8(stage) & 1] + tcko.balances[a]
     */
    function unlockAllOdd() external {
        require(tx.origin == DEV_KASASI);

        uint256 length = accounts1.length;
        for (uint256 i = 0; i < length; ++i) {
            address account = accounts1[i];
            uint256 locked = balances[account][1]; // (A)
            if (locked > 0) {
                delete balances[account][1]; // (B)
                emit Transfer(account, address(this), locked); // (C)
                supply -= locked; // (D)
                tcko.unlockToAddress(account, locked); // (E)
            }
        }
        // (I2) & (A) & (B) & (D) => (I1)
        // (I2) => (I2)
        // (I3) => (I3)
        // (I4) => (I4)
        // (I3) & (I4) & (A) & (B) => (E2)
        // (A) & (B) & (E) => (E3)
    }

    function unlockAllEven() external {
        require(tx.origin == DEV_KASASI);

        uint256 length = accounts0.length;
        for (uint256 i = 0; i < length; ++i) {
            address account = accounts0[i];
            uint256 locked = balances[account][0]; // (A)
            if (locked > 0) {
                delete balances[account][0]; // (B)
                emit Transfer(account, address(this), locked); // (C)
                supply -= locked; // (D)
                tcko.unlockToAddress(account, locked); // (E)
            }
        }
        // (I2) & (A) & (B) & (D) => (I1)
        // (I2) => (I2)
        // (I3) => (I3)
        // (I4) => (I4)
        // (I3) & (I4) & (A) & (B) => (E2)
        // (A) & (B) & (E) => (E3)
    }

    /**
     * Ensures:
     *   (E4) old(balance[msg.sender][0]) + old(balance[msg.sender][1])
     *       old(tcko.balance[msg.sender]) == balance[msg.sender][0]
     *       + balance[msg.sender][1] + tcko.balance[msg.sender]
     */
    function unlock() external {
        DistroStage stage = tcko.distroStage();
        uint128 locked = 0;
        if (stage >= DistroStage.DAOSaleEnd && stage != DistroStage.FinalMint) {
            locked += balances[msg.sender][0]; // (A)
            delete balances[msg.sender][0]; // (B)
        }

        if (stage >= DistroStage.Presale2Unlock) {
            locked += balances[msg.sender][1]; // (C)
            delete balances[msg.sender][1]; // (D)
        }
        if (locked > 0) {
            emit Transfer(msg.sender, address(this), locked);
            supply -= locked; // (E)
            tcko.unlockToAddress(msg.sender, locked); // (F)
        }
        // (I2) & (A) & (B) & (C) & (D) & (E) => (I1)
        // (I2) => (I2)
        // (I3) => (I3)
        // (I4) => (I4)
        // (I2) & (A) & (B) & (C) & (D) & (F) => (E4)
    }

    function selfDestruct() external {
        // We restrict this method to `DEV_KASASI` as there may be ERC20 tokens
        // send to this contract by accident, waiting to be rescued.
        require(tx.origin == DEV_KASASI);
        require(supply == 0);
        selfdestruct(DAO_KASASI);
    }

    /**
     * Move ERC20 tokens sent to this address by accident to `DAO_KASASI`
     */
    function rescueToken(IERC20 token) external {
        // We restrict this method to `DEV_KASASI` only, as we call a method of an unkown
        // contract, which could potentially be a security risk.
        require(tx.origin == DEV_KASASI);
        // Disable sending out TCKO to ensure the invariant TCKO.(I4).
        require(token != tcko);
        token.transfer(DAO_KASASI, token.balanceOf(address(this)));
    }
}
