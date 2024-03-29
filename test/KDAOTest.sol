// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {KDAO} from "contracts/KDAO.sol";
import {LockedKDAO} from "contracts/LockedKDAO.sol";
import {Test, stdError} from "forge-std/Test.sol";
import {
    DEV_FUND,
    KDAOL,
    KDAOL_DEPLOYER,
    KDAO_ADDR,
    KDAO_DEPLOYER,
    PROTOCOL_FUND,
    PROTOCOL_FUND_DEPLOYER,
    VOTING
} from "interfaces/Addresses.sol";
import {DistroStage} from "interfaces/IDistroStage.sol";

import {IERC20Permit} from "interfaces/IERC20Permit.sol";
import {IProtocolFund} from "interfaces/IProtocolFund.sol";
import {MockProtocolFundV1} from "interfaces/testing/MockProtocolFundV1.sol";
import {MockERC20Permit} from "interfaces/testing/MockTokens.sol";

contract KDAOTest is Test {
    KDAO private kdao;
    LockedKDAO private kdaol;
    IProtocolFund private protocolFund;
    MockERC20Permit private testToken;

    function setUp() public {
        vm.prank(KDAO_DEPLOYER);
        kdao = new KDAO(false);

        vm.prank(KDAOL_DEPLOYER);
        kdaol = new LockedKDAO();

        vm.prank(PROTOCOL_FUND_DEPLOYER);
        protocolFund = new MockProtocolFundV1();

        mintAll(1e12);
    }

    function mintAll(uint256 amount) public {
        vm.startPrank(DEV_FUND);
        for (uint256 i = 1; i <= 20; ++i) {
            kdao.mintTo((amount << 160) | uint160(vm.addr(i)));
        }
        vm.stopPrank();
    }

    function testTypeHashes() external view {
        assertEq(
            kdao.PERMIT_TYPEHASH(),
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
        );
        assertEq(
            kdao.DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes("KDAO")),
                    keccak256(bytes("1")),
                    0x144,
                    KDAO_ADDR
                )
            )
        );
    }

    function testDAOAuthentication() public {
        vm.expectRevert();
        kdao.mintTo((uint256(1) << 160) | uint160(vm.addr(1)));

        vm.expectRevert();
        kdao.setPresale2Contract(vm.addr(1337));

        vm.expectRevert();
        kdao.incrementDistroStage(DistroStage.Presale2);
    }

    function testSnapshotAuthentication() public {
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

    function testShouldCompleteAllRounds() public {
        assertEq(kdao.totalSupply(), 20e12);
        assertEq(kdaol.totalSupply(), 15e12);

        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250_000e6);

        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdao.balanceOf(vm.addr(2)), 500_000e6);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.Presale2);
        mintAll(1e12);

        assertEq(kdao.totalSupply(), 40e12);
        assertEq(kdaol.totalSupply(), 30e12);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.DAOSaleStart);

        assertEq(kdao.totalSupply(), 60e12);
        assertEq(kdaol.totalSupply(), 30e12);
        assertEq(kdao.balanceOf(PROTOCOL_FUND), 20e12);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.DAOSaleEnd);

        kdaol.unlock(vm.addr(1));
        kdaol.unlock(vm.addr(2));

        assertEq(kdao.balanceOf(vm.addr(1)), 1e12);
        assertEq(kdao.balanceOf(vm.addr(2)), 1_500e9);

        kdaol.unlockAllEven();

        assertEq(kdaol.balanceOf(vm.addr(1)), 750e9);
        assertEq(kdaol.balanceOf(vm.addr(2)), 750e9);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.DAOAMMStart);

        assertEq(kdao.totalSupply(), 80e12);
        assertEq(kdaol.totalSupply(), 15e12);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.Presale2Unlock);

        kdaol.unlockAllOdd();

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.FinalMint);
        mintAll(1e12);

        assertEq(kdaol.unlock(vm.addr(1)), false);

        assertEq(kdaol.balanceOf(vm.addr(1)), 750e9);

        vm.warp(1925097600);
        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.FinalUnlock);
        kdaol.unlock(vm.addr(1));

        assertEq(kdaol.balanceOf(vm.addr(1)), 0);

        kdaol.unlockAllEven();

        assertEq(kdaol.balanceOf(vm.addr(12)), 0);
        assertEq(kdaol.balanceOf(vm.addr(14)), 0);
        assertEq(kdaol.balanceOf(vm.addr(17)), 0);

        assertEq(kdao.balanceOf(address(kdaol)), kdaol.totalSupply());
    }

    function testShouldNotUnlockBeforeMaturity() public {
        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllEven();

        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllOdd();

        kdaol.unlock(vm.addr(10));
        assertEq(kdao.balanceOf(vm.addr(10)), 250e9);
        assertEq(kdaol.balanceOf(vm.addr(10)), 750e9);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.Presale2);

        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllEven();
        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllOdd();

        mintAll(1e12);

        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllEven();
        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllOdd();

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.DAOSaleStart);

        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllEven();
        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllOdd();

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.DAOSaleEnd);

        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllOdd();
        kdaol.unlockAllEven();

        assertEq(kdao.balanceOf(vm.addr(2)), 1250e9);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.DAOAMMStart);
        kdaol.unlock(vm.addr(1));

        assertEq(kdao.balanceOf(vm.addr(1)), 1250e9);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.Presale2Unlock);
        kdaol.unlock(vm.addr(1));
        assertEq(kdao.balanceOf(vm.addr(1)), 2e12);

        kdaol.unlockAllOdd();

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.FinalMint);

        assertEq(kdao.totalSupply(), 80e12);
        assertEq(kdaol.totalSupply(), 0);

        mintAll(1e12);
        vm.expectRevert("KDAO-l: Not matured");
        kdaol.unlockAllEven();

        assertEq(kdao.totalSupply(), 100e12);
        assertEq(kdaol.totalSupply(), 15e12);

        vm.warp(1835470800000);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.FinalUnlock);
        kdaol.unlockAllEven();

        assertEq(kdaol.totalSupply(), 0);
    }

    function testPreserveTotalPlusBurnedEqualsMinted() public {
        assertEq(kdao.totalSupply(), 20e12);
        assertEq(kdaol.totalSupply(), 15e12);

        for (uint256 i = 9; i <= 20; ++i) {
            vm.prank(vm.addr(i));
            kdao.transfer(address(protocolFund), 250e9);
        }

        assertEq(kdao.totalSupply(), 17e12);
        assertEq(kdaol.totalSupply(), 15e12);
        assertEq(kdao.totalMinted(), 20e12);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.Presale2);
        mintAll(1e12);

        assertEq(kdao.totalSupply(), 37e12);

        for (uint256 i = 9; i <= 20; ++i) {
            vm.prank(vm.addr(i));
            kdao.transfer(address(protocolFund), 250e9);
        }

        assertEq(kdao.totalSupply(), 34e12);
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

    function testTransferGas() public {
        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250e9);
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

    function testSnapshot0Preserved() public {
        vm.prank(VOTING);
        kdao.snapshot0();

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 250e9);
        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250e9);

        assertEq(kdao.balanceOf(vm.addr(2)), 500e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(3));
        kdao.transfer(vm.addr(1), 100e9);

        assertEq(kdao.balanceOf(vm.addr(3)), 150e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(3)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(1)), 100e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 250e9);

        vm.prank(VOTING);
        kdao.snapshot0();
        assertEq(kdao.balanceOf(vm.addr(1)), 100e9);
        assertEq(kdao.balanceOf(vm.addr(2)), 500e9);
        assertEq(kdao.balanceOf(vm.addr(3)), 150e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 100e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 500e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(3)), 150e9);

        vm.startPrank(vm.addr(2));
        kdao.transfer(vm.addr(1), 50e9);
        kdao.transfer(vm.addr(3), 50e9);
        kdao.transfer(vm.addr(1), 50e9);
        kdao.transfer(vm.addr(3), 50e9);
        kdao.transfer(vm.addr(1), 50e9);
        vm.stopPrank();
        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(2)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(3)), 250e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 100e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 500e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(3)), 150e9);

        vm.prank(VOTING);
        kdao.snapshot0();
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 250e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(3)), 250e9);
    }

    function testSnapshot0PreservedOnSelfTransfer() public {
        vm.prank(VOTING);
        kdao.snapshot0();

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(1), 250e9);

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 250e9);

        vm.prank(VOTING);
        kdao.snapshot0();

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(1), 100e9);

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 250e9);
    }

    function testSnapshot0Fuzz(uint8 from, uint8 to, uint256 amount) public {
        vm.assume(from % 20 != to % 20);
        amount %= 250e9;

        vm.prank(VOTING);
        kdao.snapshot0();

        vm.prank(vm.addr((from % 20) + 1));
        kdao.transfer(vm.addr((to % 20) + 1), amount);

        assertEq(kdao.balanceOf(vm.addr((from % 20) + 1)), 250e9 - amount);
        assertEq(kdao.balanceOf(vm.addr((to % 20) + 1)), 250e9 + amount);
        assertEq(kdao.snapshot0BalanceOf(vm.addr((from % 20) + 1)), 250e9);
        assertEq(kdao.snapshot0BalanceOf(vm.addr((to % 20) + 1)), 250e9);
    }

    function testSnapshot1Preserved() public {
        vm.prank(VOTING);
        kdao.snapshot1();

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 250e9);
        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250e9);

        assertEq(kdao.balanceOf(vm.addr(2)), 500e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(2)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(3));
        kdao.transfer(vm.addr(1), 100e9);

        assertEq(kdao.balanceOf(vm.addr(3)), 150e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(3)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(1)), 100e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 250e9);

        vm.prank(VOTING);
        kdao.snapshot1();
        assertEq(kdao.balanceOf(vm.addr(1)), 100e9);
        assertEq(kdao.balanceOf(vm.addr(2)), 500e9);
        assertEq(kdao.balanceOf(vm.addr(3)), 150e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 100e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(2)), 500e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(3)), 150e9);

        vm.startPrank(vm.addr(2));
        kdao.transfer(vm.addr(1), 50e9);
        kdao.transfer(vm.addr(3), 50e9);
        kdao.transfer(vm.addr(1), 50e9);
        kdao.transfer(vm.addr(3), 50e9);
        kdao.transfer(vm.addr(1), 50e9);
        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(2)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(3)), 250e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 100e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(2)), 500e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(3)), 150e9);
        vm.stopPrank();

        vm.prank(VOTING);
        kdao.snapshot1();
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(2)), 250e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(3)), 250e9);
    }

    function testSnapshot1PreservedOnSelfTransfer() public {
        vm.prank(VOTING);
        kdao.snapshot1();

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(1), 250e9);

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 250e9);

        vm.prank(VOTING);
        kdao.snapshot1();

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(1), 100e9);

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 250e9);
    }

    function testSnapshot1Fuzz(uint8 from, uint8 to, uint256 amount) public {
        vm.assume(from % 20 != to % 20);

        amount %= 250e9;
        vm.prank(VOTING);
        kdao.snapshot1();

        vm.prank(vm.addr((from % 20) + 1));
        kdao.transfer(vm.addr((to % 20) + 1), amount);

        assertEq(kdao.balanceOf(vm.addr((from % 20) + 1)), 250e9 - amount);
        assertEq(kdao.balanceOf(vm.addr((to % 20) + 1)), 250e9 + amount);
        assertEq(kdao.snapshot1BalanceOf(vm.addr((from % 20) + 1)), 250e9);
        assertEq(kdao.snapshot1BalanceOf(vm.addr((to % 20) + 1)), 250e9);
    }

    function testSnapshot2Preserved() public {
        vm.prank(VOTING);
        kdao.snapshot2();

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 250e9);
        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250e9);

        assertEq(kdao.balanceOf(vm.addr(2)), 500e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(2)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(3));
        kdao.transfer(vm.addr(1), 100e9);

        assertEq(kdao.balanceOf(vm.addr(3)), 150e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(3)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(1)), 100e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 250e9);

        vm.prank(VOTING);
        kdao.snapshot2();
        assertEq(kdao.balanceOf(vm.addr(1)), 100e9);
        assertEq(kdao.balanceOf(vm.addr(2)), 500e9);
        assertEq(kdao.balanceOf(vm.addr(3)), 150e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 100e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(2)), 500e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(3)), 150e9);

        vm.startPrank(vm.addr(2));
        kdao.transfer(vm.addr(1), 50e9);
        kdao.transfer(vm.addr(3), 50e9);
        kdao.transfer(vm.addr(1), 50e9);
        kdao.transfer(vm.addr(3), 50e9);
        kdao.transfer(vm.addr(1), 50e9);
        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(2)), 250e9);
        assertEq(kdao.balanceOf(vm.addr(3)), 250e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 100e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(2)), 500e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(3)), 150e9);
        vm.stopPrank();

        vm.prank(VOTING);
        kdao.snapshot2();
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(2)), 250e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(3)), 250e9);
    }

    function testSnapshot2PreservedOnSelfTransfer() public {
        vm.prank(VOTING);
        kdao.snapshot2();

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(1), 250e9);

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 250e9);

        vm.prank(VOTING);
        kdao.snapshot2();

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 250e9);

        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(1), 100e9);

        assertEq(kdao.balanceOf(vm.addr(1)), 250e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 250e9);
    }

    function testSnapshot2Fuzz(uint8 from, uint8 to, uint256 amount) public {
        vm.assume(from % 20 != to % 20);

        amount %= 250e9;
        vm.prank(VOTING);
        kdao.snapshot2();

        vm.prank(vm.addr((from % 20) + 1));
        kdao.transfer(vm.addr((to % 20) + 1), amount);

        assertEq(kdao.balanceOf(vm.addr((from % 20) + 1)), 250e9 - amount);
        assertEq(kdao.balanceOf(vm.addr((to % 20) + 1)), 250e9 + amount);
        assertEq(kdao.snapshot2BalanceOf(vm.addr((from % 20) + 1)), 250e9);
        assertEq(kdao.snapshot2BalanceOf(vm.addr((to % 20) + 1)), 250e9);
    }

    function authorizePayment(uint256 ownerPrivateKey, address spender, uint256 amount, uint256 deadline, uint256 nonce)
        internal
        view
        returns (uint8, bytes32, bytes32)
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                kdao.DOMAIN_SEPARATOR(),
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
        kdao.transferFrom(vm.addr(1), vm.addr(2), 250e9);

        uint256 time = block.timestamp + 1000;
        (uint8 v, bytes32 r, bytes32 s) = authorizePayment(1, vm.addr(2), 250e9, time, 0);
        kdao.permit(vm.addr(1), vm.addr(2), 250e9, time, v, r, s);
        vm.prank(vm.addr(2));
        kdao.transferFrom(vm.addr(1), vm.addr(2), 250e9);
        assertEq(kdao.balanceOf(vm.addr(2)), 500e9);
    }

    function testTokenMethods() external view {
        assertEq(kdao.decimals(), kdaol.decimals());
        // Increase coverage so we can always aim at 100%.
        assertEq(kdao.name(), "KimlikDAO");
        assertEq(kdaol.name(), "Locked KDAO");
        assertEq(kdao.maxSupply(), 100_000_000e6);

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
        kdao.transfer(address(0), 250_000e6);

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

        vm.startPrank(vm.addr(2));

        kdao.transfer(PROTOCOL_FUND, 500_000e6);

        assertEq(kdao.totalSupply() + 500_000e6, kdao.supplyCap());

        vm.stopPrank();

        vm.startPrank(DEV_FUND);
        vm.expectRevert();
        kdao.incrementDistroStage(DistroStage.Presale1);

        kdao.incrementDistroStage(DistroStage.Presale2);
        vm.stopPrank();
        mintAll(1e12);

        assertEq(kdao.totalSupply() + 500_000e6, kdao.supplyCap());

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.DAOSaleStart);

        assertEq(kdao.supplyCap(), 60_000_000e6);
        assertEq(kdao.totalSupply() + 500_000e6, kdao.supplyCap());
        assertEq(kdao.circulatingSupply(), 20_000_000e6 + 40_000_000e6 / 4 - 500_000e6);
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
        kdao.transferFrom(vm.addr(1), address(0), 200_000e6);

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

        vm.startPrank(vm.addr(13));
        kdao.transferFrom(vm.addr(3), PROTOCOL_FUND, 150_000e6);

        assertEq(kdao.balanceOf(vm.addr(3)), 100_000e6);
        assertEq(kdao.totalSupply(), 20_000_000e6 - 150_000e6);

        vm.stopPrank();

        vm.prank(vm.addr(4));
        kdao.approve(vm.addr(14), 251_000e6);

        vm.startPrank(vm.addr(14));
        vm.expectRevert();
        kdao.transferFrom(vm.addr(4), vm.addr(5), 251_000e6);

        vm.stopPrank();
    }

    function testPresale2Contract() external {
        vm.expectRevert();
        kdao.setPresale2Contract(vm.addr(0x94E008A7E2));

        vm.startPrank(DEV_FUND);
        kdao.setPresale2Contract(vm.addr(0x94E008A7E2));
        kdao.incrementDistroStage(DistroStage.Presale2);
        vm.stopPrank();

        vm.startPrank(vm.addr(0x94E008A7E2));
        vm.expectRevert();
        kdao.mintTo(uint160(address(kdaol)) | (1 << 160));
        vm.expectRevert();
        kdao.mintTo(uint160(address(PROTOCOL_FUND)) | (1 << 160));

        kdao.mintTo(uint160(vm.addr(1)) | (20_000_000e6 << 160));
        vm.expectRevert();
        kdao.mintTo(uint160(vm.addr(1)) | (1 << 160));
        vm.stopPrank();

        assertEq(kdao.balanceOf(vm.addr(1)), 5_250_000e6);
    }

    function testLockedKDAORescueToken() external {
        vm.startPrank(vm.addr(20));
        testToken = new MockERC20Permit("TestToken", "TT", 6);
        testToken.transfer(address(KDAOL), 4e7);
        vm.stopPrank();

        assertEq(testToken.balanceOf(address(kdaol)), 4e7);
        assertEq(testToken.balanceOf(vm.addr(20)), 6e7);

        vm.startPrank(vm.addr(1));
        vm.expectRevert();
        kdaol.rescueToken(testToken);
        vm.stopPrank();

        vm.startPrank(VOTING);
        vm.expectRevert();
        kdaol.rescueToken(IERC20Permit(KDAO_ADDR));
        vm.stopPrank();

        vm.startPrank(VOTING);
        kdaol.rescueToken(testToken);
        vm.stopPrank();

        assertEq(testToken.balanceOf(PROTOCOL_FUND), 4e7);
        assertEq(testToken.balanceOf(address(kdaol)), 0);
    }

    function testLockedKDAOSelfDestruct() external {
        vm.startPrank(vm.addr(1));
        vm.expectRevert();
        // kdaol.selfDestruct();
        vm.stopPrank();

        vm.startPrank(DEV_FUND);
        vm.expectRevert();
        // kdaol.selfDestruct();
        vm.stopPrank();

        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250_000e6);

        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdao.balanceOf(vm.addr(2)), 500_000e6);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.Presale2);
        mintAll(1e12);

        assertEq(kdao.totalSupply(), 40e12);
        assertEq(kdaol.totalSupply(), 30e12);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.DAOSaleStart);

        assertEq(kdao.totalSupply(), 60e12);
        assertEq(kdaol.totalSupply(), 30e12);
        assertEq(kdao.balanceOf(PROTOCOL_FUND), 20e12);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.DAOSaleEnd);

        kdaol.unlock(vm.addr(1));
        kdaol.unlock(vm.addr(2));

        assertEq(kdao.balanceOf(vm.addr(1)), 1e12);
        assertEq(kdao.balanceOf(vm.addr(2)), 1_500e9);

        kdaol.unlockAllEven();

        assertEq(kdaol.balanceOf(vm.addr(1)), 750e9);
        assertEq(kdaol.balanceOf(vm.addr(2)), 750e9);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.DAOAMMStart);

        assertEq(kdao.totalSupply(), 80e12);
        assertEq(kdaol.totalSupply(), 15e12);

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.Presale2Unlock);

        kdaol.unlockAllOdd();

        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.FinalMint);
        mintAll(1e12);

        assertEq(kdaol.unlock(vm.addr(1)), false);

        assertEq(kdaol.balanceOf(vm.addr(1)), 750e9);

        vm.warp(1925097600);
        vm.prank(DEV_FUND);
        kdao.incrementDistroStage(DistroStage.FinalUnlock);

        kdaol.unlockAllEven();

        vm.prank(DEV_FUND);
    }
}
