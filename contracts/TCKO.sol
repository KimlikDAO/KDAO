//SPDX-License-Identifier: MIT
//🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿

pragma solidity ^0.8.0;

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
 * There will be 100M TCKOs minted ever, distributed over 5 stages of 20M TCKOs
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

    function totalSupply() external view override returns (uint256) {
        unchecked {
            return totalMinted - totalBurned;
        }
    }

    function supplyCap() public view returns (uint256) {
        unchecked {
            uint256 cap = 20_000_000 *
                1_000_000 *
                (uint8(distroStage) / 2 + ((uint8(distroStage) == 0) ? 1 : 2));
            // The maximum supply cap ever is 100M TCKOs.
            // The following assert is always true and included here for ease of
            // verification of this fact.
            assert(cap <= 100_000_000 * 1_000_000);
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

    /**
     * Invariant:
     *     sum(balances) + kilitliTCKO.totalSupply() + totalBurned == totalMinted
     */
    function transfer(address to, uint256 amount)
        external
        override
        returns (bool)
    {
        require(to != address(0));
        uint256 senderBalance = balances[msg.sender];
        require(amount <= senderBalance); // (1)

        unchecked {
            balances[msg.sender] = senderBalance - amount; //  amount <=(1) senderBalance
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
                totalBurned += amount; // amount <=(1) senderBalance <= 100M * 1M.
            } else {
                balances[to] += amount; // amount <=(1) senderBalance <= 100M * 1M.
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
        uint256 fromBalance = balances[from];
        require(amount <= fromBalance); // (1)
        uint256 senderAllowance = allowances[from][msg.sender];
        require(amount <= senderAllowance);

        unchecked {
            balances[from] = fromBalance - amount; // amount <= fromBalance (1)
            allowances[from][msg.sender] = senderAllowance - amount;
            if (to == DAO_KASASI) {
                IDAOKasasi(DAO_KASASI).redeem(
                    from,
                    amount,
                    totalMinted - totalBurned
                );
                totalBurned += amount; // amount <=(1) fromBalance <= 100M * 1M.
            } else {
                balances[to] += amount; // amount <=(1) fromBalance <= 100M * 1M.
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
     * @dev Mints given number of TCKOs, respecting the supply cap
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
            kilitliTCKO.mint(account, locked, distroStage);
            emit Transfer(address(this), account, unlocked);
        }
    }

    function unlockToAddress(address account, uint256 toUnlock) external {
        require(msg.sender == address(kilitliTCKO));
        unchecked {
            balances[account] += toUnlock; // balances[account] + toUnlock <= 100M * 1M.
        }
        emit Transfer(address(this), account, toUnlock);
    }

    /**
     * @dev Advance the distribution stage
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

        unchecked {
            distroStage = newStage;

            if (
                distroStage == DistroStage.DAOSaleStart ||
                distroStage == DistroStage.DAOAMMStart
            ) {
                // Mint 20M TCKOs to `DAO_KASASI` bypassing the standard locked
                // ratio.
                uint256 amount = 20_000_000 * 1_000_000;
                totalMinted += amount;
                balances[DAO_KASASI] += amount;
                emit Transfer(address(this), DAO_KASASI, amount);
            } else if (distroStage == DistroStage.DAOSaleEnd) {
                // At stage DAOSaleEnded, Presale1 tokens are fully unlocked.
                kilitliTCKO.unlockStage(DistroStage.Presale1);
            } else if (distroStage == DistroStage.Presale2Unlock) {
                // At stage Presale2Unlocked, Presale2 tokens are fully unlocked.
                kilitliTCKO.unlockStage(DistroStage.Presale2);
            } else if (distroStage == DistroStage.FinalUnlock) {
                // The last stage is unlocked in 2028
                require(block.timestamp > 1832306400);
                // At stage FinalUnlock, FinalMint tokens (therefore all locked
                // tokens) are fully unlocked.
                kilitliTCKO.unlockStage(DistroStage.FinalMint);
                // The KilitliTCKO contract is no longer needed, therefore
                // we delete it.
                kilitliTCKO.selfDestruct();
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
 *   (I1) sum_a(balances[a][0]) + sum_a(balances[a][1]) == totalLocked
 *   (I2) totalLocked <= 100M * 1M < type(uint128).max
 *   (I3) balance[a][0] > 0 => addresses.includes(a)
 *   (I4) balance[a][1] > 0 => addresses.includes(a)
 */
contract KilitliTCKO is IERC20 {
    mapping(address => uint128[2]) private balances;
    uint256 totalLocked;
    address[] private addresses;
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
        return totalLocked;
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
     *   (R1) totalLocked + amount <= 100M * 1M
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
        addresses.push(account); // (A)
        unchecked {
            balances[account][uint256(stage) & 1] += uint128(amount); // (B)
            totalLocked += amount; // (C)
            // (R1) & (B) & (C) => (I1)
            // (R1) & (C) => (I2)
            // (B) & (A) => (I3) & (I4)
            // (R1) & (B) => (E1)
        }
        emit Transfer(address(this), account, amount);
    }

    /**
     * Ensures:
     *   (E2) sum_a(balances[a][uint8(stage) & 1]) == 0
     *   (E3) old(balances[a][uint8(stage) & 1]) + old(tcko.balances[a]) ==
     *       balances[a][uint8(stage) & 1] + tcko.balances[a]
     */
    function unlockStage(DistroStage stage) external {
        require(msg.sender == address(tcko));
        uint256 length = addresses.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 locked = balances[addresses[i]][uint8(stage) & 1]; // (A)
            if (locked > 0) {
                delete balances[addresses[i]][uint8(stage) & 1]; // (B)
                emit Transfer(addresses[i], address(this), locked); // (C)
                totalLocked -= locked; // (D)
                tcko.unlockToAddress(addresses[i], locked); // (E)
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
        if (
            stage >= DistroStage.DAOSaleEnd && stage != DistroStage.FinalMint
        ) {
            locked += balances[msg.sender][0]; // (A)
            delete balances[msg.sender][0]; // (B)
        }

        if (stage >= DistroStage.Presale2Unlock) {
            locked += balances[msg.sender][1]; // (C)
            delete balances[msg.sender][1]; // (D)
        }
        if (locked > 0) {
            emit Transfer(msg.sender, address(this), locked);
            totalLocked -= locked; // (E)
            tcko.unlockToAddress(msg.sender, locked); // (F)
        }
        // (I2) & (A) & (B) & (C) & (D) & (E) => (I1)
        // (I2) => (I2)
        // (I3) => (I3)
        // (I4) => (I4)
        // (I2) & (A) & (B) & (C) & (D) & (F) => (E4)
    }

    function selfDestruct() external {
        require(msg.sender == address(tcko));
        require(totalLocked == 0);
        selfdestruct(DAO_KASASI);
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
