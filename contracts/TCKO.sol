// SPDX-License-Identifier: MIT
// 🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿

pragma solidity 0.8.17;

import "./KilitliTCKO.sol";
import "interfaces/Addresses.sol";
import "interfaces/DistroStage.sol";
import "interfaces/IDAOKasasi.sol";
import "interfaces/IERC20Permit.sol";

/**
 * @title TCKO: KimlikDAO Token
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
 * Note however that the market value of TCKO is ought to be higher than the
 * redemption amount, as TCKO represents a share in KimlikDAO's future cash
 * flow as well. The redemption amount is merely a lower bound on TCKOs value
 * and this functionality should only be used as a last resort.
 *
 * Investment decisions are made through proposals to swap some treasury assets
 * to other assets on a DEX, which are voted on-chain by all TCKO holders. Once
 * a voting has been completed, the decided upon trade is executed by the
 * `kimlikdao.eth` contract using the nominated DEX.
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
 * Lockup
 * ======
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
 *   (I2) sum_a(balanceOf(a)) == totalSupply <= totalMinted
 *   (I3) totalMinted <= supplyCap()
 *   (I4) balanceOf(TCKOK) == KilitliTCKO.totalSupply()
 *
 * (F1) follows because DistroStage has 8 values and floor(7/2) + 2 = 5.
 * Combining (F1) and (I1) gives the 100M TCKO supply cap.
 *
 * Voting
 * ======
 * TCKOs support three concurrent snapshots, allowing users to participate
 * in three polls / voting at the same time. The voting contract should call
 * the `snapshot0()` method at the beginning of the voting. When a user votes,
 * their voting weight is obtained by calling the
 *
 *   `snapshot0BalanceOf(address)`,
 *   `snapshot1BalanceOf(address)` or
 *   `snapshot2BalanceOf(address)`
 *
 * methods. All operations are constant time, moreover use the same amount of
 * storage as just keeping the TCKO balances. This is achieved by packing the
 * snapshot values, ticks and the user balance all into the same EVM word.
 */
contract TCKO is IERC20Permit, HasDistroStage {
    mapping(address => mapping(address => uint256)) public override allowance;

    /// @notice The total number of TCKOs in existence, locked or unlocked.
    uint256 public override totalSupply;

    /// @notice The total TCKOs minted so far, including ones that have been
    /// redeemed later (i.e., burned).
    uint256 public totalMinted;

    mapping(address => uint256) private balances;

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
     * @notice The total number of TCKOs that will be minted ever.
     */
    function maxSupply() external pure returns (uint256) {
        return 100_000_000e6;
    }

    /**
     * @notice The total number of TCKOs in existence minus the locked ones.
     */
    function circulatingSupply() external view returns (uint256) {
        unchecked {
            // No overflow due to (I2)
            return totalSupply - (balances[TCKOK] & BALANCE_MASK);
        }
    }

    /**
     * @notice The max number of TCKOs that can be minted at the current stage.
     *
     * Ensures:
     *   (E2) supplyCap() <= 20M * 1M * distroRound
     *
     * Recall that distroRound := distroStage / 2 + distroStage == 0 ? 1 : 2,
     * so combined with distroRound <= 5, we get the 100M TCKO supply cap.
     */
    function supplyCap() public view returns (uint256) {
        unchecked {
            uint256 stage = uint256(distroStage);
            return 20_000_000e6 * (stage / 2 + (stage == 0 ? 1 : 2));
        }
    }

    function balanceOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return balances[account] & BALANCE_MASK;
    }

    /**
     * @notice Transfer some TCKOs to a given address.
     *
     * If the `to` address is `DAO_KASASI`, the transfer is understood as a
     * redemption: the sent TCKOs are burned and the portion of `DAO_KASASI`
     * corresponding to the sent TCKOs are given back to the `msg.sender`.
     *
     * Sending to the 0 address is disallowed to prevent user error. Sending to
     * this contract and the `KilitliTCKO` contract are disallowed to maintain
     * our invariants.
     *
     * @param to               the address of the recipient.
     * @param amount           amount of TCKOs * 1e6.
     */
    function transfer(address to, uint256 amount)
        external
        override
        returns (bool)
    {
        // Disallow sending to the 0 address, which is a common software / user
        // error.
        require(to != address(0));
        // Disallow sending TCKOs to this contract, as `rescueToken()` on
        // TCKOs would result in a redemption to this contract, which is *bad*.
        require(to != address(this));
        // We disallow sending to `TCKOK` as we want to enforce (I4)
        // at all times.
        require(to != TCKOK);
        unchecked {
            uint256 t = tick;
            uint256 fromBalance = balances[msg.sender];
            require(amount <= fromBalance & BALANCE_MASK); // (*)
            balances[msg.sender] = preserve(fromBalance, t) - amount;
            // If sent to `DAO_KASASI`, the tokens are burned and the portion
            // of the treasury is sent back to the msg.sender (i.e., redeemed).
            // The redemption amount is `amount / totalSupply()` of all
            // treasury assets.
            if (to == DAO_KASASI) {
                IDAOKasasi(DAO_KASASI).redeem(
                    payable(msg.sender),
                    amount,
                    totalSupply
                );
                totalSupply -= amount; // No overflow due to (I2)
            } else {
                // No overflow due to (*) and (I1)
                balances[to] = preserve(balances[to], t) + amount;
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
        require(to != address(0) && to != address(this));
        require(to != TCKOK); // For (I4)

        uint256 senderAllowance = allowance[from][msg.sender];
        if (senderAllowance != type(uint256).max)
            allowance[from][msg.sender] = senderAllowance - amount; // Checked sub

        unchecked {
            uint256 t = tick;
            uint256 fromBalance = balances[from];
            require(amount <= fromBalance & BALANCE_MASK);
            balances[from] = preserve(fromBalance, t) - amount;
            if (to == DAO_KASASI) {
                IDAOKasasi(DAO_KASASI).redeem(
                    payable(from),
                    amount,
                    totalSupply
                );
                totalSupply -= amount;
            } else {
                balances[to] = preserve(balances[to], t) + amount;
            }
        }
        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount)
        external
        override
        returns (bool)
    {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedAmount)
        external
        returns (bool)
    {
        // Checked addition
        uint256 newAmount = allowance[msg.sender][spender] + addedAmount;
        allowance[msg.sender][spender] = newAmount;
        emit Approval(msg.sender, spender, newAmount);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedAmount)
        external
        returns (bool)
    {
        // Checked subtraction
        uint256 newAmount = allowance[msg.sender][spender] - subtractedAmount;
        allowance[msg.sender][spender] = newAmount;
        emit Approval(msg.sender, spender, newAmount);
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////
    //
    // IERC20Permit related fields and methods
    //
    ///////////////////////////////////////////////////////////////////////////

    // keccak256(
    //     abi.encode(
    //         keccak256(
    //             "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    //         ),
    //         keccak256(bytes("TCKO")),
    //         keccak256(bytes("1")),
    //         43114,
    //         TCKO_ADDR
    //     )
    // );
    bytes32 public constant override DOMAIN_SEPARATOR =
        0xd3b6088e7d58a5742b419d3f22999e21c76cce42f96b85b3fdc54662eb2d445c;

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    mapping(address => uint256) public override nonces;

    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp);
        unchecked {
            bytes32 digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            spender,
                            amount,
                            nonces[owner]++,
                            deadline
                        )
                    )
                )
            );
            address recovered = ecrecover(digest, v, r, s);
            require(recovered != address(0) && recovered == owner);
        }
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    ///////////////////////////////////////////////////////////////////////////
    //
    // DAO related fields and methods
    //
    ///////////////////////////////////////////////////////////////////////////

    DistroStage public override distroStage;

    address private presale2Contract;

    /**
     * Advances the distribution stage.
     *
     * If we've advanced to DAOSaleStart stage or DAOAMMStart stage,
     * automatically mints 20M unlocked TCKOs to `DAO_KASASI`.
     *
     * @param newStage value to double check to prevent user error.
     */
    function incrementDistroStage(DistroStage newStage) external {
        require(msg.sender == DEV_KASASI);
        // Ensure the user provided round number matches, to prevent user error.
        require(uint256(distroStage) + 1 == uint256(newStage));
        // Make sure all minting has been done for the current stage
        require(supplyCap() == totalMinted, "Mint all!");
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
                uint256 amount = 20_000_000e6;
                totalMinted += amount;
                totalSupply += amount;
                balances[DAO_KASASI] =
                    preserve(balances[DAO_KASASI], tick) +
                    amount;
                emit Transfer(address(this), DAO_KASASI, amount);
            }
        }
        IDAOKasasi(DAO_KASASI).distroStageUpdated(newStage);
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
    function mint(uint256 amountAccount) public {
        require(
            msg.sender == DEV_KASASI ||
                (distroStage == DistroStage.Presale2 &&
                    msg.sender == presale2Contract)
        );
        uint256 amount = amountAccount >> 160;
        address account = address(uint160(amountAccount));
        require(totalMinted + amount <= supplyCap()); // Checked addition (*)
        // We need this to satisfy (I4).
        require(account != TCKOK);
        // If minted to `DAO_KASASI` unlocking would lead to redemption.
        require(account != DAO_KASASI);
        unchecked {
            uint256 unlocked = (amount + 3) / 4;
            uint256 locked = amount - unlocked;
            uint256 t = tick;
            totalMinted += amount; // No overflow due to (*) and (I1)
            totalSupply += amount; // No overflow due to (*) and (I1)
            // No overflow due to (*) and (I1)
            balances[account] = preserve(balances[account], t) + unlocked;
            // No overflow due to (*) and (I1)
            balances[TCKOK] = preserve(balances[TCKOK], t) + locked;
            emit Transfer(address(this), account, unlocked);
            emit Transfer(address(this), TCKOK, locked);
            KilitliTCKO(TCKOK).mint(account, locked, distroStage);
        }
    }

    function mintBulk(uint256[10] calldata amountAccount) external {
        require(msg.sender == DEV_KASASI);
        mint(amountAccount[0]);
        mint(amountAccount[1]);
        mint(amountAccount[2]);
        mint(amountAccount[3]);
        mint(amountAccount[4]);
        if (amountAccount[5] == 0) return;
        mint(amountAccount[5]);
        if (amountAccount[6] == 0) return;
        mint(amountAccount[6]);
        if (amountAccount[7] == 0) return;
        mint(amountAccount[7]);
        if (amountAccount[8] == 0) return;
        mint(amountAccount[8]);
        if (amountAccount[9] == 0) return;
        mint(amountAccount[9]);
    }

    function setPresale2Contract(address addr) external {
        require(msg.sender == DEV_KASASI);
        presale2Contract = addr;
    }

    /**
     * Move ERC20 tokens sent to this address by accident to `DAO_KASASI`.
     */
    function rescueToken(IERC20 token) external {
        // We restrict this method to `DEV_KASASI` only, as we call a method of
        // an unkown contract, which could potentially be a security risk.
        require(msg.sender == DEV_KASASI);
        token.transfer(DAO_KASASI, token.balanceOf(address(this)));
    }

    ///////////////////////////////////////////////////////////////////////////
    //
    // Snapshot related fields and methods
    //
    ///////////////////////////////////////////////////////////////////////////

    uint256 private constant BALANCE_MASK = type(uint48).max;
    uint256 private constant TICK0 = type(uint256).max << 232;
    uint256 private constant TICK1 = ((uint256(1) << 20) - 1) << 212;
    uint256 private constant TICK2 = ((uint256(1) << 20) - 1) << 192;

    // `tick` layout:
    // |-- tick0 --|-- tick1 --|-- tick2 --|-- balance2 --|-- balance1 --|-- balance0 --|-- balance --|
    // |--   24  --|--   20  --|--   20  --|--    48    --|--    48    --|--    48    --|--    48   --|
    uint256 private tick;

    function snapshot0BalanceOf(address account)
        external
        view
        returns (uint256)
    {
        uint256 balance = balances[account];
        unchecked {
            return
                BALANCE_MASK &
                (((balance ^ tick) & TICK0 == 0) ? (balance >> 48) : balance);
        }
    }

    function snapshot1BalanceOf(address account)
        external
        view
        returns (uint256)
    {
        uint256 balance = balances[account];
        unchecked {
            return
                BALANCE_MASK &
                (((balance ^ tick) & TICK1 == 0) ? (balance >> 96) : balance);
        }
    }

    function snapshot2BalanceOf(address account)
        external
        view
        returns (uint256)
    {
        uint256 balance = balances[account];
        unchecked {
            return
                BALANCE_MASK &
                (((balance ^ tick) & TICK2 == 0) ? (balance >> 144) : balance);
        }
    }

    function snapshot0() external {
        require(msg.sender == OYLAMA);
        unchecked {
            tick += uint256(1) << 232;
        }
    }

    function snapshot1() external {
        require(msg.sender == OYLAMA);
        unchecked {
            uint256 t = tick;
            tick = t & TICK1 == TICK1 ? t & ~TICK1 : t + (uint256(1) << 212);
        }
    }

    function snapshot2() external {
        require(msg.sender == OYLAMA);
        unchecked {
            uint256 t = tick;
            tick = t & TICK2 == TICK2 ? t & ~TICK2 : t + (uint256(1) << 192);
        }
    }

    function preserve(uint256 balance, uint256 t)
        internal
        pure
        returns (uint256)
    {
        unchecked {
            // tick.tick0 doesn't match balance.tick0; we need to preserve the
            // current balance.
            if ((balance ^ t) & TICK0 != 0) {
                balance &= ~((BALANCE_MASK << 48) | TICK0);
                balance |= (balance & BALANCE_MASK) << 48;
                balance |= t & TICK0;
            }
            // tick.tick1 doesn't match balance.tick1; we need to preserve the
            // current balance.
            if ((balance ^ t) & TICK1 != 0) {
                balance &= ~((BALANCE_MASK << 96) | TICK1);
                balance |= (balance & BALANCE_MASK) << 96;
                balance |= t & TICK1;
            }
            // tick.tick2 doesn't match balance.tick2; we need to preserve the
            // current balance.
            if ((balance ^ t) & TICK2 != 0) {
                balance &= ~((BALANCE_MASK << 144) | TICK2);
                balance |= (balance & BALANCE_MASK) << 144;
                balance |= t & TICK2;
            }
            return balance;
        }
    }
}
