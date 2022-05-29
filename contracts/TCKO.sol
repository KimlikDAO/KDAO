//SPDX-License-Identifier: MIT
//🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿

pragma solidity ^0.8.14;

import "./DistroStage.sol";
import "./IDAOKasasi.sol";
import "./IERC20.sol";

// dev.kimlikdao.eth
address constant DEV_KASASI = 0x333Bc913264B6E4a10fd38F30264Ff9c9801176D;
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
 * Inside the contract, we keep track of another variable `distroStage`, which
 * ranges between 0 and 7 inclusive, and can be mapped to the `distroRound` as
 * follows.
 *
 *   distroRound :=  distroStage / 2 + (distroStage == 0 ? 1 : 2)
 *
 * The `distroStage` has 8 values, corresponding to the beginning and the
 * ending of the 5 distribution rounds; see `DistroStage` enum.
 * The `distroStage` can only be incremented, and only by `dev.kimlikdao.eth`
 * by calling the `incrementDistroStage()` method of this contract.
 *
 * In distribution rounds 3 and 4, 20M TCKOs are minted to `kimlikdao.eth`
 * automatically, to be sold / distributed to the public by `kimlikdao.eth`.
 * In the rest of the rounds (1, 2, and 5), the minting is manually managed
 * by `dev.kimlikdao.eth`, however the total minted TCKOs is capped at
 * distroRound * 20M TCKOs at any moment during the lifetime of the contract.
 * Additionally, in round 2, the `presale2Contract` is also given minting
 * rights, again respecting the 20M * distroRound supply cap.
 *
 * Since the `releaseRound` cannot be incremented beyond 5, this ensures that
 * there can be at most 100M TCKOs minted.
 *
 * Locking
 * =======
 * Each mint to external parties results in some unlocked and some locked
 * TCKOs, and the ratio is fixed globally. Only the 40M TCKOs minted to
 * `kimlikdao.eth` across rounds 3 and 4 are fully unlocked.
 *
 * The unlocking schedule is as follows:
 *
 *  /------------------------------------
 *  | Minted in round  |  Unlock time
 *  |------------------------------------
 *  |   Round 1        |  End of round 3
 *  |   Round 2        |  End of round 4
 *  |   Round 3        |  Unlocked
 *  |   Round 4        |  Unlocked
 *  |   Round 5        |  Year 2028
 *
 * Define:
 *   (D1) distroRound := distroStage / 2 + (distroStage == 0 ? 1 : 2)
 *
 * Facts:
 *   (F1) 1 <= distroRound <= 5
 *
 * Invariants:
 *   (I1) supplyCap() <= 20M * 1M * distroRound
 *   (I2) sum_a(balances[a]) + totalBurned == totalMinted
 *   (I3) totalMinted <= supplyCap()
 *   (I4) balances[kilitliTCKO] == kilitliTCKO.totalSupply()
 *
 * (F1) follows because DistroStage has 8 values and floor(7/2) + 2 = 5.
 * Combining (F1) and (I1) gives the 100M TCKO supply cap.
 */
contract TCKO is IERC20 {
    // ERC20 contract for locked TCKOs.
    KilitliTCKO public kilitliTCKO = new KilitliTCKO();
    uint256 public totalMinted;
    uint256 public totalBurned;
    DistroStage public distroStage;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
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
     *   (E1) totalSupply() == sum_a(balances[a])
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
     *   (E2) supplyCap() <= 20M * 1M * distroRound
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
        // Disable sending TCKOs to this contract address, as `rescueToken()` on
        // TCKOs would result in a redemption to this contract, which is *bad*.
        require(to != address(this));
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
        require(to != address(this));
        require(to != address(kilitliTCKO)); // For (I4)
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
     * Mints given number of TCKOs, respecting the supply cap.
     *
     * A fixed locked / unlocked ratio is used across all mints to external
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
        // We need this to satisfy (I4).
        require(account != address(kilitliTCKO));
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
        require(uint256(distroStage) + 1 == uint256(newStage));
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
     * Move ERC20 tokens sent to this address by accident to `DAO_KASASI`.
     */
    function rescueToken(IERC20 token) external {
        // We restrict this method to `DEV_KASASI` only, as we call a method
        // of an unkown contract, which could potentially be a security risk.
        require(tx.origin == DEV_KASASI);
        token.transfer(DAO_KASASI, token.balanceOf(address(this)));
    }
}

/**
 * A KilitliTCKO represents a locked TCKO, which cannot be redeemed or
 * transferred, but turns into a TCKO automatically at the prescribed
 * `DistroStage`.
 *
 * The unlocking is triggered by the `DEV_KASASI` using the `unlockAllEven()`
 * or `unlockAllOdd()` methods and the gas is paid by KimlikDAO; the user does
 * not need to take any action to unlock their tokens.
 *
 * Invariants:
 *   (I1) sum_a(balances[a][0]) + sum_a(balances[a][1]) == supply
 *   (I2) supply == TCKO.balances[kilitliTCKO]
 *   (I3) balance[a][0] > 0 => accounts0.includes(a)
 *   (I4) balance[a][1] > 0 => accounts1.includes(a)
 */
contract KilitliTCKO is IERC20 {
    TCKO private tcko = TCKO(msg.sender);
    mapping(address => uint128[2]) private balances;
    address[] private accounts0;
    // Split Presale2 accounts out, so that even if we can't unlock them in
    // one shot due to gas limit, we can still unlock others in one shot.
    address[] private accounts1;
    uint256 private supply;

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

    function transfer(address to, uint256) external override returns (bool) {
        if (to == address(this))
            return unlock(msg.sender);
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

    function unlock(address account) public returns (bool) {
        DistroStage stage = tcko.distroStage();
        uint256 locked = 0;
        if (stage >= DistroStage.DAOSaleEnd && stage != DistroStage.FinalMint) {
            locked += balances[account][0];
            delete balances[account][0];
        }
        if (stage >= DistroStage.Presale2Unlock) {
            locked += balances[account][1];
            delete balances[account][1];
        }
        if (locked > 0) {
            emit Transfer(account, address(this), locked);
            supply -= locked;
            tcko.transfer(account, locked);
            return true;
        }
        return false;
    }

    function unlockAllEven() external {
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
                tcko.transfer(account, locked);
            }
        }
    }

    function unlockAllOdd() external {
        require(tcko.distroStage() >= DistroStage.Presale2Unlock);

        uint256 length = accounts1.length;
        for (uint256 i = 0; i < length; ++i) {
            address account = accounts1[i];
            uint256 locked = balances[account][1];
            if (locked > 0) {
                delete balances[account][1];
                emit Transfer(account, address(this), locked);
                supply -= locked;
                tcko.transfer(account, locked);
            }
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
