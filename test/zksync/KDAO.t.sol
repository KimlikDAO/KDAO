// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    KDAO_LOCKED,
    KDAO_LOCKED_DEPLOYER,
    KDAO_ZKSYNC,
    KDAO_ZKSYNC_DEPLOYER,
    VOTING
} from "interfaces/kimlikdao/addresses.sol";
import {amountAddrFrom} from "interfaces/types/amountAddr.sol";
import {uint48x2From} from "interfaces/types/uint48x2.sol";
import {KDAO} from "zksync/KDAO.sol";
import {KDAOLocked} from "zksync/KDAOLocked.sol";

contract KDAOTest is Test {
    KDAO private kdao;
    KDAOLocked private kdaol;

    function mintAll(uint256 amount) public {
        vm.startPrank(VOTING);
        for (uint256 i = 1; i <= 20; ++i) {
            kdao.mint(amountAddrFrom(amount, vm.addr(i)));
        }
        vm.stopPrank();
    }

    function setUp() public {
        vm.etch(KDAO_LOCKED, type(KDAOLocked).runtimeCode);
        kdaol = KDAOLocked(KDAO_LOCKED);

        vm.etch(KDAO_ZKSYNC, type(KDAO).runtimeCode);
        kdao = KDAO(KDAO_ZKSYNC);

        mintAll(1e12);
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

    function testAuthentication() public {
        vm.expectRevert();
        kdao.snapshot0();
        vm.expectRevert();
        kdao.snapshot1();
        vm.expectRevert();
        kdao.snapshot1();

        vm.startPrank(VOTING);
        kdao.snapshot0();
        kdao.snapshot1();
        kdao.snapshot2();
        vm.stopPrank();

        vm.expectRevert();
        kdao.consumeSnapshot0Balance(vm.addr(1));
        vm.expectRevert();
        kdao.consumeSnapshot1Balance(vm.addr(1));
        vm.expectRevert();
        kdao.consumeSnapshot2Balance(vm.addr(1));

        vm.startPrank(VOTING);
        kdao.consumeSnapshot0Balance(vm.addr(1));
        kdao.consumeSnapshot1Balance(vm.addr(1));
        kdao.consumeSnapshot2Balance(vm.addr(1));
        vm.stopPrank();
    }

    function testTransfer() public {
        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250_000e6);
        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdao.balanceOf(vm.addr(2)), 500_000e6);
    }

    function testTransferFrom() public {
        vm.prank(vm.addr(1));
        kdao.approve(vm.addr(3), 250_000e6);

        vm.prank(vm.addr(3));
        kdao.transferFrom(vm.addr(1), vm.addr(2), 250_000e6);

        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdao.balanceOf(vm.addr(2)), 500_000e6);
    }
}
