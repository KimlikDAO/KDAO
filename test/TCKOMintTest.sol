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
            tcko.balanceOf(0x299A3490c8De309D855221468167aAD6C44c59E0),
            25000e6
        );
        assertEq(
            tckok.balanceOf(0x299A3490c8De309D855221468167aAD6C44c59E0),
            75000e6
        );
        assertEq(
            tcko.balanceOf(0x384bF113dcdF3e7084C1AE2Bb97918c3Bf15A6d2),
            25000e6
        );
        assertEq(
            tckok.balanceOf(0x384bF113dcdF3e7084C1AE2Bb97918c3Bf15A6d2),
            75000e6
        );
        assertEq(
            tcko.balanceOf(0x77c60E68158De0bC70260DFd1201be9445EfFc07),
            25000e6
        );
        assertEq(
            tckok.balanceOf(0x77c60E68158De0bC70260DFd1201be9445EfFc07),
            75000e6
        );
        assertEq(
            tcko.balanceOf(0x4F1DBED3c377646c89B4F8864E0b41806f2B79fd),
            25000e6
        );
        assertEq(
            tckok.balanceOf(0x4F1DBED3c377646c89B4F8864E0b41806f2B79fd),
            75000e6
        );
        assertEq(
            tcko.balanceOf(0x86f6B34A26705E6a22B8e2EC5ED0cC5aB3f6F828),
            25000e6
        );
        assertEq(
            tckok.balanceOf(0x86f6B34A26705E6a22B8e2EC5ED0cC5aB3f6F828),
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
