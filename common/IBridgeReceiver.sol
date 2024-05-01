// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {amountAddr} from "interfaces/types/amountAddr.sol";

interface IBridgeReceiver {
    function acceptBridgeFromEthereum(amountAddr aaddr) external;
}
