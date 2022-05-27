// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./DistroStage.sol";

interface IDAOKasasi {
    function redeem(
        address owner,
        uint256 burnedTokens,
        uint256 totalTokens
    ) external;

    function distroStageUpdated(DistroStage) external;
}
