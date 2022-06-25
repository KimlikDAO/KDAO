//SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./MockDAOKasasi.sol";
import "contracts/TCKO.sol";
import "forge-std/Test.sol";

contract TCKOTest is Test {
    TCKO private tcko;
    KilitliTCKO private tckok;
    IDAOKasasi private daoKasasi;

    function setUp() public {
        tcko = new TCKO();
        tckok = new KilitliTCKO();
        daoKasasi = new MockDAOKasasi();

        mintAll(1e12);
    }

    function mintAll(uint256 amount) public {
        for (uint256 i = 1; i <= 20; ++i) tcko.mint(vm.addr(i), amount);
    }

    function testShouldCompleteAllRounds() public {
        assertEq(tcko.totalSupply(), 20e12);
        assertEq(tckok.totalSupply(), 15e12);

        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 250_000e6);

        assertEq(tcko.balanceOf(vm.addr(1)), 0);
        assertEq(tcko.balanceOf(vm.addr(2)), 500_000e6);

        tcko.incrementDistroStage(DistroStage.Presale2);
        mintAll(1e12);

        assertEq(tcko.totalSupply(), 40e12);
        assertEq(tckok.totalSupply(), 30e12);

        tcko.incrementDistroStage(DistroStage.DAOSaleStart);

        assertEq(tcko.totalSupply(), 60e12);
        assertEq(tckok.totalSupply(), 30e12);
        assertEq(tcko.balanceOf(DAO_KASASI), 20e12);

        tcko.incrementDistroStage(DistroStage.DAOSaleEnd);

        tckok.unlock(vm.addr(1));
        tckok.unlock(vm.addr(2));

        assertEq(tcko.balanceOf(vm.addr(1)), 1e12);
        assertEq(tcko.balanceOf(vm.addr(2)), 1_500e9);

        tckok.unlockAllEven();

        assertEq(tckok.balanceOf(vm.addr(1)), 750e9);
        assertEq(tckok.balanceOf(vm.addr(2)), 750e9);

        tcko.incrementDistroStage(DistroStage.DAOAMMStart);

        assertEq(tcko.totalSupply(), 80e12);
        assertEq(tckok.totalSupply(), 15e12);

        tcko.incrementDistroStage(DistroStage.Presale2Unlock);

        tckok.unlockAllOdd();

        tcko.incrementDistroStage(DistroStage.FinalMint);

        mintAll(1e12);
        tckok.unlock(vm.addr(1));

        assertEq(tckok.balanceOf(vm.addr(1)), 750e9);

        vm.warp(1925097600);
        tcko.incrementDistroStage(DistroStage.FinalUnlock);
        tckok.unlock(vm.addr(1));

        assertEq(tckok.balanceOf(vm.addr(1)), 0);

        tckok.unlockAllEven();

        assertEq(tckok.balanceOf(vm.addr(12)), 0);
        assertEq(tckok.balanceOf(vm.addr(14)), 0);
        assertEq(tckok.balanceOf(vm.addr(17)), 0);

        assertEq(tcko.balanceOf(address(tckok)), tckok.totalSupply());
    }

    function testShouldNotUnlockBeforeMaturity() public {
        vm.expectRevert("TCKO-k: Not matured");
        tckok.unlockAllEven();

        vm.expectRevert("TCKO-k: Not matured");
        tckok.unlockAllOdd();

        tckok.unlock(vm.addr(10));
        assertEq(tcko.balanceOf(vm.addr(10)), 250e9);
        assertEq(tckok.balanceOf(vm.addr(10)), 750e9);

        tcko.incrementDistroStage(DistroStage.Presale2);

        vm.expectRevert("TCKO-k: Not matured");
        tckok.unlockAllEven();
        vm.expectRevert("TCKO-k: Not matured");
        tckok.unlockAllOdd();

        mintAll(1e12);

        vm.expectRevert("TCKO-k: Not matured");
        tckok.unlockAllEven();
        vm.expectRevert("TCKO-k: Not matured");
        tckok.unlockAllOdd();

        tcko.incrementDistroStage(DistroStage.DAOSaleStart);

        vm.expectRevert("TCKO-k: Not matured");
        tckok.unlockAllEven();
        vm.expectRevert("TCKO-k: Not matured");
        tckok.unlockAllOdd();

        tcko.incrementDistroStage(DistroStage.DAOSaleEnd);

        vm.expectRevert("TCKO-k: Not matured");
        tckok.unlockAllOdd();
        tckok.unlockAllEven();

        assertEq(tcko.balanceOf(vm.addr(2)), 1250e9);

        tcko.incrementDistroStage(DistroStage.DAOAMMStart);
        tckok.unlock(vm.addr(1));

        assertEq(tcko.balanceOf(vm.addr(1)), 1250e9);

        tcko.incrementDistroStage(DistroStage.Presale2Unlock);
        tckok.unlock(vm.addr(1));
        assertEq(tcko.balanceOf(vm.addr(1)), 2e12);

        tckok.unlockAllOdd();
        tcko.incrementDistroStage(DistroStage.FinalMint);

        assertEq(tcko.totalSupply(), 80e12);
        assertEq(tckok.totalSupply(), 0);

        mintAll(1e12);
        vm.expectRevert("TCKO-k: Not matured");
        tckok.unlockAllEven();

        assertEq(tcko.totalSupply(), 100e12);
        assertEq(tckok.totalSupply(), 15e12);

        vm.warp(1835470800000);

        tcko.incrementDistroStage(DistroStage.FinalUnlock);
        tckok.unlockAllEven();

        assertEq(tckok.totalSupply(), 0);
    }

    function testPreserveTotalPlusBurnedEqualsMinted() public {
        assertEq(tcko.totalSupply(), 20e12);
        assertEq(tckok.totalSupply(), 15e12);

        for (uint256 i = 9; i <= 20; ++i) {
            vm.prank(vm.addr(i));
            tcko.transfer(address(daoKasasi), 250e9);
        }

        assertEq(tcko.totalSupply(), 17e12);
        assertEq(tckok.totalSupply(), 15e12);
        assertEq(tcko.totalMinted(), 20e12);

        tcko.incrementDistroStage(DistroStage.Presale2);
        mintAll(1e12);

        assertEq(tcko.totalSupply(), 37e12);

        for (uint256 i = 9; i <= 20; ++i) {
            vm.prank(vm.addr(i));
            tcko.transfer(address(daoKasasi), 250e9);
        }

        assertEq(tcko.totalSupply(), 34e12);
    }

    function testPreservesIndividualBalances() public {
        for (uint256 i = 1; i < 20; ++i) {
            vm.prank(vm.addr(i));
            tcko.transfer(vm.addr(i + 1), 250e9);
        }

        assertEq(tcko.balanceOf(vm.addr(1)), 0);
        assertEq(tcko.balanceOf(vm.addr(2)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(20)), 500e9);
    }

    function testPreventOverspending() public {
        vm.prank(vm.addr(1));
        vm.expectRevert();
        tcko.transfer(vm.addr(2), 251e9);

        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(3), 250e9);
        assertEq(tcko.balanceOf(vm.addr(1)), 0);

        vm.prank(vm.addr(4));
        tcko.transfer(vm.addr(5), 250e9);
        vm.prank(vm.addr(5));
        vm.expectRevert();
        tcko.transfer(vm.addr(6), 750e9);
    }

    function testAuthorizedPartiesCanSpendOnOwnersBehalf() public {
        vm.prank(vm.addr(1));
        tcko.approve(vm.addr(2), 1e12);

        assertEq(tcko.allowance(vm.addr(1), vm.addr(2)), 1e12);

        vm.prank(vm.addr(2));
        tcko.transferFrom(vm.addr(1), vm.addr(3), 250e9);

        assertEq(tcko.allowance(vm.addr(1), vm.addr(2)), 750e9);
        assertEq(tcko.balanceOf(vm.addr(1)), 0);
        assertEq(tcko.balanceOf(vm.addr(2)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(3)), 500e9);
    }

    function testUsersCanAdjustAllowance() public {
        vm.startPrank(vm.addr(1));
        tcko.increaseAllowance(vm.addr(2), 3);

        vm.expectRevert(stdError.arithmeticError);
        tcko.increaseAllowance(vm.addr(2), type(uint256).max);

        vm.expectRevert(stdError.arithmeticError);
        tcko.decreaseAllowance(vm.addr(2), 4);

        tcko.decreaseAllowance(vm.addr(2), 2);
        vm.stopPrank();

        vm.startPrank(vm.addr(2));
        vm.expectRevert(stdError.arithmeticError);
        tcko.transferFrom(vm.addr(1), vm.addr(2), 2);

        tcko.transferFrom(vm.addr(1), vm.addr(2), 1);

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9 - 1);
        assertEq(tcko.balanceOf(vm.addr(2)), 250e9 + 1);
    }

    function testSnapshot0Preserved() public {
        tcko.setVotingContract0(address(this));
        tcko.snapshot0();

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 250e9);
        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 250e9);

        assertEq(tcko.balanceOf(vm.addr(2)), 500e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(3));
        tcko.transfer(vm.addr(1), 100e9);

        assertEq(tcko.balanceOf(vm.addr(3)), 150e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(3)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(1)), 100e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 250e9);

        tcko.snapshot0();
        assertEq(tcko.balanceOf(vm.addr(1)), 100e9);
        assertEq(tcko.balanceOf(vm.addr(2)), 500e9);
        assertEq(tcko.balanceOf(vm.addr(3)), 150e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 100e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 500e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(3)), 150e9);

        vm.startPrank(vm.addr(2));
        tcko.transfer(vm.addr(1), 50e9);
        tcko.transfer(vm.addr(3), 50e9);
        tcko.transfer(vm.addr(1), 50e9);
        tcko.transfer(vm.addr(3), 50e9);
        tcko.transfer(vm.addr(1), 50e9);
        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(2)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(3)), 250e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 100e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 500e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(3)), 150e9);
        vm.stopPrank();

        tcko.snapshot0();
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 250e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(3)), 250e9);
    }
}
