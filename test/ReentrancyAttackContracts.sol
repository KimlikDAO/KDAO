// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {DAO_KASASI, TCKO_ADDR} from "interfaces/Addresses.sol";
import {IERC20} from "interfaces/IERC20.sol";

contract ReentrancyAttackAttempt1 {
    IERC20 private tcko = IERC20(TCKO_ADDR);

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
    IERC20 private tcko = IERC20(TCKO_ADDR);

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
    IERC20 private tcko = IERC20(TCKO_ADDR);

    function sendToDAOkasasi() external {
        tcko.transfer(address(DAO_KASASI), tcko.balanceOf(address(this)));
    }

    receive() external payable {
        vm.deal(address(this), 2e18);
    }
}
