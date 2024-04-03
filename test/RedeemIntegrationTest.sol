// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {KDAO, LockedKDAO} from "contracts/KDAO.sol";
import {Test} from "forge-std/Test.sol";
import {
    KDAOL,
    KDAOL_DEPLOYER,
    KDAO_ADDR,
    KDAO_DEPLOYER,
    PROTOCOL_FUND,
    PROTOCOL_FUND_DEPLOYER,
    VOTING
} from "interfaces/Addresses.sol";
import {IERC20} from "interfaces/IERC20.sol";
import {IProtocolFund} from "interfaces/IProtocolFund.sol";
import {MockProtocolFundV1} from "interfaces/testing/MockProtocolFundV1.sol";

contract ReentrancyAttackAttempt1 {
    IERC20 private kdao = IERC20(KDAO_ADDR);

    function attack() external {
        kdao.transfer(address(PROTOCOL_FUND), (kdao.balanceOf(address(this)) * 3) / 4);
    }

    receive() external payable {
        uint256 amount = (kdao.balanceOf(address(this)) * 3) / 4;
        if (kdao.balanceOf(address(this)) >= amount) {
            kdao.transfer(address(PROTOCOL_FUND), amount);
        }
    }
}

contract ReentrancyAttackAttempt2 {
    IERC20 private kdao = IERC20(KDAO_ADDR);

    function attack() external {
        kdao.transfer(address(PROTOCOL_FUND), (kdao.balanceOf(address(this)) / 2));
    }

    receive() external payable {
        if (kdao.balanceOf(address(this)) >= 125e9) {
            kdao.transfer(address(PROTOCOL_FUND), 125e9);
        }
    }
}

contract InnocentContract is Test {
    IERC20 private kdao = IERC20(KDAO_ADDR);

    function sendToProtocolFund() external {
        kdao.transfer(address(PROTOCOL_FUND), kdao.balanceOf(address(this)));
    }

    receive() external payable {
        vm.deal(address(this), 2e18);
    }
}

contract RedeemIngegrationTest is Test {
    KDAO private kdao;
    LockedKDAO private kdaol;
    ReentrancyAttackAttempt1 private reentrancyContract1;
    ReentrancyAttackAttempt2 private reentrancyContract2;
    InnocentContract private innocentContract;
    IProtocolFund private protocolFund;

    function setUp() public {
        vm.prank(KDAO_DEPLOYER);
        kdao = new KDAO(false);
        vm.prank(KDAOL_DEPLOYER);
        kdaol = new LockedKDAO();
        assertEq(address(kdaol), KDAOL);

        vm.startPrank(vm.addr(1));
        reentrancyContract1 = new ReentrancyAttackAttempt1();
        reentrancyContract2 = new ReentrancyAttackAttempt2();
        innocentContract = new InnocentContract();
        vm.stopPrank();

        vm.prank(PROTOCOL_FUND_DEPLOYER);
        protocolFund = new MockProtocolFundV1();

        vm.deal(PROTOCOL_FUND, 80e18);

        mintAll(1e12);
    }

    function mintAll(uint256 amount) public {
        vm.startPrank(VOTING);
        for (uint256 i = 1; i <= 20; ++i) {
            kdao.mintTo((amount << 160) | uint160(vm.addr(i)));
        }
        vm.stopPrank();
    }

    function testReentrancyAttack1() external {
        vm.startPrank(vm.addr(1));
        kdao.transfer(address(reentrancyContract1), kdao.balanceOf(vm.addr(1)));

        assertEq(kdao.balanceOf(address(reentrancyContract1)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(1)), 0);

        vm.expectRevert();
        reentrancyContract1.attack();

        vm.stopPrank();
    }

    function testReentrancyAttack2() external {
        vm.prank(vm.addr(2));
        kdao.transfer(address(reentrancyContract2), 250e9);
        assertEq(kdao.balanceOf(address(reentrancyContract2)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(2)), 0);

        vm.expectRevert();
        reentrancyContract2.attack();
    }

    function testInnocent() external {
        vm.prank(vm.addr(3));
        kdao.transfer(PROTOCOL_FUND, 250e9);

        assertEq(vm.addr(3).balance, 1e18);
    }

    function testInnocentWithContract() external {
        vm.prank(vm.addr(4));
        kdao.transfer(address(innocentContract), 250e9);

        assertEq(kdao.balanceOf(address(innocentContract)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(4)), 0);

        innocentContract.sendToProtocolFund();

        assertEq(address(innocentContract).balance, 2e18);
    }
}
