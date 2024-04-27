// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {CODE_SLOT, setCodeSlot} from "interfaces/erc/ERC1967.sol";

address constant KDAO_PRESALE_V1 = 0x02D764e5D0d586dEFDa85C6F0D74F7805E0F6B5b;
address constant KDAO_PRESALE_V2 = 0xd6706f5226d64EF72670501A9375E18D78dFa4ce;

contract KDAOPresale {
    constructor() {
        setCodeSlot(KDAO_PRESALE_V1);
    }

    receive() external payable {}

    fallback() external payable {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), sload(CODE_SLOT), 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
