//SPDX-License-Identifier: MIT
//🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿

pragma solidity ^0.8.14;

import "./IDAOKasasi.sol";
import "hardhat/console.sol";

contract MockDAOKasasi is IDAOKasasi {
    function redeem(
        address payable redeemer,
        uint256 burnedTokens,
        uint256 totalTokens
    ) external view {
        console.log(
            "MockDAOKasasi.distroStageUpdated ",
            redeemer,
            burnedTokens,
            totalTokens
        );
    }

    function distroStageUpdated(DistroStage stage) external view {
        console.log("MockDAOKasasi.distroStageUpdated ", uint256(stage));
    }
}
