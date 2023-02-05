// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "contracts/TCKO.sol";
import "forge-std/Test.sol";
import "interfaces/testing/MockDAOKasasi.sol";
import {MockERC20Permit} from "interfaces/testing/MockTokens.sol";

contract TCKOGasTest is Test {
    TCKO private tcko;
    KilitliTCKO private tckok;
    IDAOKasasi private daoKasasi;
    MockERC20Permit private testToken;

    function setUp() public {
        vm.prank(TCKO_DEPLOYER);
        tcko = new TCKO(false);

        vm.prank(TCKOK_DEPLOYER);
        tckok = new KilitliTCKO();

        vm.prank(DAO_KASASI_DEPLOYER);
        daoKasasi = new MockDAOKasasi();

        mintAll(1e12);
        vm.deal(DAO_KASASI, 80e18);
    }

    function mintAll(uint256 amount) public {
        vm.startPrank(DEV_KASASI);
        for (uint256 i = 1; i <= 20; ++i)
            tcko.mintTo((amount << 160) | uint160(vm.addr(i)));
        vm.stopPrank();
    }

    function testRedeemCorrectness() external {
        vm.prank(vm.addr(1));
        tcko.transfer(DAO_KASASI, 250_000e6);

        assertEq(vm.addr(1).balance, 1e18);
    }

    function testRedeemGas() external {
        vm.prank(vm.addr(1));
        tcko.transfer(DAO_KASASI, 250_000e6);
    }

    function testRedeemAllCorrectness() external {
        for (uint256 i = 1; i <= 20; ++i) {
            vm.prank(vm.addr(i));
            tcko.transfer(DAO_KASASI, 250_000e6);

            assertEq(vm.addr(i).balance, 1e18);
        }
        assertEq(DAO_KASASI.balance, 60e18);
    }

    function testRedeemAllGas() external {
        for (uint256 i = 1; i <= 20; ++i) {
            vm.prank(vm.addr(i));
            tcko.transfer(DAO_KASASI, 250_000e6);
        }
    }
}
