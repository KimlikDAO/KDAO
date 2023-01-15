// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./ReentrancyAttackContracts.sol";
import "contracts/TCKO.sol";
import "forge-std/Test.sol";
import {MockDAOKasasi} from "interfaces/testing/MockDAOKasasi.sol";

contract ReentrancyTest is Test {
    TCKO private tcko;
    KilitliTCKO private tckok;
    ReentrancyAttackAttempt1 private reentrancyContract1;
    ReentrancyAttackAttempt2 private reentrancyContract2;
    InnocentContract private innocentContract;
    IDAOKasasi private daoKasasi;

    function setUp() public {
        vm.prank(TCKO_DEPLOYER);
        tcko = new TCKO(false);
        vm.prank(TCKOK_DEPLOYER);
        tckok = new KilitliTCKO();
        assertEq(address(tckok), TCKOK);

        vm.startPrank(vm.addr(1));
        reentrancyContract1 = new ReentrancyAttackAttempt1();
        reentrancyContract2 = new ReentrancyAttackAttempt2();
        innocentContract = new InnocentContract();
        vm.stopPrank();

        vm.prank(DAO_KASASI_DEPLOYER);
        daoKasasi = new MockDAOKasasi();

        vm.deal(DAO_KASASI, 80e18);

        mintAll(1e12);
    }

    function mintAll(uint256 amount) public {
        vm.startPrank(DEV_KASASI);
        for (uint256 i = 1; i <= 20; ++i)
            tcko.mintTo((amount << 160) | uint160(vm.addr(i)));
        vm.stopPrank();
    }

    function testReentrancyAttack1() external {
        vm.startPrank(vm.addr(1));
        tcko.transfer(address(reentrancyContract1), tcko.balanceOf(vm.addr(1)));

        assertEq(tcko.balanceOf(address(reentrancyContract1)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(1)), 0);

        vm.expectRevert();
        reentrancyContract1.attack();

        vm.stopPrank();
    }

    function testReentrancyAttack2() external {
        console.log(vm.addr(2).balance);
        vm.prank(vm.addr(2));
        tcko.transfer(address(reentrancyContract2), 250e9);
        assertEq(tcko.balanceOf(address(reentrancyContract2)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(2)), 0);

        vm.expectRevert();
        reentrancyContract2.attack();
    }

    function testInnocent() external {
        vm.prank(vm.addr(3));
        tcko.transfer(DAO_KASASI, 250e9);

        assertEq(vm.addr(3).balance, 1e18);
    }

    function testInnocentWithContract() external {
        vm.prank(vm.addr(4));
        tcko.transfer(address(innocentContract), 250e9);

        assertEq(tcko.balanceOf(address(innocentContract)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(4)), 0);

        innocentContract.sendToDAOkasasi();

        assertEq(address(innocentContract).balance, 2e18);
    }
}
