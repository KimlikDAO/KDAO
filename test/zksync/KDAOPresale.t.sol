// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {KDAO_PRESALE, KDAO_PRESALE_DEPLOYER} from "interfaces/kimlikdao/addresses.sol";
import {computeCreateAddress as computeZkSyncCreateAddress} from "interfaces/zksync/IZkSync.sol";
import {KDAO_PRESALE_V1, KDAO_PRESALE_V2} from "zksync/KDAOPresale.sol";

contract addressesTest is Test {
    function testDeployerConsistency() public pure {
        assertEq(computeZkSyncCreateAddress(KDAO_PRESALE_DEPLOYER, 0), KDAO_PRESALE);
        assertEq(computeZkSyncCreateAddress(KDAO_PRESALE_DEPLOYER, 1), KDAO_PRESALE_V1);
        assertEq(computeZkSyncCreateAddress(KDAO_PRESALE_DEPLOYER, 2), KDAO_PRESALE_V2);
    }
}
