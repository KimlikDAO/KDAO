// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {KDAO} from "ethereum/KDAO.sol";
import {uint48x2From} from "interfaces/types/uint48x2.sol";

// Premined KDAO contract for testing purposes.
// Addresses 0 through 19 are given 100 KDAOs.
contract MockKDAO is KDAO {
    constructor() {
        for (uint160 i = 0; i < 20; ++i) {
            balanceOf[address(i)] = 100e6;
        }

        balanceOf[address(20)] = 1_000_000e6;

        totals = uint48x2From(100_000_000e6, 20 * 100e6 + 1_000_000e6);
    }
}
