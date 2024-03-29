// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {KDAO, LockedKDAO} from "contracts/KDAO.sol";
import {Test} from "forge-std/Test.sol";
import {KDAOL_DEPLOYER, KDAO_DEPLOYER, PROTOCOL_FUND_DEPLOYER} from "interfaces/Addresses.sol";
import {IProtocolFund} from "interfaces/IProtocolFund.sol";
import {MockProtocolFundV1} from "interfaces/testing/MockProtocolFundV1.sol";

contract KDAOMintTest is Test {
    KDAO private kdao;
    LockedKDAO private kdaol;
    IProtocolFund private protocolFund;

    function setUp() public {
        vm.prank(KDAOL_DEPLOYER);
        kdaol = new LockedKDAO();

        vm.prank(KDAO_DEPLOYER);
        kdao = new KDAO(true);

        vm.prank(PROTOCOL_FUND_DEPLOYER);
        protocolFund = new MockProtocolFundV1();
    }

    function testBalances() external view {
        // Check signer node balances.
        assertEq(kdao.balanceOf(0x299A3490c8De309D855221468167aAD6C44c59E0), 25000e6);
        assertEq(kdaol.balanceOf(0x299A3490c8De309D855221468167aAD6C44c59E0), 75000e6);
        assertEq(kdao.balanceOf(0x384bF113dcdF3e7084C1AE2Bb97918c3Bf15A6d2), 25000e6);
        assertEq(kdaol.balanceOf(0x384bF113dcdF3e7084C1AE2Bb97918c3Bf15A6d2), 75000e6);
        assertEq(kdao.balanceOf(0x77c60E68158De0bC70260DFd1201be9445EfFc07), 25000e6);
        assertEq(kdaol.balanceOf(0x77c60E68158De0bC70260DFd1201be9445EfFc07), 75000e6);
        assertEq(kdao.balanceOf(0x4F1DBED3c377646c89B4F8864E0b41806f2B79fd), 25000e6);
        assertEq(kdaol.balanceOf(0x4F1DBED3c377646c89B4F8864E0b41806f2B79fd), 75000e6);
        assertEq(kdao.balanceOf(0x86f6B34A26705E6a22B8e2EC5ED0cC5aB3f6F828), 25000e6);
        assertEq(kdaol.balanceOf(0x86f6B34A26705E6a22B8e2EC5ED0cC5aB3f6F828), 75000e6);
        assertEq(kdao.balanceOf(0x57074c1956d7eF1cDa0A8ca26E22C861e30cd733), 1_000_000e6);
        assertEq(kdaol.balanceOf(0x57074c1956d7eF1cDa0A8ca26E22C861e30cd733), 3_000_000e6);
        assertEq(kdao.totalSupply(), 18_416_000e6 + 600_000e6);
    }
}
