// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "contracts/TCKO.sol";
import "forge-std/Test.sol";
import "interfaces/testing/MockDAOKasasi.sol";

contract TCKOSnapshotTest is Test {
    TCKO private tcko;
    KilitliTCKO private tckok;
    IDAOKasasi private daoKasasi;

    function mintAll(uint256 amount) public {
        vm.startPrank(DEV_KASASI);
        for (uint256 i = 1; i <= 20; ++i)
            tcko.mint((amount << 160) | uint160(vm.addr(i)));
        vm.stopPrank();
    }

    function setUp() public {
        vm.prank(TCKO_DEPLOYER);
        tcko = new TCKO();

        vm.prank(TCKOK_DEPLOYER);
        tckok = new KilitliTCKO();

        vm.prank(DAO_KASASI_DEPLOYER);
        daoKasasi = new MockDAOKasasi();

        mintAll(1e12);
    }

    function testTransferFunction() public {
        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 250_000e6);
        assertEq(tcko.balanceOf(vm.addr(1)), 0);
        assertEq(tcko.balanceOf(vm.addr(2)), 500_000e6);
    }

    function testTransferFromFunction() public {
        vm.prank(vm.addr(1));
        tcko.approve(vm.addr(3), 250_000e6);

        vm.prank(vm.addr(3));
        tcko.transferFrom(vm.addr(1), vm.addr(2), 250_000e6);

        assertEq(tcko.balanceOf(vm.addr(1)), 0);
        assertEq(tcko.balanceOf(vm.addr(2)), 500_000e6);
    }

    function testSnapshot0() public {
        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 250_000e6);
        vm.prank(OYLAMA);
        tcko.snapshot0();

        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(vm.addr(3));
        tcko.transfer(vm.addr(2), 250_000e6);

        assertFalse(tcko.snapshot0BalanceOf(vm.addr(3)) == 0);
        assertFalse(tcko.snapshot0BalanceOf(vm.addr(2)) == 750_000e6);
    }

    function testSnapshot1() public {
        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 250_000e6);
        vm.prank(OYLAMA);
        tcko.snapshot1();

        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(vm.addr(3));
        tcko.transfer(vm.addr(2), 250_000e6);

        assertEq(tcko.snapshot1BalanceOf(vm.addr(3)), 250_000e6);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(2)), 500_000e6);
    }

    function testSnapshot2() public {
        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 250_000e6);
        vm.prank(OYLAMA);
        tcko.snapshot2();

        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(vm.addr(3));
        tcko.transfer(vm.addr(2), 250_000e6);

        assertEq(tcko.snapshot2BalanceOf(vm.addr(3)), 250_000e6);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(2)), 500_000e6);
    }

    function testAllSnapshotsTogether() public {
        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 250_000e6);

        vm.prank(OYLAMA);
        tcko.snapshot0();
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(vm.addr(3));
        tcko.transfer(vm.addr(2), 250_000e6);

        assertEq(tcko.snapshot0BalanceOf(vm.addr(3)), 250_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(OYLAMA);
        tcko.snapshot1();
        assertEq(tcko.snapshot0BalanceOf(vm.addr(3)), 250_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 500_000e6);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(3)), 0);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(2)), 750_000e6);

        vm.prank(vm.addr(4));
        tcko.transfer(vm.addr(2), 250_000e6);

        assertEq(tcko.snapshot0BalanceOf(vm.addr(4)), 250_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 500_000e6);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(4)), 250_000e6);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(2)), 750_000e6);

        vm.prank(OYLAMA);
        tcko.snapshot2();
        assertEq(tcko.snapshot2BalanceOf(vm.addr(4)), 0);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(2)), 1e12);

        assertEq(tcko.snapshot0BalanceOf(vm.addr(4)), 250_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 500_000e6);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(4)), 250_000e6);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(2)), 750_000e6);
    }
}
