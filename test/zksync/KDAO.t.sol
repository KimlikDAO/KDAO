// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test, stdError} from "forge-std/Test.sol";
import {DistroStage} from "interfaces/kimlikdao/IDistroStage.sol";
import {
    DEV_FUND,
    KDAO_LOCKED,
    KDAO_LOCKED_DEPLOYER,
    KDAO_ZKSYNC,
    KDAO_ZKSYNC_DEPLOYER,
    PROTOCOL_FUND_ZKSYNC,
    VOTING
} from "interfaces/kimlikdao/addresses.sol";
import {amountAddrFrom} from "interfaces/types/amountAddr.sol";
import {uint48x2From} from "interfaces/types/uint48x2.sol";
import {computeCreateAddress as computeZkSyncCreateAddress} from "interfaces/zksync/IZkSync.sol";
import {KDAO} from "zksync/KDAO.sol";
import {KDAOLocked} from "zksync/KDAOLocked.sol";

contract KDAOTest is Test {
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

    function testAddressConsistency() external pure {
        assertEq(computeZkSyncCreateAddress(KDAO_LOCKED_DEPLOYER, 0), KDAO_LOCKED);
        assertEq(computeZkSyncCreateAddress(KDAO_ZKSYNC_DEPLOYER, 0), KDAO_ZKSYNC);
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

    function testMetadataMethods() external view {
        assertEq(kdao.decimals(), kdaol.decimals());
        // Increase coverage so we can always aim at 100%.
        assertEq(kdao.name(), "KimlikDAO");
        assertEq(kdaol.name(), "Locked KDAO");

        assertEq(kdao.circulatingSupply(), 5_000_000e6);
        assertEq(bytes32(bytes(kdaol.symbol()))[0], bytes32(bytes(kdao.symbol()))[0]);
        assertEq(bytes32(bytes(kdaol.symbol()))[1], bytes32(bytes(kdao.symbol()))[1]);
        assertEq(bytes32(bytes(kdaol.symbol()))[2], bytes32(bytes(kdao.symbol()))[2]);
        assertEq(bytes32(bytes(kdaol.symbol()))[3], bytes32(bytes(kdao.symbol()))[3]);
    }

    event Transfer(address indexed from, address indexed to, uint256 amount);

    function testTransfer() external {
        vm.startPrank(vm.addr(1));

        vm.expectRevert();
        kdao.transfer(address(kdao), 250_000e6);

        vm.expectRevert();
        kdao.transfer(address(kdaol), 250_000e6);

        vm.expectRevert();
        kdao.transfer(vm.addr(2), 251_000e6);

        vm.expectEmit(true, true, false, true, address(kdao));
        emit Transfer(vm.addr(1), vm.addr(2), 250_000e6);
        kdao.transfer(vm.addr(2), 250_000e6);

        assertEq(kdao.totalSupply(), 20_000_000e6);

        vm.stopPrank();

        vm.startPrank(VOTING);
        vm.expectRevert();
        kdao.incrementDistroStage(DistroStage.Presale1);

        kdao.incrementDistroStage(DistroStage.Presale2);
        vm.stopPrank();
        mintAll(1e12, VOTING);

        assertEq(kdao.totalSupply(), kdao.supplyCap());

        vm.prank(VOTING);
        kdao.incrementDistroStage(DistroStage.ProtocolSaleStart);

        assertEq(kdao.supplyCap(), 60_000_000e6);
        assertEq(kdao.totalSupply(), kdao.supplyCap());
        assertEq(kdao.circulatingSupply(), 20_000_000e6 + 40_000_000e6 / 4);
    }

    function testTransferSimple() external {
        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250_000e6);
        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdao.balanceOf(vm.addr(2)), 500_000e6);
    }

    function testTransferFromSimple() external {
        vm.prank(vm.addr(1));
        kdao.approve(vm.addr(3), 250_000e6);

        vm.prank(vm.addr(3));
        kdao.transferFrom(vm.addr(1), vm.addr(2), 250_000e6);

        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdao.balanceOf(vm.addr(2)), 500_000e6);
    }

    function testTransferFrom() external {
        vm.startPrank(vm.addr(1));
        kdao.approve(vm.addr(11), 200_000e6);
        kdao.approve(address(kdao), 50_000e6);
        kdao.approve(address(0), 50_000e6);
        kdao.approve(address(kdaol), 50_000e6);
        vm.stopPrank();

        vm.startPrank(vm.addr(11));
        vm.expectRevert();
        kdao.transferFrom(vm.addr(1), vm.addr(2), 201_000e6);

        vm.expectRevert();
        kdao.transferFrom(vm.addr(1), address(kdao), 200_000e6);

        vm.expectRevert();
        kdao.transferFrom(vm.addr(1), address(kdaol), 200_000e6);

        kdao.transferFrom(vm.addr(1), vm.addr(2), 200_000e6);

        assertEq(kdao.balanceOf(vm.addr(1)), 50_000e6);
        assertEq(kdao.balanceOf(vm.addr(2)), 450_000e6);
        assertEq(kdaol.balanceOf(vm.addr(1)), 750_000e6);
        assertEq(kdaol.balanceOf(vm.addr(2)), 750_000e6);

        vm.stopPrank();

        vm.prank(vm.addr(3));
        kdao.approve(vm.addr(13), 150_000e6);

        vm.prank(vm.addr(4));
        kdao.approve(vm.addr(14), 251_000e6);

        vm.startPrank(vm.addr(14));
        vm.expectRevert();
        kdao.transferFrom(vm.addr(4), vm.addr(5), 251_000e6);

        vm.stopPrank();
    }

    function testProtocolAuthentication() external {
        vm.expectRevert();
        kdao.mint(amountAddrFrom(1, vm.addr(1)));

        vm.expectRevert();
        kdao.incrementDistroStage(DistroStage.Presale2);
    }

    function testSnapshotAuthentication() external {
        vm.expectRevert();
        kdao.snapshot0();

        vm.expectRevert();
        kdao.snapshot1();

        vm.expectRevert();
        kdao.snapshot2();

        vm.startPrank(VOTING);
        kdao.snapshot0();
        kdao.snapshot1();
        kdao.snapshot2();
        vm.stopPrank();
    }

    function testPreservesIndividualBalances() public {
        for (uint256 i = 1; i < 20; ++i) {
            vm.prank(vm.addr(i));
            kdao.transfer(vm.addr(i + 1), 250e9);
        }

        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdao.balanceOf(vm.addr(2)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(20)), 500e9);
    }

    function testPreventOverspending() public {
        vm.prank(vm.addr(1));
        vm.expectRevert();
        kdao.transfer(vm.addr(2), 251e9);

        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(3), 250e9);
        assertEq(kdao.balanceOf(vm.addr(1)), 0);

        vm.prank(vm.addr(4));
        kdao.transfer(vm.addr(5), 250e9);
        vm.prank(vm.addr(5));
        vm.expectRevert();
        kdao.transfer(vm.addr(6), 750e9);
    }

    function testAuthorizedPartiesCanSpendOnOwnersBehalf() public {
        vm.prank(vm.addr(1));
        kdao.approve(vm.addr(2), 1e12);

        assertEq(kdao.allowance(vm.addr(1), vm.addr(2)), 1e12);

        vm.prank(vm.addr(2));
        kdao.transferFrom(vm.addr(1), vm.addr(3), 250e9);

        assertEq(kdao.allowance(vm.addr(1), vm.addr(2)), 750e9);
        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdao.balanceOf(vm.addr(2)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(3)), 500e9);
    }

    function testUsersCanAdjustAllowance() public {
        vm.startPrank(vm.addr(1));
        kdao.increaseAllowance(vm.addr(2), 3);

        vm.expectRevert(stdError.arithmeticError);
        kdao.increaseAllowance(vm.addr(2), type(uint256).max);

        vm.expectRevert(stdError.arithmeticError);
        kdao.decreaseAllowance(vm.addr(2), 4);

        kdao.decreaseAllowance(vm.addr(2), 2);
        vm.stopPrank();

        vm.startPrank(vm.addr(2));
        vm.expectRevert(stdError.arithmeticError);
        kdao.transferFrom(vm.addr(1), vm.addr(2), 2);

        kdao.transferFrom(vm.addr(1), vm.addr(2), 1);

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9 - 1);
        assertEq(kdao.balanceOf(vm.addr(2)), 250e9 + 1);
    }

    function testShouldCompleteAllRounds() external {
        // 1M each, 250k unlocked
        assertEq(kdao.totalSupply(), 20e12);
        assertEq(kdaol.totalSupply(), 15e12);

        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250_000e6);

        // vm.addr(1):    0, 750k
        // vm.addr(2): 500k, 750k
        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdaol.balanceOf(vm.addr(1)), 750_000e6);
        assertEq(kdao.balanceOf(vm.addr(2)), 500_000e6);
        assertEq(kdaol.balanceOf(vm.addr(2)), 750_000e6);

        vm.prank(VOTING);
        kdao.incrementDistroStage(DistroStage.Presale2);
        mintAll(1e12, VOTING);
        // vm.addr(1)  250k, 1_500k
        // vm.addr(2)  750k, 1_500k
        assertEq(kdao.totalSupply(), 40e12);
        assertEq(kdaol.totalSupply(), 30e12);

        assertEq(kdao.balanceOf(vm.addr(1)), 250_000e6);
        assertEq(kdaol.balanceOf(vm.addr(1)), 1_500_000e6);
        assertEq(kdao.balanceOf(vm.addr(2)), 750_000e6);
        assertEq(kdaol.balanceOf(vm.addr(2)), 1_500_000e6);

        vm.prank(VOTING);
        kdao.incrementDistroStage(DistroStage.ProtocolSaleStart);

        assertEq(kdao.totalSupply(), 60e12);
        assertEq(kdaol.totalSupply(), 30e12);
        assertEq(kdao.balanceOf(PROTOCOL_FUND_ZKSYNC), 20e12);

        vm.prank(VOTING);
        kdao.incrementDistroStage(DistroStage.ProtocolSaleEnd);

        kdaol.unlock(vm.addr(1));
        kdaol.unlock(vm.addr(2));

        assertEq(kdao.balanceOf(vm.addr(1)), 1_000_000e6);
        assertEq(kdao.balanceOf(vm.addr(2)), 1_500_000e6);

        kdaol.unlockAllEven();

        assertEq(kdaol.balanceOf(vm.addr(1)), 750_000e6);
        assertEq(kdaol.balanceOf(vm.addr(2)), 750_000e6);

        vm.prank(VOTING);
        kdao.incrementDistroStage(DistroStage.ProtocolAMMStart);

        assertEq(kdao.totalSupply(), 80e12);
        assertEq(kdaol.totalSupply(), 15e12);

        vm.prank(VOTING);
        kdao.incrementDistroStage(DistroStage.Presale2Unlock);

        kdaol.unlockAllOdd();

        assertEq(kdao.totalSupply(), 80e12);
        assertEq(kdaol.totalSupply(), 0e12);

        vm.prank(VOTING);
        kdao.incrementDistroStage(DistroStage.FinalMint);
        mintAll(1e12, DEV_FUND);

        assertEq(kdaol.unlock(vm.addr(1)), false);

        assertEq(kdaol.balanceOf(vm.addr(1)), 750e9);

        vm.warp(1925097600);
        vm.prank(VOTING);
        kdao.incrementDistroStage(DistroStage.FinalUnlock);
        kdaol.unlock(vm.addr(1));

        assertEq(kdaol.balanceOf(vm.addr(1)), 0);

        kdaol.unlockAllEven();

        assertEq(kdaol.balanceOf(vm.addr(12)), 0);
        assertEq(kdaol.balanceOf(vm.addr(14)), 0);
        assertEq(kdaol.balanceOf(vm.addr(17)), 0);

        assertEq(kdao.balanceOf(address(kdaol)), kdaol.totalSupply());
    }
}
