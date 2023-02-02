// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "interfaces/Addresses.sol";
import {IDAOKasasi} from "interfaces/IDAOKasasi.sol";
import {MockDAOKasasi} from "interfaces/testing/MockDAOKasasi.sol";
import {TCKO, KilitliTCKO} from "contracts/TCKO.sol";

contract TCKOMintTest is Test {
    TCKO private tcko;
    KilitliTCKO private tckok;
    IDAOKasasi private daoKasasi;

    function setUp() public {
        vm.prank(TCKOK_DEPLOYER);
        tckok = new KilitliTCKO();

        vm.prank(TCKO_DEPLOYER);
        tcko = new TCKO(true);

        vm.prank(DAO_KASASI_DEPLOYER);
        daoKasasi = new MockDAOKasasi();
    }

    function testBalances() external {
        // Check signer node balances.
        assertEq(
            tcko.balanceOf(0x0A8B89D47d73a716EBF0F98696A7201480c2Ca43),
            25000e6
        );
        assertEq(
            tckok.balanceOf(0x0A8B89D47d73a716EBF0F98696A7201480c2Ca43),
            75000e6
        );
        assertEq(
            tcko.balanceOf(0xCB75191c60AE41CAe73BA150c08d3B4645493A60),
            25000e6
        );
        assertEq(
            tckok.balanceOf(0xCB75191c60AE41CAe73BA150c08d3B4645493A60),
            75000e6
        );
        assertEq(
            tcko.balanceOf(0xBe3c9E51270D9313A530758b6ECa68400eBF31AF),
            25000e6
        );
        assertEq(
            tckok.balanceOf(0xBe3c9E51270D9313A530758b6ECa68400eBF31AF),
            75000e6
        );
        assertEq(
            tcko.balanceOf(0x57074c1956d7eF1cDa0A8ca26E22C861e30cd733),
            1_000_000e6
        );
        assertEq(
            tckok.balanceOf(0x57074c1956d7eF1cDa0A8ca26E22C861e30cd733),
            3_000_000e6
        );
        assertEq(tcko.totalSupply(), 19_216_000e6 + 500_000e6);
    }
}
