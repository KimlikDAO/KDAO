//SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

enum DistroStage {
    Presale1,
    Presale2,
    DAOSaleStart,
    DAOSaleEnd,
    DAOAMMStart,
    Presale2Unlock,
    FinalMint,
    FinalUnlock
}

interface HasDistroStage {
    function distroStage() external view returns (DistroStage);
}
