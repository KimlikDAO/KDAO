//SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "contracts/TCKO.sol";
import "forge-std/Test.sol";
import "interfaces/testing/MockDAOKasasi.sol";

contract TCKOTest is Test {
    TCKO private tcko;
    KilitliTCKO private tckok;
    IDAOKasasi private daoKasasi;

    function setUp() public {
        vm.prank(TCKO_DEPLOYER);
        tcko = new TCKO();

        vm.prank(TCKOK_DEPLOYER);
        tckok = new KilitliTCKO();

        vm.prank(DAO_KASASI_DEPLOYER);
        daoKasasi = new MockDAOKasasi();

        mintAll(1e12);
    }

    function mintAll(uint256 amount) public {
        vm.startPrank(DEV_KASASI);
        for (uint256 i = 1; i <= 20; ++i)
            tcko.mint((amount << 160) | uint160(vm.addr(i)));
        vm.stopPrank();
    }

    function testDAOAuthentication() public {
        vm.expectRevert();
        tcko.mint((uint256(1) << 160) | uint160(vm.addr(1)));

        uint256[10] memory accounts = [
            (uint256(1) << 160) | 1,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0
        ];

        vm.expectRevert();
        tcko.mintBulk(accounts);

        vm.expectRevert();
        tcko.setPresale2Contract(vm.addr(1337));

        vm.expectRevert();
        tcko.incrementDistroStage(DistroStage.Presale2);
    }

    function testSnapshotAuthentication() public {
        vm.expectRevert();
        tcko.snapshot0();

        vm.expectRevert();
        tcko.snapshot1();

        vm.expectRevert();
        tcko.snapshot2();

        vm.startPrank(OYLAMA);
        tcko.snapshot0();
        tcko.snapshot1();
        tcko.snapshot2();
        vm.stopPrank();
    }

    function testShouldCompleteAllRounds() public {
        assertEq(tcko.totalSupply(), 20e12);
        assertEq(tckok.totalSupply(), 15e12);

        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 250_000e6);

        assertEq(tcko.balanceOf(vm.addr(1)), 0);
        assertEq(tcko.balanceOf(vm.addr(2)), 500_000e6);

        vm.prank(DEV_KASASI);
        tcko.incrementDistroStage(DistroStage.Presale2);
        mintAll(1e12);

        assertEq(tcko.totalSupply(), 40e12);
        assertEq(tckok.totalSupply(), 30e12);

        vm.prank(DEV_KASASI);
        tcko.incrementDistroStage(DistroStage.DAOSaleStart);

        assertEq(tcko.totalSupply(), 60e12);
        assertEq(tckok.totalSupply(), 30e12);
        assertEq(tcko.balanceOf(DAO_KASASI), 20e12);

        vm.prank(DEV_KASASI);
        tcko.incrementDistroStage(DistroStage.DAOSaleEnd);

        tckok.unlock(vm.addr(1));
        tckok.unlock(vm.addr(2));

        assertEq(tcko.balanceOf(vm.addr(1)), 1e12);
        assertEq(tcko.balanceOf(vm.addr(2)), 1_500e9);

        tckok.unlockAllEven();

        assertEq(tckok.balanceOf(vm.addr(1)), 750e9);
        assertEq(tckok.balanceOf(vm.addr(2)), 750e9);

        vm.prank(DEV_KASASI);
        tcko.incrementDistroStage(DistroStage.DAOAMMStart);

        assertEq(tcko.totalSupply(), 80e12);
        assertEq(tckok.totalSupply(), 15e12);

        vm.prank(DEV_KASASI);
        tcko.incrementDistroStage(DistroStage.Presale2Unlock);

        tckok.unlockAllOdd();

        vm.prank(DEV_KASASI);
        tcko.incrementDistroStage(DistroStage.FinalMint);
        mintAll(1e12);

        assertEq(tckok.unlock(vm.addr(1)), false);

        assertEq(tckok.balanceOf(vm.addr(1)), 750e9);

        vm.warp(1925097600);
        vm.prank(DEV_KASASI);
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

        vm.prank(DEV_KASASI);
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

        vm.prank(DEV_KASASI);
        tcko.incrementDistroStage(DistroStage.DAOSaleStart);

        vm.expectRevert("TCKO-k: Not matured");
        tckok.unlockAllEven();
        vm.expectRevert("TCKO-k: Not matured");
        tckok.unlockAllOdd();

        vm.prank(DEV_KASASI);
        tcko.incrementDistroStage(DistroStage.DAOSaleEnd);

        vm.expectRevert("TCKO-k: Not matured");
        tckok.unlockAllOdd();
        tckok.unlockAllEven();

        assertEq(tcko.balanceOf(vm.addr(2)), 1250e9);

        vm.prank(DEV_KASASI);
        tcko.incrementDistroStage(DistroStage.DAOAMMStart);
        tckok.unlock(vm.addr(1));

        assertEq(tcko.balanceOf(vm.addr(1)), 1250e9);

        vm.prank(DEV_KASASI);
        tcko.incrementDistroStage(DistroStage.Presale2Unlock);
        tckok.unlock(vm.addr(1));
        assertEq(tcko.balanceOf(vm.addr(1)), 2e12);

        tckok.unlockAllOdd();

        vm.prank(DEV_KASASI);
        tcko.incrementDistroStage(DistroStage.FinalMint);

        assertEq(tcko.totalSupply(), 80e12);
        assertEq(tckok.totalSupply(), 0);

        mintAll(1e12);
        vm.expectRevert("TCKO-k: Not matured");
        tckok.unlockAllEven();

        assertEq(tcko.totalSupply(), 100e12);
        assertEq(tckok.totalSupply(), 15e12);

        vm.warp(1835470800000);

        vm.prank(DEV_KASASI);
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

        vm.prank(DEV_KASASI);
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

    function testTransferGas() public {
        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 250e9);
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
        vm.prank(OYLAMA);
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

        vm.prank(OYLAMA);
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
        vm.stopPrank();
        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(2)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(3)), 250e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 100e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 500e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(3)), 150e9);

        vm.prank(OYLAMA);
        tcko.snapshot0();
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(2)), 250e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(3)), 250e9);
    }

    function testSnapshot0PreservedOnSelfTransfer() public {
        vm.prank(OYLAMA);
        tcko.snapshot0();

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(1), 250e9);

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 250e9);

        vm.prank(OYLAMA);
        tcko.snapshot0();

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(1), 100e9);

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr(1)), 250e9);
    }

    function testSnapshot0Fuzz(
        uint8 from,
        uint8 to,
        uint256 amount
    ) public {
        vm.assume(from % 20 != to % 20);
        amount %= 250e9;

        vm.prank(OYLAMA);
        tcko.snapshot0();

        vm.prank(vm.addr((from % 20) + 1));
        tcko.transfer(vm.addr((to % 20) + 1), amount);

        assertEq(tcko.balanceOf(vm.addr((from % 20) + 1)), 250e9 - amount);
        assertEq(tcko.balanceOf(vm.addr((to % 20) + 1)), 250e9 + amount);
        assertEq(tcko.snapshot0BalanceOf(vm.addr((from % 20) + 1)), 250e9);
        assertEq(tcko.snapshot0BalanceOf(vm.addr((to % 20) + 1)), 250e9);
    }

    function testSnapshot1Preserved() public {
        vm.prank(OYLAMA);
        tcko.snapshot1();

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 250e9);
        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 250e9);

        assertEq(tcko.balanceOf(vm.addr(2)), 500e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(2)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(3));
        tcko.transfer(vm.addr(1), 100e9);

        assertEq(tcko.balanceOf(vm.addr(3)), 150e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(3)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(1)), 100e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 250e9);

        vm.prank(OYLAMA);
        tcko.snapshot1();
        assertEq(tcko.balanceOf(vm.addr(1)), 100e9);
        assertEq(tcko.balanceOf(vm.addr(2)), 500e9);
        assertEq(tcko.balanceOf(vm.addr(3)), 150e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 100e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(2)), 500e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(3)), 150e9);

        vm.startPrank(vm.addr(2));
        tcko.transfer(vm.addr(1), 50e9);
        tcko.transfer(vm.addr(3), 50e9);
        tcko.transfer(vm.addr(1), 50e9);
        tcko.transfer(vm.addr(3), 50e9);
        tcko.transfer(vm.addr(1), 50e9);
        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(2)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(3)), 250e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 100e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(2)), 500e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(3)), 150e9);
        vm.stopPrank();

        vm.prank(OYLAMA);
        tcko.snapshot1();
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(2)), 250e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(3)), 250e9);
    }

    function testSnapshot1PreservedOnSelfTransfer() public {
        vm.prank(OYLAMA);
        tcko.snapshot1();

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(1), 250e9);

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 250e9);

        vm.prank(OYLAMA);
        tcko.snapshot1();

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(1), 100e9);

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr(1)), 250e9);
    }

    function testSnapshot1Fuzz(
        uint8 from,
        uint8 to,
        uint256 amount
    ) public {
        vm.assume(from % 20 != to % 20);

        amount %= 250e9;
        vm.prank(OYLAMA);
        tcko.snapshot1();

        vm.prank(vm.addr((from % 20) + 1));
        tcko.transfer(vm.addr((to % 20) + 1), amount);

        assertEq(tcko.balanceOf(vm.addr((from % 20) + 1)), 250e9 - amount);
        assertEq(tcko.balanceOf(vm.addr((to % 20) + 1)), 250e9 + amount);
        assertEq(tcko.snapshot1BalanceOf(vm.addr((from % 20) + 1)), 250e9);
        assertEq(tcko.snapshot1BalanceOf(vm.addr((to % 20) + 1)), 250e9);
    }

    function testSnapshot2Preserved() public {
        vm.prank(OYLAMA);
        tcko.snapshot2();

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 250e9);
        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(2), 250e9);

        assertEq(tcko.balanceOf(vm.addr(2)), 500e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(2)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(1)), 0);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(3));
        tcko.transfer(vm.addr(1), 100e9);

        assertEq(tcko.balanceOf(vm.addr(3)), 150e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(3)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(1)), 100e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 250e9);

        vm.prank(OYLAMA);
        tcko.snapshot2();
        assertEq(tcko.balanceOf(vm.addr(1)), 100e9);
        assertEq(tcko.balanceOf(vm.addr(2)), 500e9);
        assertEq(tcko.balanceOf(vm.addr(3)), 150e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 100e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(2)), 500e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(3)), 150e9);

        vm.startPrank(vm.addr(2));
        tcko.transfer(vm.addr(1), 50e9);
        tcko.transfer(vm.addr(3), 50e9);
        tcko.transfer(vm.addr(1), 50e9);
        tcko.transfer(vm.addr(3), 50e9);
        tcko.transfer(vm.addr(1), 50e9);
        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(2)), 250e9);
        assertEq(tcko.balanceOf(vm.addr(3)), 250e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 100e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(2)), 500e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(3)), 150e9);
        vm.stopPrank();

        vm.prank(OYLAMA);
        tcko.snapshot2();
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(2)), 250e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(3)), 250e9);
    }

    function testSnapshot2PreservedOnSelfTransfer() public {
        vm.prank(OYLAMA);
        tcko.snapshot2();

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(1), 250e9);

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 250e9);

        vm.prank(OYLAMA);
        tcko.snapshot2();

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(1));
        tcko.transfer(vm.addr(1), 100e9);

        assertEq(tcko.balanceOf(vm.addr(1)), 250e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr(1)), 250e9);
    }

    function testSnapshot2Fuzz(
        uint8 from,
        uint8 to,
        uint256 amount
    ) public {
        vm.assume(from % 20 != to % 20);

        amount %= 250e9;
        vm.prank(OYLAMA);
        tcko.snapshot2();

        vm.prank(vm.addr((from % 20) + 1));
        tcko.transfer(vm.addr((to % 20) + 1), amount);

        assertEq(tcko.balanceOf(vm.addr((from % 20) + 1)), 250e9 - amount);
        assertEq(tcko.balanceOf(vm.addr((to % 20) + 1)), 250e9 + amount);
        assertEq(tcko.snapshot2BalanceOf(vm.addr((from % 20) + 1)), 250e9);
        assertEq(tcko.snapshot2BalanceOf(vm.addr((to % 20) + 1)), 250e9);
    }

    function authorizePayment(
        uint256 ownerPrivateKey,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint256 nonce
    )
        internal
        view
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                tcko.DOMAIN_SEPARATOR(),
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

    function testPermit() public {
        vm.prank(vm.addr(2));
        vm.expectRevert(stdError.arithmeticError);
        tcko.transferFrom(vm.addr(1), vm.addr(2), 250e9);

        uint256 time = block.timestamp + 1000;
        (uint8 v, bytes32 r, bytes32 s) = authorizePayment(
            1,
            vm.addr(2),
            250e9,
            time,
            0
        );
        tcko.permit(vm.addr(1), vm.addr(2), 250e9, time, v, r, s);
        vm.prank(vm.addr(2));
        tcko.transferFrom(vm.addr(1), vm.addr(2), 250e9);
        assertEq(tcko.balanceOf(vm.addr(2)), 500e9);
    }

    function testTokenMethods() external {
        assertEq(tcko.decimals(), tckok.decimals());
        // Increase coverage so we can always aim at 100%.
        assertEq(tcko.name(), "KimlikDAO Tokeni");
        assertEq(tckok.name(), "Kilitli TCKO");
        assertEq(tcko.maxSupply(), 100_000_000e6);

        assertEq(tcko.circulatingSupply(), 5_000_000e6);
        assertEq(
            bytes32(bytes(tckok.symbol()))[0],
            bytes32(bytes(tcko.symbol()))[0]
        );
        assertEq(
            bytes32(bytes(tckok.symbol()))[1],
            bytes32(bytes(tcko.symbol()))[1]
        );
        assertEq(
            bytes32(bytes(tckok.symbol()))[2],
            bytes32(bytes(tcko.symbol()))[2]
        );
        assertEq(
            bytes32(bytes(tckok.symbol()))[3],
            bytes32(bytes(tcko.symbol()))[3]
        );
    }

    event Transfer(address indexed from, address indexed to, uint256 amount);

    function testTransfer() external {
        vm.startPrank(vm.addr(1));

        vm.expectRevert();
        tcko.transfer(address(0), 250_000e6);

        vm.expectRevert();
        tcko.transfer(address(tcko), 250_000e6);

        vm.expectRevert();
        tcko.transfer(address(tckok), 250_000e6);

        vm.expectRevert();
        tcko.transfer(vm.addr(2), 251_000e6);

        vm.expectEmit(true, true, false, true, address(tcko));
        emit Transfer(vm.addr(1), vm.addr(2), 250_000e6);
        tcko.transfer(vm.addr(2), 250_000e6);

        assertEq(tcko.totalSupply(), 20_000_000e6);

        vm.stopPrank();

        vm.startPrank(vm.addr(2));

        tcko.transfer(DAO_KASASI, 500_000e6);

        assertEq(tcko.totalSupply() + 500_000e6, tcko.supplyCap());

        vm.stopPrank();

        vm.startPrank(DEV_KASASI);
        vm.expectRevert();
        tcko.incrementDistroStage(DistroStage.Presale1);

        tcko.incrementDistroStage(DistroStage.Presale2);
        vm.stopPrank();
        mintAll(1e12);

        assertEq(tcko.totalSupply() + 500_000e6, tcko.supplyCap());

        vm.prank(DEV_KASASI);
        tcko.incrementDistroStage(DistroStage.DAOSaleStart);

        assertEq(tcko.supplyCap(), 60_000_000e6);
        assertEq(tcko.totalSupply() + 500_000e6, tcko.supplyCap());
        assertEq(
            tcko.circulatingSupply(),
            20_000_000e6 + 40_000_000e6 / 4 - 500_000e6
        );
    }

    function testTransferFrom() external {
        vm.startPrank(vm.addr(1));
        tcko.approve(vm.addr(11), 200_000e6);
        tcko.approve(address(tcko), 50_000e6);
        tcko.approve(address(0), 50_000e6);
        tcko.approve(address(tckok), 50_000e6);
        vm.stopPrank();

        vm.startPrank(vm.addr(11));
        vm.expectRevert();
        tcko.transferFrom(vm.addr(1), vm.addr(2), 201_000e6);

        vm.expectRevert();
        tcko.transferFrom(vm.addr(1), address(0), 200_000e6);

        vm.expectRevert();
        tcko.transferFrom(vm.addr(1), address(tcko), 200_000e6);

        vm.expectRevert();
        tcko.transferFrom(vm.addr(1), address(tckok), 200_000e6);

        tcko.transferFrom(vm.addr(1), vm.addr(2), 200_000e6);

        assertEq(tcko.balanceOf(vm.addr(1)), 50_000e6);
        assertEq(tcko.balanceOf(vm.addr(2)), 450_000e6);
        assertEq(tckok.balanceOf(vm.addr(1)), 750_000e6);
        assertEq(tckok.balanceOf(vm.addr(2)), 750_000e6);

        vm.stopPrank();

        vm.prank(vm.addr(3));
        tcko.approve(vm.addr(13), 150_000e6);

        vm.startPrank(vm.addr(13));
        tcko.transferFrom(vm.addr(3), DAO_KASASI, 150_000e6);

        assertEq(tcko.balanceOf(vm.addr(3)), 100_000e6);
        assertEq(tcko.totalSupply(), 20_000_000e6 - 150_000e6);

        vm.stopPrank();

        vm.prank(vm.addr(4));
        tcko.approve(vm.addr(14), 251_000e6);

        vm.startPrank(vm.addr(14));
        vm.expectRevert();
        tcko.transferFrom(vm.addr(4), vm.addr(5), 251_000e6);

        vm.stopPrank();
    }

    function testPresale2Contract() external {
        vm.expectRevert();
        tcko.setPresale2Contract(vm.addr(0x94E008A7E2));

        vm.startPrank(DEV_KASASI);
        tcko.setPresale2Contract(vm.addr(0x94E008A7E2));
        tcko.incrementDistroStage(DistroStage.Presale2);
        vm.stopPrank();

        vm.startPrank(vm.addr(0x94E008A7E2));
        vm.expectRevert();
        tcko.mint(uint160(address(tckok)) | (1 << 160));
        vm.expectRevert();
        tcko.mint(uint160(address(DAO_KASASI)) | (1 << 160));

        tcko.mint(uint160(vm.addr(1)) | (20_000_000e6 << 160));
        vm.expectRevert();
        tcko.mint(uint160(vm.addr(1)) | (1 << 160));
        vm.stopPrank();

        assertEq(tcko.balanceOf(vm.addr(1)), 5_250_000e6);
    }
}
