//SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "contracts/TCKO.sol";
import "./MockDAOKasasi.sol";

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
}
