// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {SSBalance} from "zksync/SSBalance.sol";

contract SSBalanceTest is Test {
    function testBalance01() external pure {
        SSBalance s;
        SSBalance t;
        s = s.add(10);

        assertEq(s.balance(), 10);
        assertEq(s.balance0(t), 0);
        assertEq(s.balance1(t), 0);
        assertEq(s.balance2(t), 0);

        t = t.inc0().inc1();

        s = s.keep(t).add(10);
        assertEq(s.balance(), 20);
        assertEq(s.balance0(t), 10);
        assertEq(s.balance1(t), 10);
        assertEq(s.balance2(t), 0);

        t = t.inc0();
        s = s.keep(t).add(11);
        assertEq(s.balance(), 31);
        assertEq(s.balance0(t), 20);
        assertEq(s.balance1(t), 10);
        assertEq(s.balance2(t), 0);
    }

    function testBalance12() external pure {
        SSBalance s;
        SSBalance t;
        s = s.add(10);

        assertEq(s.balance(), 10);
        assertEq(s.balance0(t), 0);
        assertEq(s.balance1(t), 0);
        assertEq(s.balance2(t), 0);

        t = t.inc1().inc2();

        s = s.keep(t).add(10);
        assertEq(s.balance(), 20);
        assertEq(s.balance0(t), 0);
        assertEq(s.balance1(t), 10);
        assertEq(s.balance2(t), 10);

        t = t.inc2();
        s = s.keep(t).add(11);
        assertEq(s.balance(), 31);
        assertEq(s.balance0(t), 0);
        assertEq(s.balance1(t), 10);
        assertEq(s.balance2(t), 20);
    }

    function testInc() external pure {
        SSBalance t0 = SSBalance.wrap(type(uint48).max | 1 << 96 | 2 << 144);
        SSBalance t1 = SSBalance.wrap(type(uint256).max);

        assertEq(t0.balance(), type(uint48).max);
        assertEq(t0.balance0(t0), 0);
        assertEq(t0.balance1(t0), 1);
        assertEq(t0.balance2(t0), 2);

        t1 = t1.inc0();

        assertEq(t0.balance(), type(uint48).max);
        assertEq(t0.balance0(t1), 0);
        assertEq(t0.balance1(t1), type(uint48).max);
        assertEq(t0.balance2(t1), type(uint48).max);

        t1 = t1.inc1();

        assertEq(t0.balance(), type(uint48).max);
        assertEq(t0.balance0(t1), 0);
        assertEq(t0.balance1(t1), 1);
        assertEq(t0.balance2(t1), type(uint48).max);

        t1 = t1.inc2();

        assertEq(t0.balance(), type(uint48).max);
        assertEq(t0.balance0(t1), 0);
        assertEq(t0.balance1(t1), 1);
        assertEq(t0.balance2(t1), 2);
    }
}
