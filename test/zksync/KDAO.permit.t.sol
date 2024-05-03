// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test, stdError} from "forge-std/Test.sol";
import {KDAO_LOCKED, KDAO_ZKSYNC, VOTING} from "interfaces/kimlikdao/addresses.sol";
import {amountAddrFrom} from "interfaces/types/amountAddr.sol";
import {KDAO} from "zksync/KDAO.sol";
import {KDAOLocked} from "zksync/KDAOLocked.sol";

contract KDAOPermitTest is Test {
    KDAO private kdao;
    KDAOLocked private kdaol;

    function mintAll(uint256 amount, address minter) internal {
        vm.startPrank(minter);
        for (uint256 i = 1; i <= 20; ++i) {
            kdao.mint(amountAddrFrom(amount, vm.addr(i)));
        }
        vm.stopPrank();
    }

    function setUp() external {
        vm.etch(KDAO_LOCKED, type(KDAOLocked).runtimeCode);
        kdaol = KDAOLocked(KDAO_LOCKED);

        vm.etch(KDAO_ZKSYNC, type(KDAO).runtimeCode);
        kdao = KDAO(KDAO_ZKSYNC);

        mintAll(1e12, VOTING);
    }

    function testDomainSeparator() external view {
        assertEq(
            kdao.DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes("KDAO")),
                    keccak256(bytes("1")),
                    0x144,
                    KDAO_ZKSYNC
                )
            )
        );
    }

    function authorizePayment(
        uint256 ownerPrivateKey,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint256 nonce
    ) internal view returns (uint8, bytes32, bytes32) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                kdao.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9,
                        vm.addr(ownerPrivateKey),
                        spender,
                        amount,
                        nonce,
                        deadline
                    )
                )
            )
        );
        return vm.sign(ownerPrivateKey, digest);
    }

    function testPermit() external {
        vm.prank(vm.addr(2));
        vm.expectRevert(stdError.arithmeticError);
        kdao.transferFrom(vm.addr(1), vm.addr(2), 250e9);

        uint256 time = block.timestamp + 1000;
        (uint8 v, bytes32 r, bytes32 s) = authorizePayment(1, vm.addr(2), 250e9, time, 0);
        kdao.permit(vm.addr(1), vm.addr(2), 250e9, time, v, r, s);
        vm.prank(vm.addr(2));
        kdao.transferFrom(vm.addr(1), vm.addr(2), 250e9);
        assertEq(kdao.balanceOf(vm.addr(2)), 500e9);
    }
}
