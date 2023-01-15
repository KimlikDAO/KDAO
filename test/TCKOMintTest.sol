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
            tcko.balanceOf(0xa41F9Ad9fD440C2e297dD89F36240716d832BbDb),
            25000e6
        );
        assertEq(
            tckok.balanceOf(0xa41F9Ad9fD440C2e297dD89F36240716d832BbDb),
            75000e6
        );
        assertEq(
            tcko.balanceOf(0x9c6502b0837353097562E5Ffc815Ac7D44A729eA),
            25000e6
        );
        assertEq(
            tckok.balanceOf(0x9c6502b0837353097562E5Ffc815Ac7D44A729eA),
            75000e6
        );
        assertEq(
            tcko.balanceOf(0x7D211ECf4dd431D68D800497C8902474aF0412B7),
            25000e6
        );
        assertEq(
            tckok.balanceOf(0x7D211ECf4dd431D68D800497C8902474aF0412B7),
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
