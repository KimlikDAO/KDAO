// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IBridgeReceiver} from "common/IBridgeReceiver.sol";
import {IERC20, IERC20Permit} from "interfaces/erc/IERC20Permit.sol";
import {PROTOCOL_FUND, ProtocolFund, RedeemInfoFrom} from "interfaces/kimlikdao/IProtocolFund.sol";
import {KDAO_ZKSYNC} from "interfaces/kimlikdao/addresses.sol";
import {amountAddr, amountAddrFrom} from "interfaces/types/amountAddr.sol";
import {uint128x2} from "interfaces/types/uint128x2.sol";
import {uint48x2, uint48x2From} from "interfaces/types/uint48x2.sol";
import {L1_MESSENGER} from "interfaces/zksync/IL1Messenger.sol";
import {TxStatus, ZkSync, applyL1ToL2Alias} from "interfaces/zksync/IZkSync.sol";
import {L2Log, L2LogLocator} from "interfaces/zksync/L2Log.sol";

contract KDAO is IERC20Permit {
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

    mapping(address => uint256) public override balanceOf;

    uint48x2 internal totals = uint48x2From(100_000_000e6, 0);

    /// @notice `maxSupply()` starts out as 100M and can only be decremented thereafter
    /// through `redeem()` operations. There is no way to increment it.
    function maxSupply() external view returns (uint256) {
        return totals.hi();
    }

    function totalSupply() external view override returns (uint256) {
        return totals.lo();
    }

    /**
     * @notice The circulating supply of KDAO is obtained by summing `circulatingSupply()`
     * on mainnet and zkSync Era.
     */
    function circulatingSupply() external view returns (uint256) {
        return totals.lo();
    }

    ///////////////////////////////////////////////////////////////////////////
    //
    // IERC20 transfer methods
    //
    ///////////////////////////////////////////////////////////////////////////

    function transfer(address to, uint256 amount) external override returns (bool) {
        if (to == PROTOCOL_FUND) {
            redeem(amount);
            return true;
        }
        require(to != address(this));
        balanceOf[msg.sender] -= amount; // Checked subtaction
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external
        override
        returns (bool)
    {
        require(to != address(this) && to != PROTOCOL_FUND);
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount; // Checked subtraction
        balanceOf[from] -= amount; // Checked subtraction
        unchecked {
            balanceOf[to] += amount;
        }
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
    //         keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
    //         keccak256(bytes("KDAO")),
    //         keccak256(bytes("1")),
    //         0x1,
    //         KDAO_ETHEREUM
    //     )
    // );
    bytes32 public constant override DOMAIN_SEPARATOR =
        0x6faf94999332059363533545c34fe71ffc0642c13cd1fa816c361b545eb33d9b;

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

    function redeem(uint256 amount) public {
        // Redemption on non EVM chains require providing a proof of knowledge of the private key
        // of the redeemer address. Because of this, redemption is allowed from EOA only.
        require(msg.sender == tx.origin);
        uint48x2 total = totals;
        balanceOf[msg.sender] -= amount; // Checked subtraction
        ProtocolFund.redeem(RedeemInfoFrom(total.setLo(amount), msg.sender));
        totals = total.dec(amount);
    }

    function sweepNativeToken() external {
        PROTOCOL_FUND.transfer(address(this).balance);
    }

    function sweepToken(IERC20 token) external {
        token.transfer(PROTOCOL_FUND, token.balanceOf(address(this)));
    }

    ///////////////////////////////////////////////////////////////////////////
    //
    // Mainnet <-> zkSync Era bridge fields and methods
    //
    ///////////////////////////////////////////////////////////////////////////

    event BridgeToZkSync(
        bytes32 indexed l2TxHash, address indexed from, address indexed to, uint256 amount
    );
    event ClaimFailedZkSyncBridge(bytes32 indexed l2TxHash, address indexed addr, uint256 amount);
    event AcceptBridgeFromZkSync(
        L2LogLocator indexed logLocator, address indexed addr, uint256 amount
    );

    mapping(bytes32 => amountAddr) private bridgedAmountAddr;
    mapping(L2LogLocator => bool) private isLogProcessed;

    function bridgeToZkSync(amountAddr aaddr, uint128x2 l2TxGasLimitAndPerPubdata)
        public
        payable
        returns (bytes32 l2TxHash)
    {
        (uint256 amount, address addr) = aaddr.unpack();
        if (addr == address(0)) {
            addr = msg.sender;
            aaddr = aaddr.addAddr(msg.sender);
        }
        balanceOf[msg.sender] -= amount; // Checked subtraction
        l2TxHash = ZkSync.requestL2Transaction{value: msg.value}(
            KDAO_ZKSYNC,
            0,
            abi.encodeCall(IBridgeReceiver.acceptBridgeFromEthereum, aaddr),
            l2TxGasLimitAndPerPubdata.hi(),
            l2TxGasLimitAndPerPubdata.lo(),
            new bytes[](0),
            msg.sender == tx.origin ? msg.sender : applyL1ToL2Alias(msg.sender)
        );
        totals = totals.decLo(amount);
        bridgedAmountAddr[l2TxHash] = aaddr.setAddr(msg.sender);
        emit BridgeToZkSync(l2TxHash, msg.sender, addr, amount);
    }

    function claimFailedZkSyncBridge(
        bytes32 l2TxHash,
        L2LogLocator logLocator,
        bytes32[] calldata merkleProof
    ) public {
        require(
            ZkSync.proveL1ToL2TransactionStatus(
                l2TxHash,
                logLocator.batchNumber(),
                logLocator.messageIndex(),
                logLocator.txNumber(),
                merkleProof,
                TxStatus.Failure
            )
        );
        amountAddr aaddr = bridgedAmountAddr[l2TxHash];
        require(!aaddr.isZero());
        bridgedAmountAddr[l2TxHash] = amountAddr.wrap(0);

        (uint256 amount, address addr) = aaddr.unpack();
        totals = totals.incLo(amount);
        unchecked {
            balanceOf[addr] += amount;
        }
        emit ClaimFailedZkSyncBridge(l2TxHash, addr, amount);
    }

    function acceptBridgeFromZkSync(
        amountAddr aaddr,
        L2LogLocator logLocator,
        bytes32[] calldata merkleProof
    ) public {
        L2Log memory l2Log = L2Log({
            l2ShardId: 0,
            isService: true,
            txNumberInBatch: uint16(logLocator.txNumber()),
            sender: L1_MESSENGER,
            key: bytes32(uint256(uint160(KDAO_ZKSYNC))),
            value: keccak256(abi.encode(aaddr))
        });
        require(!isLogProcessed[logLocator]);
        require(
            ZkSync.proveL2LogInclusion(
                logLocator.batchNumber(), logLocator.messageIndex(), l2Log, merkleProof
            )
        );

        (uint256 amount, address addr) = aaddr.unpack();
        uint48x2 total = totals.incLo(amount);
        require(total.lo() <= total.hi()); // We maintain this invariant even if zkSync Era is compromised.
        totals = total;
        unchecked {
            balanceOf[addr] += amount;
        }
        isLogProcessed[logLocator] = true;
        emit AcceptBridgeFromZkSync(logLocator, addr, amount);
    }
}
