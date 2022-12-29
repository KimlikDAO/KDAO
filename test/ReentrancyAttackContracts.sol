// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "contracts/TCKO.sol";
import "interfaces/Addresses.sol";
import "forge-std/Test.sol";

contract ReentrancyAttackAttempt1 {
    TCKO private tcko = TCKO(TCKO_ADDR);

    function attack() external {
        tcko.transfer(
            address(DAO_KASASI),
            (tcko.balanceOf(address(this)) * 3) / 4
        );
    }

    receive() external payable {
        uint256 amount = (tcko.balanceOf(address(this)) * 3) / 4;
        if (tcko.balanceOf(address(this)) >= amount) {
            tcko.transfer(address(DAO_KASASI), amount);
        }
    }
}

contract ReentrancyAttackAttempt2 {
    TCKO private tcko = TCKO(TCKO_ADDR);

    function attack() external {
        tcko.transfer(address(DAO_KASASI), (tcko.balanceOf(address(this)) / 2));
    }

    receive() external payable {
        if (tcko.balanceOf(address(this)) >= 125e9) {
            tcko.transfer(address(DAO_KASASI), 125e9);
        }
    }
}

contract InnocentContract is Test {
    TCKO private tcko = TCKO(TCKO_ADDR);

    function sendToDAOkasasi() external {
        tcko.transfer(address(DAO_KASASI), tcko.balanceOf(address(this)));
    }

    receive() external payable {
        vm.deal(address(this), 2e18);
    }
}
