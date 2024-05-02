// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {DistroStage} from "interfaces/kimlikdao/IDistroStage.sol";
import {DEV_FUND, KDAO_LOCKED, KDAO_ZKSYNC, VOTING} from "interfaces/kimlikdao/addresses.sol";
import {amountAddrFrom} from "interfaces/types/amountAddr.sol";
import {KDAO} from "zksync/KDAO.sol";
import {KDAOLocked} from "zksync/KDAOLocked.sol";

contract KDAOUnlockTest is Test {
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

    function testShouldNotUnlockBeforeMaturity() public {
        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllEven();

        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllOdd();

        kdaol.unlock(vm.addr(10));
        assertEq(kdao.balanceOf(vm.addr(10)), 250e9);
        assertEq(kdaol.balanceOf(vm.addr(10)), 750e9);

        vm.prank(VOTING);
        kdao.incrementDistroStage(DistroStage.Presale2);

        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllEven();
        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllOdd();

        mintAll(1e12, VOTING);

        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllEven();
        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllOdd();

        vm.prank(VOTING);
        kdao.incrementDistroStage(DistroStage.ProtocolSaleStart);

        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllEven();
        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllOdd();

        vm.prank(VOTING);
        kdao.incrementDistroStage(DistroStage.ProtocolSaleEnd);

        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllOdd();
        kdaol.unlockAllEven();

        assertEq(kdao.balanceOf(vm.addr(2)), 1250e9);

        vm.prank(VOTING);
        kdao.incrementDistroStage(DistroStage.ProtocolAMMStart);
        kdaol.unlock(vm.addr(1));

        assertEq(kdao.balanceOf(vm.addr(1)), 1250e9);

        vm.prank(VOTING);
        kdao.incrementDistroStage(DistroStage.Presale2Unlock);
        kdaol.unlock(vm.addr(1));
        assertEq(kdao.balanceOf(vm.addr(1)), 2e12);

        kdaol.unlockAllOdd();

        vm.prank(VOTING);
        kdao.incrementDistroStage(DistroStage.FinalMint);

        assertEq(kdao.totalSupply(), 80e12);
        assertEq(kdaol.totalSupply(), 0);

        vm.prank(DEV_FUND);
        kdao.mint(amountAddrFrom(20_000_000e6, DEV_FUND));

        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllEven();

        assertEq(kdao.totalSupply(), 100e12);
        assertEq(kdaol.totalSupply(), 15e12);

        vm.warp(1835470800000);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.FinalUnlock);
        kdaol.unlockAllEven();

        assertEq(kdaol.totalSupply(), 0);
        assertEq(kdao.balanceOf(DEV_FUND), 20_000_000e6);
    }
}
