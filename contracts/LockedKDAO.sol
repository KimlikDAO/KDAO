// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {KDAO_ADDR, KDAO_ADDR, PROTOCOL_FUND, VOTING} from "interfaces/Addresses.sol";
import {DistroStage, IDistroStage} from "interfaces/IDistroStage.sol";
import {IERC20} from "interfaces/IERC20.sol";

/**
 * @title KDAO-l: Locked KimlikDAO Token
 *
 * A LockedKDAO represents a locked KDAO, which cannot be redeemed or
 * transferred, but turns into a KDAO automatically at the prescribed
 * `DistroStage`.
 *
 * The unlocking is triggered by the `PROTOCOL_FUND` using the `unlockAllEven()`
 * or `unlockAllOdd()` methods and the gas is paid by KimlikDAO; the user does
 * not need to take any action to unlock their tokens.
 *
 * Invariants:
 *   (I1) sum_a(lo(balances[a])) + sum_a(hi(balances[a])) == totalSupply
 *   (I2) totalSupply == KDAO.balanceOf(address(this))
 *   (I3) lo(balance[a]) > 0 => accounts0.includes(a)
 *   (I4) hi(balance[a]) > 0 => accounts1.includes(a)
 */
contract LockedKDAO is IERC20 {
    uint256 public override totalSupply;

    mapping(address => uint256) private balances;
    address[] private accounts0;
    // Split Presale2 accounts out, so that even if we can't unlock them in
    // one shot due to gas limit, we can still unlock others in one shot.
    address[] private accounts1;

    function name() external pure override returns (string memory) {
        return "Locked KDAO";
    }

    function symbol() external pure override returns (string memory) {
        return "KDAO-l";
    }

    function decimals() external pure override returns (uint8) {
        return 6;
    }

    uint256 private constant BALANCE0_MASK = type(uint256).max >> 128;

    function balanceOf(address account) external view override returns (uint256) {
        unchecked {
            uint256 balance = balances[account];
            return (balance & BALANCE0_MASK) + (balance >> 128);
        }
    }

    function transfer(address to, uint256) external override returns (bool) {
        if (to == address(this)) return unlock(msg.sender);
        return false;
    }

    function transferFrom(address, address, uint256) external pure override returns (bool) {
        return false;
    }

    function allowance(address, address) external pure override returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure override returns (bool) {
        return false;
    }

    function mint(address account, uint256 amount, DistroStage stage) external {
        require(msg.sender == KDAO_ADDR);
        unchecked {
            if (uint256(stage) & 1 == 0) {
                accounts0.push(account);
                balances[account] += amount;
            } else {
                accounts1.push(account);
                balances[account] += amount << 128;
            }
            totalSupply += amount;
            emit Transfer(address(this), account, amount);
        }
    }

    function unlock(address account) public returns (bool) {
        unchecked {
            DistroStage stage = IDistroStage(KDAO_ADDR).distroStage();
            uint256 locked;
            uint256 balance = balances[account];
            if (stage >= DistroStage.DAOSaleEnd && stage != DistroStage.FinalMint) {
                locked += balance & BALANCE0_MASK;
                balance &= ~BALANCE0_MASK;
            }
            if (stage >= DistroStage.Presale2Unlock) {
                locked += balance >> 128;
                balance &= BALANCE0_MASK;
            }
            if (locked > 0) {
                balances[account] = balance;
                emit Transfer(account, address(this), locked);
                totalSupply -= locked;
                IERC20(KDAO_ADDR).transfer(account, locked);
                return true;
            }
            return false;
        }
    }

    function unlockAllEven() external {
        DistroStage stage = IDistroStage(KDAO_ADDR).distroStage();
        require(stage >= DistroStage.DAOSaleEnd && stage != DistroStage.FinalMint, "KDAO-l: Not matured");
        unchecked {
            uint256 length = accounts0.length;
            uint256 totalUnlocked;
            for (uint256 i = 0; i < length; ++i) {
                address account = accounts0[i];
                uint256 balance = balances[account];
                uint256 locked = balance & BALANCE0_MASK;
                if (locked > 0) {
                    balances[account] = balance & ~BALANCE0_MASK;
                    emit Transfer(account, address(this), locked);
                    totalUnlocked += locked;
                    IERC20(KDAO_ADDR).transfer(account, locked);
                }
            }
            totalSupply -= totalUnlocked;
        }
    }

    function unlockAllOdd() external {
        require(IDistroStage(KDAO_ADDR).distroStage() >= DistroStage.Presale2Unlock, "KDAO-l: Not matured");

        unchecked {
            uint256 length = accounts1.length;
            uint256 totalUnlocked;
            for (uint256 i = 0; i < length; ++i) {
                address account = accounts1[i];
                uint256 balance = balances[account];
                uint256 locked = balance >> 128;
                if (locked > 0) {
                    balances[account] = balance & BALANCE0_MASK;
                    emit Transfer(account, address(this), locked);
                    totalUnlocked += locked;
                    IERC20(KDAO_ADDR).transfer(account, locked);
                }
            }
            totalSupply -= totalUnlocked;
        }
    }

    /**
     * Moves ERC20 tokens sent to this address by accident to `PROTOCOL_FUND`.
     */
    function rescueToken(IERC20 token) external {
        // We restrict this method to `VOTING` only, as we call a method of
        // an unkown contract, which could potentially be a security risk.
        require(msg.sender == VOTING);
        // Disable sending out KDAO to ensure the invariant KDAO.(I4).
        require(address(token) != KDAO_ADDR);
        token.transfer(PROTOCOL_FUND, token.balanceOf(address(this)));
    }
}
