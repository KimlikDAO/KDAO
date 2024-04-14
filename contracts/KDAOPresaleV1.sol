// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {setCodeSlot} from "interfaces/erc/ERC1967.sol";
import {DistroStage} from "interfaces/kimlikdao/IDistroStage.sol";
import {IUpgradable} from "interfaces/kimlikdao/IUpgradable.sol";
import {KDAO_PRESALE_DEPLOYER} from "interfaces/kimlikdao/addresses.sol";

contract KDAOPresaleV1 is IUpgradable {
    function versionHash() external pure override returns (bytes32) {
        // keccak256("KDAOPresaleV1")
        return 0x0a3cef05236c595906af3a533ce20fbf646ccbb0a32201150617b8af9343900c;
    }

    function updateCodeTo(IUpgradable code) external override {
        // keccak256("KDAOPresaleV2")
        require(code.versionHash() == 0xa891814ff991c9a1b3464ca3ecb80cceafbe489f2cf160f4f51baefa350d347f);
        require(msg.sender == KDAO_PRESALE_DEPLOYER);
        setCodeSlot(address(code));
    }
}
