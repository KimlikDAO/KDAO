// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {KDAOLocked} from "./KDAOLocked.sol";
import {SSBalance} from "./SSBalance.sol";
import {IBridgeReceiver} from "common/IBridgeReceiver.sol";
import {IERC20, IERC20Permit} from "interfaces/erc/IERC20Permit.sol";
import {IERC20Snapshot3} from "interfaces/erc/IERC20Snapshot3.sol";
import {DistroStage, IDistroStage} from "interfaces/kimlikdao/IDistroStage.sol";
import {
    DEV_FUND,
    KDAO_LOCKED,
    KDAO_PRESALE,
    KDAO_ZKSYNC,
    KDAO_ZKSYNC_ALIAS,
    KPASS_SIGNERS,
    PROTOCOL_FUND_ZKSYNC,
    VOTING
} from "interfaces/kimlikdao/addresses.sol";
import {amountAddr} from "interfaces/types/amountAddr.sol";
import {L1Messenger} from "interfaces/zksync/IL1Messenger.sol";

/**
 * @title KDAO: KimlikDAO Token
 *
 * Utility
 * =======
 * 1 KDAO represents a share of all assets of the KimlikDAO treasury located
 * at `kimlikdao.eth` and 1 voting right for all treasury investment decisions.
 * Further, KimlikDAO protocol nodes need to stake KDAOs to get promoted to a
 * signer node.
 *
 * Any KDAO holder can redeem their share of the DAO treasury assets by
 * transferring their KDAOs to `kimlikdao.eth` on Avalanche C-chain. Such a
 * transfer burns the transferred KDAOs and sends the redeemer their share of
 * the treasury. The share of the redeemer is `sentAmount / totalSupply()`
 * fraction of all the ERC20 tokens and AVAX the treasury has.
 * Note however that the market value of KDAO is ought to be higher than the
 * redemption amount, as KDAO represents a share in KimlikDAO's future cash
 * flow as well. The redemption amount is merely a lower bound on KDAOs value
 * and the `redeem` functionality should only be used as a last resort.
 *
 * Investment decisions are made through proposals to swap some treasury assets
 * to other assets on a DEX, which are voted on-chain by all KDAO holders. Once
 * a voting has been completed, the decided upon trade is executed by the
 * `kimlikdao.eth` contract using the nominated DEX.
 *
 * Combined with a KPASS, KDAO gives a person voting rights for non-financial
 * decisions of KimlikDAO also; however in such decisions the voting weight is
 * not necessarily proportional to one's KDAO holdings (guaranteed to be
 * sub-linear in one's KDAO holdings). Since KPASS is an ID token, it allows us
 * to enforce the sub-linear voting weight.
 *
 * Supply Cap
 * ==========
 * There will be 100M KDAOs minted ever, distributed over 5 rounds of 20M KDAOs
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
 * In distribution rounds 3 and 4, 20M KDAOs are minted to `kimlikdao.eth`
 * automatically, to be sold / distributed to the public by `kimlikdao.eth`.
 * In the rest of the rounds (1, 2, and 5), the minting is manually managed
 * by `dev.kimlikdao.eth`, however the total minted KDAOs is capped at
 * distroRound * 20M KDAOs at any moment during the lifetime of the contract.
 * Additionally, in round 2, the `presale2Contract` is also given minting
 * rights, again respecting the 20M * distroRound supply cap.
 *
 * Since the `releaseRound` cannot be incremented beyond 5, this ensures that
 * there can be at most 100M KDAOs minted.
 *
 * Lockup
 * ======
 * Each mint to external parties results in some unlocked and some locked
 * KDAOs, and the ratio is fixed globally. Only the 40M KDAOs minted to
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
 *   (I1) supplyCap() <= 20M * 1M * distroRound < 2^48.
 *   (I2) sum_a(balanceOf(a)) == totalSupply
 *   (I3) totalSupply <= supplyCap()
 *   (I4) balanceOf(KDAO_LOCKED) == KDAOLocked.totalSupply()
 *
 * (F1) follows because DistroStage has 8 values and floor(7/2) + 2 = 5.
 * Combining (F1) and (I1) gives the 100M KDAO supply cap.
 *
 * Voting
 * ======
 * KDAOs support three concurrent snapshots, allowing users to participate
 * in three polls / voting at the same time. The voting contract should call
 * the `snapshot0()` method at the beginning of the voting. When a user votes,
 * their voting weight is obtained by calling the
 *
 *   `snapshot0BalanceOf(address)`,
 *   `snapshot1BalanceOf(address)` or
 *   `snapshot2BalanceOf(address)`
 *
 * methods. All operations are constant time, moreover use the same amount of
 * storage as just keeping the KDAO balances. This is achieved by packing the
 * snapshot values, ticks and the user balance all into the same EVM word.
 */
contract KDAO is IERC20Permit, IERC20Snapshot3, IDistroStage, IBridgeReceiver {
    function name() external pure override returns (string memory) {
        return "KimlikDAO";
    }

    function symbol() external pure override returns (string memory) {
        return "KDAO";
    }

    function decimals() external pure override returns (uint8) {
        return 6;
    }

    ///////////////////////////////////////////////////////////////////////////
    //
    // IERC20 balance fields and methods + additional supply methods
    //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice The total number of KDAOs in existence, locked or unlocked.
    uint256 public override totalSupply;

    mapping(address => SSBalance) private balances;

    /**
     * @notice An upper bound on the number of KDAOs in circulation. This
     * method does not account for the redeemed KDAOs since the redemption
     * happens on mainnet.
     *
     * Calculates the total number of KDAOs minted, minus the locked and
     * the staked ones.
     *
     * To calculate the actual circulating supply, compute
     *
     *   circulatingSupply() - (100_000_000e6 - ethereum/KDAO.maxSupply()).
     *
     * which corrects this amount by the redeemed (and hence burned) KDAOs.
     */
    function circulatingSupply() external view returns (uint256) {
        // No overflow due to (I2)
        return totalSupply - balances[KDAO_LOCKED].balance() - balances[KPASS_SIGNERS].balance();
    }

    /**
     * @notice The max number of KDAOs that can be minted at the current stage.
     *
     * Ensures:
     *   (E2) supplyCap() <= 20M * 1M * distroRound
     *
     * Recall that distroRound := distroStage / 2 + distroStage == 0 ? 1 : 2,
     * so combined with distroRound <= 5, we get the 100M KDAO supply cap.
     */
    function supplyCap() public view returns (uint256) {
        unchecked {
            uint256 stage = uint256(distroStage);
            return 20_000_000e6 * (stage / 2 + (stage == 0 ? 1 : 2));
        }
    }

    function balanceOf(address account) external view override returns (uint256) {
        return balances[account].balance();
    }

    ///////////////////////////////////////////////////////////////////////////
    //
    // IERC20 transfer methods
    //
    ///////////////////////////////////////////////////////////////////////////

    /**
     * @notice Transfer some KDAOs to a given address.
     *
     * If the `to` address is `PROTOCOL_FUND`, the transfer is understood as a
     * redemption: the sent KDAOs are burned and the portion of `PROTOCOL_FUND`
     * corresponding to the sent KDAOs are given back to the `msg.sender`.
     *
     * Sending to the 0 address is disallowed to prevent user error. Sending to
     * this contract and the `KDAOLocked` contract are disallowed to maintain
     * our invariants.
     *
     * @param to               the address of the recipient.
     * @param amount           amount of KDAOs * 1e6.
     */
    function transfer(address to, uint256 amount) external override returns (bool) {
        require(to != KDAO_LOCKED); // For (I4)
        SSBalance t = tick;
        SSBalance fromBalance = balances[msg.sender];
        require(amount <= fromBalance.balance()); // (*)
        balances[msg.sender] = fromBalance.keep(t).sub(amount);
        balances[to] = balances[to].keep(t).add(amount); // No overflow due to (*) and (I1)
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external
        override
        returns (bool)
    {
        require(to != KDAO_LOCKED); // For (I4)
        uint256 senderAllowance = allowance[from][msg.sender];
        if (senderAllowance != type(uint256).max) {
            allowance[from][msg.sender] = senderAllowance - amount; // Checked sub
        }

        SSBalance t = tick;
        SSBalance fromBalance = balances[from];
        require(amount <= fromBalance.balance());
        balances[from] = fromBalance.keep(t).sub(amount);
        balances[to] = balances[to].keep(t).add(amount);
        emit Transfer(from, to, amount);
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////
    //
    // IERC20 allowance fields and methods + recommended update methods
    //
    ///////////////////////////////////////////////////////////////////////////

    mapping(address => mapping(address => uint256)) public override allowance;

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedAmount) external returns (bool) {
        uint256 newAmount = allowance[msg.sender][spender] + addedAmount; // Checked addition
        allowance[msg.sender][spender] = newAmount;
        emit Approval(msg.sender, spender, newAmount);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedAmount) external returns (bool) {
        uint256 newAmount = allowance[msg.sender][spender] - subtractedAmount; // Checked subtraction
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
    //         keccak256(bytes("KDAO")),
    //         keccak256(bytes("1")),
    //         0x144,
    //         KDAO_ZKSYNC
    //     )
    // );
    bytes32 public constant override DOMAIN_SEPARATOR =
        0xd4e93a4d8d1d64f6e02f179e7327d0ecd38feb1be285875c9cc442af71766c76;

    bytes32 private constant PERMIT_TYPEHASH =
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
                            PERMIT_TYPEHASH, owner, spender, amount, nonces[owner]++, deadline
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
    // KimlikDAO protocol specific fields and methods
    //
    ///////////////////////////////////////////////////////////////////////////

    DistroStage public override distroStage;

    /**
     * Advances the distribution stage.
     *
     * If we've advanced to ProtocolSaleStart stage or ProtocolAMMStart stage,
     * automatically mints 20M unlocked KDAOs to `PROTOCOL_FUND`.
     *
     * @param newStage value to double check to prevent user error.
     */
    function incrementDistroStage(DistroStage newStage) external {
        require(msg.sender == VOTING);
        // Ensure the user provided round number matches, to prevent user error.
        require(uint256(distroStage) + 1 == uint256(newStage));
        // Make sure all minting has been done for the current stage
        require(supplyCap() == totalSupply);
        // Ensure that we cannot go to FinalUnlock before 2028.
        if (newStage == DistroStage.FinalUnlock) require(block.timestamp > 1832306400);

        distroStage = newStage;

        if (newStage == DistroStage.ProtocolSaleStart || newStage == DistroStage.ProtocolAMMStart) {
            // Mint 20M KDAOs to `PROTOCOL_FUND` bypassing the standard locked
            // ratio.
            uint256 amount = 20_000_000e6;
            unchecked {
                totalSupply += amount;
            }
            balances[PROTOCOL_FUND_ZKSYNC] = balances[PROTOCOL_FUND_ZKSYNC].keep(tick).add(amount);
            emit Transfer(address(this), PROTOCOL_FUND_ZKSYNC, amount);
        }
    }

    /**
     * Mints a given number of tokens (locked + unlocked) to an address,
     * respecting the supply cap.
     *
     * A fixed locked / unlocked ratio is used across all mints to external
     * participants.
     *
     * To mint KDAOs to `PROTOCOL_FUND`, a separate code path is used, in which
     * all KDAOs are unlocked.
     *
     * @param aaddr            Account to be minted and the mint amount
     *                          packed in a single word. The amount is 48 bits
     *                          followed by a 160-bits address.
     */
    function mint(amountAddr aaddr) public {
        require(
            distroStage <= DistroStage.Presale2
                && (msg.sender == VOTING || msg.sender == KDAO_PRESALE)
                || (distroStage == DistroStage.FinalMint && msg.sender == DEV_FUND)
        );
        _mint(aaddr);
    }

    /**
     * Mints a given number of tokens (locked + unlocked) to an address,
     * respecting the supply cap.
     *
     * @param aaddr             Account to be minted and the mint amount
     *                          packed in a single word. The amount is 48 bits
     *                          followed by a 160-bits address.
     */
    function _mint(amountAddr aaddr) internal {
        (uint256 amount, address addr) = aaddr.unpack();
        require(totalSupply + amount <= supplyCap()); // Checked addition (*)
        // We need this to satisfy (I4).
        require(addr != KDAO_LOCKED);
        // If minted to `PROTOCOL_FUND` unlocking would lead to redemption.
        require(addr != PROTOCOL_FUND_ZKSYNC);
        unchecked {
            uint256 unlocked = (amount + 3) / 4;
            uint256 locked = amount - unlocked;
            SSBalance t = tick;
            totalSupply += amount; // No overflow due to (*) and (I1)
            balances[addr] = balances[addr].keep(t).add(unlocked); // No overflow due to (*) and (I1)
            balances[KDAO_LOCKED] = balances[KDAO_LOCKED].keep(t).add(locked); // No overflow due to (*) and (I1)
            emit Transfer(address(this), addr, unlocked);
            emit Transfer(address(this), KDAO_LOCKED, locked);
            KDAOLocked(KDAO_LOCKED).mint(addr, locked, distroStage);
        }
    }

    function sweepNativeToken() external {
        PROTOCOL_FUND_ZKSYNC.transfer(address(this).balance);
    }

    function sweepToken(IERC20 token) external {
        token.transfer(PROTOCOL_FUND_ZKSYNC, token.balanceOf(address(this)));
    }

    ///////////////////////////////////////////////////////////////////////////
    //
    // Mainnet bridge related fields and methods
    //
    ///////////////////////////////////////////////////////////////////////////

    event BridgeToMainnet(address indexed from, address indexed to, uint256 amount);
    event AcceptBridgeFromEthereum(address indexed addr, uint256 amount);

    function bridgeToMainnet(amountAddr aaddr) external {
        SSBalance fromBalance = balances[msg.sender];
        (uint256 amount, address to) = aaddr.unpack();
        if (to == address(0)) {
            to = msg.sender;
            aaddr = aaddr.addAddr(msg.sender);
        }
        require(amount <= fromBalance.balance());
        balances[msg.sender] = fromBalance.keep(tick).sub(amount);
        L1Messenger.sendToL1(abi.encode(aaddr));

        emit BridgeToMainnet(msg.sender, to, amount);
    }

    function acceptBridgeFromEthereum(amountAddr aaddr) external override {
        require(msg.sender == KDAO_ZKSYNC_ALIAS);
        (uint256 amount, address addr) = aaddr.unpack();
        balances[addr] = balances[addr].keep(tick).add(amount);

        emit AcceptBridgeFromEthereum(addr, amount);
    }

    ///////////////////////////////////////////////////////////////////////////
    //
    // Snapshot related fields and methods
    //
    ///////////////////////////////////////////////////////////////////////////

    SSBalance private tick;

    function snapshot0BalanceOf(address addr) external view override returns (uint256) {
        return balances[addr].balance0(tick);
    }

    function snapshot1BalanceOf(address addr) external view override returns (uint256) {
        return balances[addr].balance1(tick);
    }

    function snapshot2BalanceOf(address addr) external view override returns (uint256) {
        return balances[addr].balance2(tick);
    }

    function consumeSnapshot0Balance(address addr) external override returns (uint256) {
        require(msg.sender == VOTING);
        SSBalance balance = balances[addr];
        SSBalance t = tick;
        balances[addr] = balance.reset0(t);
        return balance.balance0(t);
    }

    function consumeSnapshot1Balance(address addr) external override returns (uint256) {
        require(msg.sender == VOTING);
        SSBalance balance = balances[addr];
        SSBalance t = tick;
        balances[addr] = balance.reset1(t);
        return balance.balance1(t);
    }

    function consumeSnapshot2Balance(address addr) external override returns (uint256) {
        require(msg.sender == VOTING);
        SSBalance balance = balances[addr];
        SSBalance t = tick;
        balances[addr] = balance.reset2(t);
        return balance.balance2(t);
    }

    function snapshot0() external override {
        require(msg.sender == VOTING);
        tick = tick.inc0();
    }

    function snapshot1() external override {
        require(msg.sender == VOTING);
        tick = tick.inc1();
    }

    function snapshot2() external override {
        require(msg.sender == VOTING);
        tick = tick.inc2();
    }
}
