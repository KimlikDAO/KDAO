// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {KDAO} from "ethereum/KDAO.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {KDAO_ETHEREUM, KDAO_ETHEREUM_DEPLOYER} from "interfaces/kimlikdao/addresses.sol";
import {uint48x2From} from "interfaces/types/uint48x2.sol";

contract KDAOPremined is KDAO {
    constructor() {
        balanceOf[address(0x1337)] = 100e6;
        balanceOf[address(0x1338)] = 100e6;
        balanceOf[address(0x1339)] = 100e6;
        balanceOf[address(0x1310)] = 100e6;

        totals = uint48x2From(100_000_000e6, 4 * 100e6);
    }
}

contract KDAOTest is Test {
    KDAO private kdao;

    function setUp() public {
        vm.prank(KDAO_ETHEREUM_DEPLOYER);
        kdao = new KDAOPremined();
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
                    0x1,
                    KDAO_ETHEREUM
                )
            )
        );
    }

    function testTransfer() external {
        assertEq(kdao.balanceOf(address(0x1337)), 100e6);

        vm.prank(address(0x1337));
        kdao.transfer(address(0x1338), 100e6);
        assertEq(kdao.balanceOf(address(0x1337)), 0);
        assertEq(kdao.balanceOf(address(0x1338)), 200e6);

        vm.startPrank(address(0x1338));
        vm.expectRevert();
        kdao.transfer(address(0x1339), 200e6 + 1);

        assertEq(kdao.balanceOf(address(0x1338)), 200e6);

        kdao.transfer(address(0x1339), 200e6);
        vm.stopPrank();

        assertEq(kdao.balanceOf(address(0x1338)), 0);
        assertEq(kdao.balanceOf(address(0x1339)), 300e6);
    }
}
