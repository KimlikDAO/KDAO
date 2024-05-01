// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "interfaces/erc/IERC20.sol";
import {DistroStage, IDistroStage} from "interfaces/kimlikdao/IDistroStage.sol";
import {KDAO_ZKSYNC} from "interfaces/kimlikdao/addresses.sol";
import {KDAO_ETHEREUM, PROTOCOL_FUND, VOTING} from "interfaces/kimlikdao/addresses.sol";
import {uint128x2} from "interfaces/types/uint128x2.sol";

/**
 * @title KDAO-l: Locked KimlikDAO Token
 *
 * A LockedKDAO represents a locked KDAO, which cannot be redeemed or
 * transferred, but turns into a KDAO automatically at the prescribed
 * `DistroStage`.
 *
 * The unlocking is triggered by the `unlockAllEven()` or `unlockAllOdd()` methods
 * permissionlessly.
 *
 * Invariants:
 *   (I1) sum_a(balances[a].sum()) == totalSupply
 *   (I2) totalSupply == KDAO.balanceOf(address(this))
 *   (I3) lo(balance[a]) > 0 => accounts0.includes(a)
 *   (I4) hi(balance[a]) > 0 => accounts1.includes(a)
 */
contract KDAOLocked is IERC20 {
    uint256 public override totalSupply;

    mapping(address => uint128x2) private balances;
    // Split Presale2 accounts out, so that even if we can't unlock them in
    // one shot due to gas limit, we can still unlock others in one shot.
    address[] private addrs0;
    address[] private addrs1;

    function name() external pure override returns (string memory) {
        return "Locked KDAO";
    }

    function symbol() external pure override returns (string memory) {
        return "KDAO-l";
    }

    function decimals() external pure override returns (uint8) {
        return 6;
    }

    function balanceOf(address addr) external view override returns (uint256) {
        return balances[addr].sum();
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

    ///////////////////////////////////////////////////////////////////////////
    //
    // KimlikDAO protocol specific methods
    //
    ///////////////////////////////////////////////////////////////////////////

    function mint(address addr, uint256 amount, DistroStage stage) external {
        require(msg.sender == KDAO_ZKSYNC);
        if (uint256(stage) & 1 == 0) {
            addrs0.push(addr);
            balances[addr] = balances[addr].incLo(amount);
        } else {
            addrs1.push(addr);
            balances[addr] == balances[addr].incHi(amount);
        }
        unchecked {
            totalSupply += amount;
        }
        emit Transfer(address(this), addr, amount);
    }

    function unlock(address addr) public returns (bool) {
        DistroStage stage = IDistroStage(KDAO_ZKSYNC).distroStage();
        uint256 unlocked;
        uint128x2 balance = balances[addr];
        if (stage >= DistroStage.ProtocolSaleEnd && stage != DistroStage.FinalMint) {
            unchecked {
                unlocked += balance.lo();
            }
            balance = balance.clearLo();
        }
        if (stage >= DistroStage.Presale2Unlock) {
            unchecked {
                unlocked += balance.hi(); // No overflow since totalBalance <= 100_000_000e6
            }
            balance = balance.clearHi();
        }
        if (unlocked > 0) {
            balances[addr] = balance;
            emit Transfer(addr, address(this), unlocked);
            unchecked {
                totalSupply -= unlocked;
            }
            IERC20(KDAO_ZKSYNC).transfer(addr, unlocked);
            return true;
        }
        return false;
    }

    function unlockAllEven() external {
        DistroStage stage = IDistroStage(KDAO_ZKSYNC).distroStage();
        require(stage >= DistroStage.ProtocolSaleEnd && stage != DistroStage.FinalMint, "KDAO-l: Not matured");
        unchecked {
            uint256 length = addrs0.length;
            uint256 totalUnlocked;
            for (uint256 i = 0; i < length; ++i) {
                address addr = addrs0[i];
                uint128x2 balance = balances[addr];
                uint256 unlocked = balance.lo();
                if (unlocked > 0) {
                    balances[addr] = balance.clearLo();
                    emit Transfer(addr, address(this), unlocked);
                    totalUnlocked += unlocked;
                    IERC20(KDAO_ZKSYNC).transfer(addr, unlocked);
                }
            }
            totalSupply -= totalUnlocked;
        }
    }

    function unlockAllOdd() external {
        require(IDistroStage(KDAO_ZKSYNC).distroStage() >= DistroStage.Presale2Unlock, "KDAO-l: Not matured");
        unchecked {
            uint256 length = addrs1.length;
            uint256 totalUnlocked;
            for (uint256 i = 0; i < length; ++i) {
                address addr = addrs1[i];
                uint128x2 balance = balances[addr];
                uint256 unlocked = balance.hi();
                if (unlocked > 0) {
                    balances[addr] = balance.clearHi();
                    emit Transfer(addr, address(this), unlocked);
                    totalUnlocked += unlocked;
                    IERC20(KDAO_ZKSYNC).transfer(addr, unlocked);
                }
            }
            totalSupply -= totalUnlocked;
        }
    }
}
