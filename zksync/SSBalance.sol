// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

uint256 constant TICK0 = type(uint256).max << 232;
uint256 constant TICK1 = ((uint256(1) << 20) - 1) << 212;
uint256 constant TICK2 = ((uint256(1) << 20) - 1) << 192;
uint256 constant BALANCE_MASK = type(uint48).max;

// `SSBalance` layout:
// |-- tick0 --|-- tick1 --|-- tick2 --|-- balance2 --|-- balance1 --|-- balance0 --|-- balance --|
// |--   24  --|--   20  --|--   20  --|--    48    --|--    48    --|--    48    --|--    48   --|
type SSBalance is uint256;

function balance(SSBalance self) pure returns (uint256) {
    return SSBalance.unwrap(self) & BALANCE_MASK;
}

function sub(SSBalance self, uint256 other) pure returns (SSBalance) {
    unchecked {
        return SSBalance.wrap(SSBalance.unwrap(self) - other);
    }
}

function add(SSBalance self, uint256 other) pure returns (SSBalance) {
    unchecked {
        return SSBalance.wrap(SSBalance.unwrap(self) + other);
    }
}

function keep(SSBalance self, SSBalance tick) pure returns (SSBalance) {
    uint256 s = SSBalance.unwrap(self);
    uint256 t = SSBalance.unwrap(tick);
    unchecked {
        // tick.tick0 doesn't match balance.tick0; we need to preserve the
        // current balance.
        if ((s ^ t) & TICK0 != 0) {
            s = (s & ~((BALANCE_MASK << 48) | TICK0)) | (s & BALANCE_MASK) << 48 | (t & TICK0);
        }
        // tick.tick1 doesn't match balance.tick1; we need to preserve the
        // current balance.
        if ((s ^ t) & TICK1 != 0) {
            s = (s & ~((BALANCE_MASK << 96) | TICK1)) | (s & BALANCE_MASK) << 96 | (t & TICK1);
        }
        // tick.tick2 doesn't match balance.tick2; we need to preserve the
        // current balance.
        if ((s ^ t) & TICK2 != 0) {
            s = (s & ~((BALANCE_MASK << 144) | TICK2)) | (s & BALANCE_MASK) << 144 | (t & TICK2);
        }
        return SSBalance.wrap(s);
    }
}

function balance0(SSBalance self, SSBalance t) pure returns (uint256) {
    uint256 s = SSBalance.unwrap(self);
    return BALANCE_MASK & (((s ^ SSBalance.unwrap(t)) & TICK0 == 0) ? (s >> 48) : s);
}

function balance1(SSBalance self, SSBalance t) pure returns (uint256) {
    uint256 s = SSBalance.unwrap(self);
    return BALANCE_MASK & (((s ^ SSBalance.unwrap(t)) & TICK1 == 0) ? (s >> 96) : s);
}

function balance2(SSBalance self, SSBalance t) pure returns (uint256) {
    uint256 s = SSBalance.unwrap(self);
    return BALANCE_MASK & (((s ^ SSBalance.unwrap(t)) & TICK2 == 0) ? (s >> 144) : s);
}

function reset0(SSBalance self, SSBalance t) pure returns (SSBalance) {
    return SSBalance.wrap(
        (SSBalance.unwrap(self) & ~((BALANCE_MASK << 48) | TICK0)) | (SSBalance.unwrap(t) & TICK0)
    );
}

function reset1(SSBalance self, SSBalance t) pure returns (SSBalance) {
    return SSBalance.wrap(
        (SSBalance.unwrap(self) & ~((BALANCE_MASK << 96) | TICK1)) | (SSBalance.unwrap(t) & TICK1)
    );
}

function reset2(SSBalance self, SSBalance t) pure returns (SSBalance) {
    return SSBalance.wrap(
        (SSBalance.unwrap(self) & ~((BALANCE_MASK << 144) | TICK2)) | (SSBalance.unwrap(t) & TICK2)
    );
}

function inc0(SSBalance self) pure returns (SSBalance) {
    unchecked {
        return SSBalance.wrap(SSBalance.unwrap(self) + (uint256(1) << 232));
    }
}

function inc1(SSBalance self) pure returns (SSBalance) {
    uint256 t = SSBalance.unwrap(self);
    unchecked {
        return SSBalance.wrap(t & TICK1 == TICK1 ? t & ~TICK1 : t + (uint256(1) << 212));
    }
}

function inc2(SSBalance self) pure returns (SSBalance) {
    uint256 t = SSBalance.unwrap(self);
    unchecked {
        return SSBalance.wrap(t & TICK2 == TICK2 ? t & ~TICK2 : t + (uint256(1) << 192));
    }
}

using {
    balance,
    balance0,
    balance1,
    balance2,
    reset0,
    reset1,
    reset2,
    inc0,
    inc1,
    inc2,
    keep,
    add,
    sub
} for SSBalance global;
