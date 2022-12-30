//SPDX-License-Identifier: MIT

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
        vm.prank(TCKO_DEPLOYER);
        tcko = new TCKO();

        vm.prank(TCKOK_DEPLOYER);
        tckok = new KilitliTCKO();

        vm.prank(DAO_KASASI_DEPLOYER);
        daoKasasi = new MockDAOKasasi();
    }

    function testMintBulk() external {
        uint256[10] memory amountAccounts = [
            uint160(vm.addr(1)) | uint256(1e12 << 160),
            uint160(vm.addr(2)) | (1e12 << 160),
            uint160(vm.addr(3)) | (1e12 << 160),
            uint160(vm.addr(4)) | (1e12 << 160),
            uint160(vm.addr(5)) | (1e12 << 160),
            uint160(vm.addr(6)) | (1e12 << 160),
            uint160(vm.addr(7)) | (1e12 << 160),
            uint160(vm.addr(8)) | (1e12 << 160),
            uint160(vm.addr(9)) | (1e12 << 160),
            uint160(vm.addr(10)) | (1e12 << 160)
        ];
        vm.expectRevert();
        tcko.mintBulk(amountAccounts);

        vm.prank(DEV_KASASI);
        tcko.mintBulk(amountAccounts);

        assertEq(tcko.totalSupply(), 10_000_000e6);
    }
}
