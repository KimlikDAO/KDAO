// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {MockKDAO} from "./MockKDAO.sol";
import {KDAO} from "ethereum/KDAO.sol";
import {Test, stdError} from "forge-std/Test.sol";
import {
    KDAO_ETHEREUM,
    KDAO_ETHEREUM_DEPLOYER,
    PROTOCOL_FUND
} from "interfaces/kimlikdao/addresses.sol";

contract KDAOTest is Test {
    KDAO private kdao;

    function setUp() public {
        vm.prank(KDAO_ETHEREUM_DEPLOYER);
        kdao = new MockKDAO();
    }

    function testAddressConsistency() external pure {
        assertEq(vm.computeCreateAddress(KDAO_ETHEREUM_DEPLOYER, 0), KDAO_ETHEREUM);
    }

    function testMetadata() external view {
        assertEq(kdao.name(), "KimlikDAO");
        assertEq(kdao.symbol(), "KDAO");
        assertEq(kdao.decimals(), 6);
    }

    function testTransferToContractNotAllowed() external {
        vm.startPrank(address(0));
        vm.expectRevert();
        kdao.transfer(address(kdao), 100e6);
        vm.stopPrank();
    }

    function testTransferToSelfPreservesBalance() external {
        // Transfer to self and assert that the balance remains the same
        vm.startPrank(address(0));
        for (uint256 i = 0; i <= 100; ++i) {
            kdao.transfer(address(0), i * 1e6);
            assertEq(kdao.balanceOf(address(0)), 100e6);
        }
        vm.stopPrank();
    }

    function testTransferInsuffucientBalance() external {
        vm.startPrank(address(2));
        for (uint256 i = 1; i < 100; ++i) {
            vm.expectRevert();
            kdao.transfer(address(3), 100e6 + i);
        }
        vm.stopPrank();
    }

    function testTransferPreservesBalances() external {
        // Transfer all balance of i to -3i (mod 19)
        // Since this is bijective, all balances should remain the same
        for (uint160 i = 0; i < 19; ++i) {
            vm.prank(address(i));
            kdao.transfer(address((i * 16) % 19), 100e6);
        }
        for (uint160 i = 0; i < 20; ++i) {
            assertEq(kdao.balanceOf(address(i)), 100e6);
        }
        // Transfer all balance of i to -5i (mod 19) for i = 0..19
        // This should move the balance of 19 to 0.
        for (uint160 i = 0; i < 20; ++i) {
            vm.prank(address(i));
            kdao.transfer(address((i * 16) % 19), 100e6);
        }
        assertEq(kdao.balanceOf(address(0)), 200e6);
        assertEq(kdao.balanceOf(address(19)), 0);
        for (uint160 i = 1; i < 19; ++i) {
            assertEq(kdao.balanceOf(address(i)), 100e6);
        }
    }

    function testTransferFrom() external {
        vm.prank(address(11));
        kdao.approve(address(12), 3);

        vm.startPrank(address(12));
        kdao.transferFrom(address(11), address(12), 1);
        kdao.transferFrom(address(11), address(13), 1);
        kdao.transferFrom(address(11), address(14), 1);

        vm.expectRevert();
        kdao.transferFrom(address(11), address(15), 1);

        assertEq(kdao.balanceOf(address(12)), 100e6 + 1);
        assertEq(kdao.balanceOf(address(13)), 100e6 + 1);
        assertEq(kdao.balanceOf(address(14)), 100e6 + 1);
    }

    function testTransferFromDisallowedAddresses() external {
        vm.startPrank(address(11));
        kdao.approve(address(11), 100e6);

        vm.expectRevert();
        kdao.transferFrom(address(11), address(kdao), 100e6);

        vm.expectRevert();
        kdao.transferFrom(address(11), PROTOCOL_FUND, 100e6);

        vm.stopPrank();
    }

    function testTransferFromInfiniteApproval() external {
        vm.prank(address(19));
        kdao.approve(address(11), ~uint256(0));

        vm.startPrank(address(11));
        kdao.transferFrom(address(19), address(20), 50e6);
        kdao.transferFrom(address(19), address(21), 50e6);
        vm.expectRevert();
        kdao.transferFrom(address(19), address(22), 1);
    }

    function testTransferFromToSelfPreservesBalance() external {
        vm.startPrank(address(0));
        // Approve self for infinite KDAOs
        kdao.approve(address(0), ~uint256(0));
        for (uint256 i = 0; i <= 100; ++i) {
            kdao.transferFrom(address(0), address(0), i * 1e6);
            assertEq(kdao.balanceOf(address(0)), 100e6);
        }
        // Do the same with exact amount approval
        kdao.approve(address(0), (100e6 * 101) / 2);
        for (uint256 i = 0; i <= 100; ++i) {
            kdao.transferFrom(address(0), address(0), i * 1e6);
            assertEq(kdao.balanceOf(address(0)), 100e6);
        }
        vm.stopPrank();
    }

    function testIncreaseDecreaseAllowance() external {
        vm.startPrank(address(1));
        kdao.increaseAllowance(address(2), 12);
        kdao.increaseAllowance(address(2), 18);

        assertEq(kdao.allowance(address(1), address(2)), 30);

        kdao.decreaseAllowance(address(2), 10);

        assertEq(kdao.allowance(address(1), address(2)), 20);
        vm.stopPrank();

        vm.prank(address(2));
        kdao.transferFrom(address(1), address(3), 20);

        assertEq(kdao.balanceOf(address(3)), 100e6 + 20);
        assertEq(kdao.balanceOf(address(1)), 100e6 - 20);
        assertEq(kdao.allowance(address(1), address(2)), 0);

        vm.startPrank(address(1));
        kdao.increaseAllowance(address(2), 10);
        kdao.decreaseAllowance(address(2), 10);

        assertEq(kdao.allowance(address(1), address(2)), 0);
    }

    function testIncreaseDecreaseAllowanceOverflow() external {
        vm.startPrank(address(1));
        kdao.increaseAllowance(address(3), 10);

        vm.expectRevert();
        kdao.decreaseAllowance(address(3), 11);

        kdao.approve(address(3), type(uint256).max - 1);

        vm.expectRevert(stdError.arithmeticError);
        kdao.increaseAllowance(address(3), 2);

        vm.stopPrank();
    }
}
