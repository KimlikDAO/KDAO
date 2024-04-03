// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {KDAO, LockedKDAO} from "contracts/KDAO.sol";
import {Test} from "forge-std/Test.sol";
import {KDAOL_DEPLOYER, KDAO_DEPLOYER, PROTOCOL_FUND, PROTOCOL_FUND_DEPLOYER, VOTING} from "interfaces/Addresses.sol";
import {IProtocolFund} from "interfaces/IProtocolFund.sol";
import {MockProtocolFundV1} from "interfaces/testing/MockProtocolFundV1.sol";
import {MockERC20Permit} from "interfaces/testing/MockTokens.sol";

contract KDAOGasTest is Test {
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
        vm.deal(PROTOCOL_FUND, 80e18);
    }

    function mintAll(uint256 amount) public {
        vm.startPrank(VOTING);
        for (uint256 i = 1; i <= 20; ++i) {
            kdao.mintTo((amount << 160) | uint160(vm.addr(i)));
        }
        vm.stopPrank();
    }

    function testRedeemCorrectness() external {
        vm.prank(vm.addr(1));
        kdao.transfer(PROTOCOL_FUND, 250_000e6);

        assertEq(vm.addr(1).balance, 1e18);
    }

    function testRedeemGas() external {
        vm.prank(vm.addr(1));
        kdao.transfer(PROTOCOL_FUND, 250_000e6);
    }

    function testRedeemAllCorrectness() external {
        for (uint256 i = 1; i <= 20; ++i) {
            vm.prank(vm.addr(i));
            kdao.transfer(PROTOCOL_FUND, 250_000e6);

            assertEq(vm.addr(i).balance, 1e18);
        }
        assertEq(PROTOCOL_FUND.balance, 60e18);
    }

    function testRedeemAllGas() external {
        for (uint256 i = 1; i <= 20; ++i) {
            vm.prank(vm.addr(i));
            kdao.transfer(PROTOCOL_FUND, 250_000e6);
        }
    }
}
