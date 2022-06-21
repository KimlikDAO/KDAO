//SPDX-License-Identifier: MIT
//🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿

pragma solidity ^0.8.15;

import "./KimlikDAO.sol";

contract DAOKasasiProxy {
    constructor() {
        assembly {
            sstore(ERC1967_CODE_SLOT, DAO_KASASI_VO)
        }
    }

    fallback() external payable {
        assembly {
            let codeAddress := sload(ERC1967_CODE_SLOT)
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), codeAddress, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
