// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IUpgradable} from "interfaces/kimlikdao/IUpgradable.sol";
import {KDAO_PRESALE_DEPLOYER} from "interfaces/kimlikdao/addresses.sol";
import {KDAOPresaleV1} from "zksync/KDAOPresaleV1.sol";

contract MockKDAOPresaleV2 is IUpgradable {
    function versionHash() external pure override returns (bytes32) {
        return keccak256("KDAOPresaleV2");
    }

    function updateCodeTo(IUpgradable code) external override {}
}

contract KDAOPresaleV1Test is Test {
    function testVersionHash() public {
        KDAOPresaleV1 ps1 = new KDAOPresaleV1();

        assertEq(ps1.versionHash(), keccak256("KDAOPresaleV1"));

        MockKDAOPresaleV2 ps2 = new MockKDAOPresaleV2();

        vm.prank(KDAO_PRESALE_DEPLOYER);
        ps1.updateCodeTo(ps2);
    }
}
