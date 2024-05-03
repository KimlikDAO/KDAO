// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {KDAO, MockKDAO} from "./MockKDAO.sol";
import {Test, console, stdError} from "forge-std/Test.sol";
import {USDT} from "interfaces/ethereum/addresses.sol";
import {deployMockTokens} from "interfaces/ethereum/mockTokens.sol";
import {IProtocolFund, ProtocolFund, RedeemInfoFrom} from "interfaces/kimlikdao/IProtocolFund.sol";
import {
    KDAO_ETHEREUM,
    KDAO_ETHEREUM_DEPLOYER,
    PROTOCOL_FUND,
    PROTOCOL_FUND_DEPLOYER
} from "interfaces/kimlikdao/addresses.sol";
import {MockERC20} from "interfaces/testing/MockERC20Permit.sol";
import {MockProtocolFundV1} from "interfaces/testing/MockProtocolFundV1.sol";
import {uint48x2From} from "interfaces/types/uint48x2.sol";

contract KDAORedeemTest is Test {
    KDAO private kdao;
    IProtocolFund private protocolFund;

    function setUp() external {
        vm.prank(KDAO_ETHEREUM_DEPLOYER);
        kdao = new MockKDAO();

        vm.prank(PROTOCOL_FUND_DEPLOYER);
        protocolFund = new MockProtocolFundV1();

        assertEq(address(protocolFund), PROTOCOL_FUND);

        deployMockTokens();
        vm.deal(PROTOCOL_FUND, 100 ether);

        vm.prank(PROTOCOL_FUND);
        MockERC20(address(USDT)).mint(100_000_000e6);
    }

    function testInitialBalances() external view {
        assertEq(PROTOCOL_FUND.balance, 100 ether);
        assertEq(USDT.balanceOf(PROTOCOL_FUND), 100_000_000e6);
    }

    function testRedeem() external {
        // KimlikDAO protocol has 100M USDT and 100 ethere.
        // address(20) owns 1% of the KimlikDAO protocol.
        // address(20) redeems their entire stake.
        assertEq(address(20).balance, 0);
        assertEq(USDT.balanceOf(address(20)), 0);
        assertEq(kdao.balanceOf(address(20)), 1_000_000e6);
        assertEq(kdao.totalSupply(), 1_002_000e6);
        assertEq(kdao.maxSupply(), 100_000_000e6);
        assertEq(kdao.circulatingSupply(), 1_002_000e6);

        vm.prank(address(20), address(20));
        kdao.redeem(1_000_000e6);

        assertEq(kdao.balanceOf(address(20)), 0);
        assertEq(address(20).balance, 1 ether);
        assertEq(USDT.balanceOf(address(20)), 1_000_000e6);
        assertEq(kdao.maxSupply(), 99_000_000e6);
        assertEq(kdao.totalSupply(), 2_000e6);
        assertEq(kdao.circulatingSupply(), 2_000e6);
    }

    function testRedeemViaTransfer() external {
        // KimlikDAO protocol has 100M USDT and 100 ethere.
        // address(20) owns 1% of the KimlikDAO protocol.
        // address(20) redeems their entire stake.
        assertEq(address(20).balance, 0);
        assertEq(USDT.balanceOf(address(20)), 0);
        assertEq(kdao.balanceOf(address(20)), 1_000_000e6);
        assertEq(kdao.totalSupply(), 1_002_000e6);
        assertEq(kdao.maxSupply(), 100_000_000e6);
        assertEq(kdao.circulatingSupply(), 1_002_000e6);

        vm.prank(address(20), address(20));
        kdao.transfer(PROTOCOL_FUND, 1_000_000e6);

        assertEq(kdao.balanceOf(address(20)), 0);
        assertEq(address(20).balance, 1 ether);
        assertEq(USDT.balanceOf(address(20)), 1_000_000e6);
        assertEq(kdao.maxSupply(), 99_000_000e6);
        assertEq(kdao.totalSupply(), 2_000e6);
        assertEq(kdao.circulatingSupply(), 2_000e6);
    }

    function testRedeemOnlyEOA() external {
        vm.prank(address(20), address(21));
        vm.expectRevert();
        kdao.redeem(1_000_000e6);
    }
}
