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
 * Define:
 *   (D1) distroRound := distroStage / 2 + (distroStage == 0 ? 1 : 2)
 *
 * Invariants:
 *   (I1) distroRound <= 5
 *   (I2) supplyCap() <= 20M * 1M * distroRound
 *   (I3) sum_a(balances[a]) + totalBurned == totalMinted
 *   (I4) totalMinted <= supplyCap()
 *   (I5) balances[kilitliTCKO] == kilitliTCKO.totalSupply()
 */
contract TCKO is IERC20 {
    // ERC20 contract for locked TCKOs.
    KilitliTCKO kilitliTCKO = new KilitliTCKO();
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    uint256 public totalMinted;
    uint256 public totalBurned;
    DistroStage public distroStage;
    address private presale2Contract;

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
     *   totalSupply() == sum_a(balances[a])
     */
    function totalSupply() external view override returns (uint256) {
        unchecked {
            return totalMinted - totalBurned;
        }
    }

    /**
     * Returns the max number of TCKOs that can be minted at the current stage.
     *
     * Ensures:
     *   supplyCap() <= 20M * 1M * distroRound
     *
     * Recall that distroRound := distroStage / 2 + distroStage == 0 ? 1 : 2,
     * so combined with distroRound <= 5, we get 100M TCKO supply cap.
     */
    function supplyCap() public view returns (uint256) {
        unchecked {
            uint256 stage = uint256(distroStage);
            uint256 cap = 20_000_000 *
                1_000_000 *
                (stage / 2 + (stage == 0 ? 1 : 2));
            return cap;
        }
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
        // Disable sending to the 0 address, which is a common software / user
        // error.
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

    function unlockToAddress(address account, uint256 toUnlock) external {
        require(msg.sender == address(kilitliTCKO));
        unchecked {
            balances[address(kilitliTCKO)] -= toUnlock;
            balances[account] += toUnlock;
        }
        emit Transfer(address(this), account, toUnlock);
    }

    /**
     * Mints given number of TCKOs, respecting the supply cap.
     *
     * A fixed locked / unlocked ratio is used across mints to all external
     * participants.
     *
     * To mint TCKOs to `DAO_KASASI`, a separate code path is used, in which
     * all TCKOs are unlocked.
     */
    function mint(address account, uint256 amount) external {
        require(
            tx.origin == DEV_KASASI ||
                (distroStage == DistroStage.Presale2 &&
                    msg.sender == presale2Contract)
        );
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

    function setPresale2Contract(address addr) external {
        require(tx.origin == DEV_KASASI);
        presale2Contract = addr;
    }

    /**
     * Advances the distribution stage.
     *
     * If we've advanced to DAOSaleStart stage or DAOAMMStart stage,
     * automatically mints 20M unlocked TCKOs to `DAO_KASASI`.
     *
     * @param newStage value to double check to prevent user error.
     */
    function incrementDistroStage(DistroStage newStage) external {
        require(tx.origin == DEV_KASASI);
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
            newStage == DistroStage.DAOSaleStart ||
            newStage == DistroStage.DAOAMMStart
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
     * Move ERC20 tokens sent to this address by accident to `DAO_KASASI`
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
 * The unlocking is triggered by the `DEV_KASASI` using the `unlockAllOdd()`
 * method and the gas is paid by KimlikDAO; the user does not need
 * to take any action to unlock their tokens.
 *
 * Invariants:
 *   (I1) sum_a(balances[a][0]) + sum_a(balances[a][1]) == supply
 *   (I2) supply == TCKO.balances[kilitliTCKO]
 *   (I3) balance[a][0] > 0 => accounts0.includes(a)
 *   (I4) balance[a][1] > 0 => accounts1.includes(a)
 */
contract KilitliTCKO is IERC20 {
    mapping(address => uint128[2]) private balances;
    address[] private accounts0;
    // Split Presale2 accounts out, so that even if we can't unlock them in
    // one shot due to gas limit, we can still unlock others in one shot.
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
    }

    function unlockAllEven() external {
        require(tx.origin == DEV_KASASI);
        DistroStage stage = tcko.distroStage();
        require(
            stage >= DistroStage.DAOSaleEnd && stage != DistroStage.FinalMint
        );

        uint256 length = accounts0.length;
        for (uint256 i = 0; i < length; ++i) {
            address account = accounts0[i];
            uint256 locked = balances[account][0];
            if (locked > 0) {
                delete balances[account][0];
                emit Transfer(account, address(this), locked);
                supply -= locked;
                tcko.unlockToAddress(account, locked);
            }
        }
    }

    function unlockAllOdd() external {
        require(tx.origin == DEV_KASASI);
        require(tcko.distroStage() >= DistroStage.Presale2Unlock);

        uint256 length = accounts1.length;
        for (uint256 i = 0; i < length; ++i) {
            address account = accounts1[i];
            uint256 locked = balances[account][1];
            if (locked > 0) {
                delete balances[account][1];
                emit Transfer(account, address(this), locked);
                supply -= locked;
                tcko.unlockToAddress(account, locked);
            }
        }
    }

    function unlock() external {
        DistroStage stage = tcko.distroStage();
        uint128 locked = 0;
        if (stage >= DistroStage.DAOSaleEnd && stage != DistroStage.FinalMint) {
            locked += balances[msg.sender][0];
            delete balances[msg.sender][0];
        }
        if (stage >= DistroStage.Presale2Unlock) {
            locked += balances[msg.sender][1];
            delete balances[msg.sender][1];
        }
        if (locked > 0) {
            emit Transfer(msg.sender, address(this), locked);
            supply -= locked;
            tcko.unlockToAddress(msg.sender, locked);
        }
    }

    /**
     * Deletes the contract if all TCKO-k's have been unlocked.
     */
    function selfDestruct() external {
        // We restrict this method to `DEV_KASASI` as there may be ERC20 tokens
        // sent to this contract by accident waiting to be rescued.
        require(tx.origin == DEV_KASASI);
        require(supply == 0);
        selfdestruct(DAO_KASASI);
    }

    /**
     * Moves ERC20 tokens sent to this address by accident to `DAO_KASASI`.
     */
    function rescueToken(IERC20 token) external {
        // We restrict this method to `DEV_KASASI` only, as we call a method
        // of an unkown contract, which could potentially be a security risk.
        require(tx.origin == DEV_KASASI);
        // Disable sending out TCKO to ensure the invariant TCKO.(I4).
        require(token != tcko);
        token.transfer(DAO_KASASI, token.balanceOf(address(this)));
    }
}
