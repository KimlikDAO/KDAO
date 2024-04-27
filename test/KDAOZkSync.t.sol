// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {KDAO} from "contracts/KDAOZkSync.sol";
import {Test} from "forge-std/Test.sol";
import {KDAO_ZKSYNC, KDAO_ZKSYNC_DEPLOYER} from "interfaces/kimlikdao/addresses.sol";
import {uint48x2From} from "interfaces/types/uint48x2.sol";

contract KDAOZkSyncTest is Test {
    KDAO private kdao;

    function setUp() public {
        vm.prank(KDAO_ZKSYNC_DEPLOYER);
        kdao = new KDAO();
    }

    function testDomainSeparator() external view {
        assertEq(
            kdao.DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes("KDAO")),
                    keccak256(bytes("1")),
                    0x144,
                    KDAO_ZKSYNC
                )
            )
        );
    }
}
