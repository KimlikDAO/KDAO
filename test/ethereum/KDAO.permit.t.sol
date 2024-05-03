// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {KDAO} from "ethereum/KDAO.sol";
import {Test, stdError} from "forge-std/Test.sol";
import {KDAO_ETHEREUM, KDAO_ETHEREUM_DEPLOYER} from "interfaces/kimlikdao/addresses.sol";

contract KDAOPermitTest is Test {
    KDAO private kdao;

    function setUp() external {
        vm.prank(KDAO_ETHEREUM_DEPLOYER);
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
                    0x1,
                    KDAO_ETHEREUM
                )
            )
        );
    }

    function authorizePayment(
        uint256 ownerPrivateKey,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint256 nonce
    ) internal view returns (uint8, bytes32, bytes32) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                kdao.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9,
                        vm.addr(ownerPrivateKey),
                        spender,
                        amount,
                        nonce,
                        deadline
                    )
                )
            )
        );
        return vm.sign(ownerPrivateKey, digest);
    }

    function testPermit() external {
        {
            uint256 deadline = block.timestamp + 1000;
            (uint8 v, bytes32 r, bytes32 s) =
                authorizePayment(1337, address(888), 100_000e6, deadline, 0);
            kdao.permit(vm.addr(1337), address(888), 100_000e6, deadline, v, r, s);

            assertEq(kdao.allowance(vm.addr(1337), address(888)), 100_000e6);
        }

        {
            uint256 deadline = block.timestamp + 2000;
            (uint8 v, bytes32 r, bytes32 s) =
                authorizePayment(1337, address(888), 200_000e6, deadline, 1);
            kdao.permit(vm.addr(1337), address(888), 200_000e6, deadline, v, r, s);

            assertEq(kdao.allowance(vm.addr(1337), address(888)), 200_000e6);
        }

        {
            uint256 deadline = block.timestamp + 3000;
            (uint8 v, bytes32 r, bytes32 s) =
                authorizePayment(1337, address(999), 300_000e6, deadline, 2);
            kdao.permit(vm.addr(1337), address(999), 300_000e6, deadline, v, r, s);

            assertEq(kdao.allowance(vm.addr(1337), address(999)), 300_000e6);
        }
    }

    function testPermitMalformedSignature() external {
        uint256 deadline = block.timestamp + 1000;
        (uint8 v, bytes32 r, bytes32 s) =
            authorizePayment(1337, address(888), 100_000e6, deadline, 0);

        vm.expectRevert();
        kdao.permit(vm.addr(1337), address(888), 100_000e6, deadline, 2, r, s);

        vm.expectRevert();
        kdao.permit(vm.addr(1338), address(888), 100_000e6, deadline, 2, r, s);

        kdao.permit(vm.addr(1337), address(888), 100_000e6, deadline, v, r, s);
    }

    function testExpiredPermitSignature() external {
        uint256 deadline = block.timestamp + 1000;
        (uint8 v, bytes32 r, bytes32 s) =
            authorizePayment(1337, address(888), 100_000e6, deadline, 0);
        vm.warp(deadline + 1);
        vm.expectRevert();
        kdao.permit(vm.addr(1337), address(888), 100_000e6, deadline, v, r, s);
    }
}
