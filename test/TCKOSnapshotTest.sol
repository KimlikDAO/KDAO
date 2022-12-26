// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

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

    function testAuthentication() public {
        vm.expectRevert();
        tcko.snapshot0();
        vm.expectRevert();
        tcko.snapshot1();
        vm.expectRevert();
        tcko.snapshot1();

        vm.startPrank(OYLAMA);
        tcko.snapshot0();
        tcko.snapshot1();
        tcko.snapshot2();
        vm.stopPrank();

        vm.expectRevert();
        tcko.consumeSnapshot0Balance(vm.addr(1));
        vm.expectRevert();
        tcko.consumeSnapshot1Balance(vm.addr(1));
        vm.expectRevert();
        tcko.consumeSnapshot2Balance(vm.addr(1));

        vm.startPrank(OYLAMA);
        tcko.consumeSnapshot0Balance(vm.addr(1));
        tcko.consumeSnapshot1Balance(vm.addr(1));
        tcko.consumeSnapshot2Balance(vm.addr(1));
        vm.stopPrank();
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

    function testAllSnapshotsRepeatedly() public {
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

    function testUsingSnapshotMultipleTimes() public {
        uint256 balance = tcko.balanceOf(vm.addr(1));
        for (uint256 i = 1; i <= 10; ++i) {
            vm.prank(OYLAMA);
            tcko.snapshot0();

            uint256 amount = i * 10e6;
            for (uint256 x = 1; x <= 20; ++x) {
                vm.prank(vm.addr(x));
                tcko.transfer(vm.addr(50), amount);
            }

            for (uint256 y = 1; y <= 20; ++y) {
                assertEq(tcko.snapshot0BalanceOf(vm.addr(y)), balance);
            }

            balance = balance - amount;
        }
    }

    function testSnapshotValuesArePreserved() public {
        uint256 balance = tcko.balanceOf(vm.addr(1));
        for (uint256 i = 1; i <= 20; ++i) {
            vm.prank(OYLAMA);
            tcko.snapshot1();

            uint256 amount = i * 10e6;
            for (uint256 j = 1; j <= 20; ++j) {
                vm.prank(vm.addr(j));
                tcko.transfer(vm.addr((j % 20) + 1), amount);
            }

            for (uint256 j = 1; j <= 20; ++j) {
                assertEq(tcko.balanceOf(vm.addr(i)), balance);
                assertEq(tcko.snapshot1BalanceOf(vm.addr(j)), balance);
            }

            for (uint256 j = 1; j <= 20; ++j) {
                vm.prank(vm.addr(j));
                tcko.transfer(vm.addr(50), amount);
            }

            for (uint256 j = 1; j <= 20; ++j) {
                assertEq(tcko.balanceOf(vm.addr(i)), balance - amount);
                assertEq(tcko.snapshot1BalanceOf(vm.addr(j)), balance);
            }

            for (uint256 j = 1; j <= 20; ++j) {
                vm.prank(vm.addr(50));
                tcko.transfer(vm.addr(j), amount);
            }

            for (uint256 j = 1; j <= 20; ++j) {
                assertEq(tcko.balanceOf(vm.addr(i)), balance);
                assertEq(tcko.snapshot1BalanceOf(vm.addr(j)), balance);
            }

            for (uint256 j = 1; j <= 20; ++j) {
                vm.prank(vm.addr(j));
                tcko.transfer(vm.addr(50), amount);
            }

            balance = balance - amount;
        }
    }

    function testSnapshot0WrapsAround() public {
        vm.prank(OYLAMA);
        tcko.snapshot0();
        vm.store(
            address(tcko),
            bytes32(uint256(6)),
            bytes32(((uint256(1) << 24) - 1) << 232)
        );

        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 250_000e6);

        assertEq(tcko.balanceOf(vm.addr(1)), 0);
        assertEq(tcko.balanceOf(vm.addr(2)), 500_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 250_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 250_000e6);

        vm.prank(OYLAMA);
        tcko.snapshot0();
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(vm.addr(2));
        tcko.transfer(vm.addr(1), 250_000e6);
        assertEq(tcko.balanceOf(vm.addr(1)), 250_000e6);
        assertEq(tcko.balanceOf(vm.addr(2)), 250_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(OYLAMA);
        tcko.snapshot0();
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 250_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 250_000e6);
    }

    function testSnapshot1WrapsAround() public {
        vm.prank(OYLAMA);
        tcko.snapshot0();
        assertEq(
            uint256(vm.load(address(tcko), bytes32(uint256(6)))) >> 232,
            1
        );
        vm.store(
            address(tcko),
            bytes32(uint256(6)),
            bytes32(((uint256(1) << 21) - 1) << 212)
        );
        assertEq(
            uint256(vm.load(address(tcko), bytes32(uint256(6)))) >> 232,
            1
        );

        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 250_000e6);

        assertEq(tcko.balanceOf(vm.addr(1)), 0);
        assertEq(tcko.balanceOf(vm.addr(2)), 500_000e6);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 250_000e6);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(2)), 250_000e6);

        vm.prank(OYLAMA);
        tcko.snapshot1();

        assertEq(
            uint256(vm.load(address(tcko), bytes32(uint256(6)))) >> 232,
            1
        );
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(vm.addr(2));
        tcko.transfer(vm.addr(1), 250_000e6);
        assertEq(tcko.balanceOf(vm.addr(1)), 250_000e6);
        assertEq(tcko.balanceOf(vm.addr(2)), 250_000e6);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(OYLAMA);
        tcko.snapshot1();
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 250_000e6);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(2)), 250_000e6);
    }

    function testSnapshot2WrapsAround() public {
        vm.prank(OYLAMA);
        tcko.snapshot1();
        assertEq(
            uint256(vm.load(address(tcko), bytes32(uint256(6)))) >> 212,
            1
        );
        vm.store(
            address(tcko),
            bytes32(uint256(6)),
            bytes32(((uint256(1) << 21) - 1) << 192)
        );
        assertEq(
            uint256(vm.load(address(tcko), bytes32(uint256(6)))) >> 212,
            1
        );

        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 250_000e6);

        assertEq(tcko.balanceOf(vm.addr(1)), 0);
        assertEq(tcko.balanceOf(vm.addr(2)), 500_000e6);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 250_000e6);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(2)), 250_000e6);

        vm.prank(OYLAMA);
        tcko.snapshot2();

        assertEq(
            uint256(vm.load(address(tcko), bytes32(uint256(6)))) >> 212,
            1
        );
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(vm.addr(2));
        tcko.transfer(vm.addr(1), 250_000e6);
        assertEq(tcko.balanceOf(vm.addr(1)), 250_000e6);
        assertEq(tcko.balanceOf(vm.addr(2)), 250_000e6);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(OYLAMA);
        tcko.snapshot2();
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 250_000e6);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(2)), 250_000e6);
    }

    function testConsumeSnapshotNBalance3Snapshots() public {
        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(1 + 1), 50_000e6);

        vm.startPrank(OYLAMA);
        tcko.snapshot0();
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 200_000e6);
        uint256 snapshot0Balance = tcko.snapshot0BalanceOf(vm.addr(1));
        uint256 snapshot0ConsumedBalance = tcko.consumeSnapshot0Balance(
            vm.addr(1)
        );
        vm.stopPrank();
        assertEq(snapshot0Balance, 200_000e6);
        assertEq(snapshot0Balance, snapshot0ConsumedBalance);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1 + 1)), 300_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 0);

        vm.prank(vm.addr(1 + 1));
        tcko.transfer(vm.addr(1), 50_000e6);

        vm.startPrank(OYLAMA);
        tcko.snapshot1();
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 250_000e6);
        uint256 snapshot1Balance = tcko.snapshot1BalanceOf(vm.addr(1));
        uint256 snapshot1ConsumedBalance = tcko.consumeSnapshot1Balance(
            vm.addr(1)
        );
        vm.stopPrank();
        assertEq(snapshot1Balance, 250_000e6);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 0);
        assertEq(snapshot1Balance, snapshot1ConsumedBalance);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1 + 1)), 250_000e6);

        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(1 + 1), 25_000e6);

        vm.startPrank(OYLAMA);
        tcko.snapshot2();
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 225_000e6);
        uint256 snapshot2Balance = tcko.snapshot2BalanceOf(vm.addr(1));
        uint256 snapshot2ConsumedBalance = tcko.consumeSnapshot2Balance(
            vm.addr(1)
        );
        vm.stopPrank();
        assertEq(snapshot2Balance, 225_000e6);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 0);
        assertEq(snapshot2Balance, snapshot2ConsumedBalance);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1 + 1)), 275_000e6);
    }

    function testConsumeSnapshot0Balance() public {
        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 100_000e6);

        vm.startPrank(OYLAMA);
        tcko.snapshot0();
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 150_000e6);
        assertEq(
            tcko.snapshot0BalanceOf(vm.addr(1)),
            tcko.consumeSnapshot0Balance(vm.addr(1))
        );
        vm.stopPrank();
        assertEq(tcko.balanceOf(vm.addr(1)), 150_000e6);
        assertEq(tcko.balanceOf(vm.addr(2)), 350_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 350_000e6);

        vm.prank(OYLAMA);
        assertEq(tcko.consumeSnapshot0Balance(vm.addr(2)), 350_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 0);
        assertEq(tcko.balanceOf(vm.addr(2)), 350_000e6);
    }

    function testConsumeSnapshot1Balance() public {
        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 100_000e6);

        vm.startPrank(OYLAMA);
        tcko.snapshot1();
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 150_000e6);
        assertEq(
            tcko.snapshot1BalanceOf(vm.addr(1)),
            tcko.consumeSnapshot1Balance(vm.addr(1))
        );
        vm.stopPrank();
        assertEq(tcko.balanceOf(vm.addr(1)), 150_000e6);
        assertEq(tcko.balanceOf(vm.addr(2)), 350_000e6);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(2)), 350_000e6);

        vm.prank(OYLAMA);
        assertEq(tcko.consumeSnapshot1Balance(vm.addr(2)), 350_000e6);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(2)), 0);
        assertEq(tcko.balanceOf(vm.addr(2)), 350_000e6);
    }

    function testConsumeSnapshot2Balance() public {
        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 100_000e6);

        vm.startPrank(OYLAMA);
        tcko.snapshot2();
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 150_000e6);
        assertEq(
            tcko.snapshot2BalanceOf(vm.addr(1)),
            tcko.consumeSnapshot2Balance(vm.addr(1))
        );
        vm.stopPrank();
        assertEq(tcko.balanceOf(vm.addr(1)), 150_000e6);
        assertEq(tcko.balanceOf(vm.addr(2)), 350_000e6);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(2)), 350_000e6);

        vm.prank(OYLAMA);
        assertEq(tcko.consumeSnapshot2Balance(vm.addr(2)), 350_000e6);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(2)), 0);
        assertEq(tcko.balanceOf(vm.addr(2)), 350_000e6);
    }

    function testConsumeSnapshotBalanceWithTransactions() public {
        vm.prank(OYLAMA);
        tcko.snapshot0();

        for (uint256 i = 1; i <= 4; ++i) {
            assertEq(tcko.balanceOf(vm.addr(i)), 250_000e6);
            assertEq(tcko.snapshot0BalanceOf(vm.addr(i)), 250_000e6);
        }

        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 250_000e6);

        assertEq(tcko.balanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 250_000e6);

        assertEq(tcko.balanceOf(vm.addr(2)), 500_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 250_000e6);

        uint256 totalSupply = tcko.totalSupply();
        vm.prank(vm.addr(3));
        tcko.transfer(DAO_KASASI, 250_000e6);

        assertEq(tcko.totalSupply(), totalSupply - 250_000e6);
        assertEq(tcko.balanceOf(vm.addr(3)), 0);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(3)), 250_000e6);

        vm.prank(vm.addr(2));
        tcko.transfer(vm.addr(1), 250_000e6);

        assertEq(tcko.balanceOf(vm.addr(1)), 250_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 250_000e6);

        assertEq(tcko.balanceOf(vm.addr(2)), 250_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 250_000e6);

        vm.prank(vm.addr(4));
        tcko.transfer(vm.addr(3), 100_000e6);

        assertEq(tcko.balanceOf(vm.addr(3)), 100_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(3)), 250_000e6);

        assertEq(tcko.balanceOf(vm.addr(4)), 150_000e6);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(4)), 250_000e6);

        vm.startPrank(OYLAMA);
        for (uint256 i = 1; i <= 4; ++i) {
            assertEq(
                tcko.snapshot0BalanceOf(vm.addr(i)),
                tcko.consumeSnapshot0Balance(vm.addr(i))
            );

            assertEq(tcko.snapshot0BalanceOf(vm.addr(i)), 0);
        }
        vm.stopPrank();

        assertEq(tcko.balanceOf(vm.addr(1)), 250_000e6);
        assertEq(tcko.balanceOf(vm.addr(2)), 250_000e6);
        assertEq(tcko.balanceOf(vm.addr(3)), 100_000e6);
        assertEq(tcko.balanceOf(vm.addr(4)), 150_000e6);
    }

    function testBalanceIsPreservedAfterConsume() external {
        assertEq(tcko.balanceOf(vm.addr(1)), 250_000e6);
        vm.prank(OYLAMA);
        tcko.snapshot2();
        vm.prank(OYLAMA);
        tcko.consumeSnapshot2Balance(vm.addr(1));
        assertEq(tcko.balanceOf(vm.addr(1)), 250_000e6);
    }
}
