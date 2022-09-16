## TCKO: KimlikDAO Token


### Utility
1 TCKO represents a share of all assets of the KimlikDAO treasury located
at `kimlikdao.eth` and 1 voting right for all treasury investment decisions.

Any TCKO holder can redeem their share of the DAO treasury assets by
transferring their TCKOs to `kimlikdao.eth` on Avalanche C-chain. Such a
transfer burns the transferred TCKOs and sends the redeemer their share of
the treasury. The share of the redeemer is `sentAmount / totalSupply()`
fraction of all the ERC20 tokens and AVAX the treasury has.
Note however that the market value of TCKO is ought to be higher than the
redemption amount, as TCKO represents a share in KimlikDAO's future cash
flow as well. The redemption amount is merely a lower bound on TCKOs value
and this functionality should only be used as a last resort.
 
Investment decisions are made through proposals to swap some treasury assets
to other assets on a DEX, which are voted on-chain by all TCKO holders. Once
a voting has been completed, the decided upon trade is executed by the
`kimlikdao.eth` contract using the nominated DEX.

Combined with a TCKT, TCKO gives a person voting rights for non-financial
decisions of KimlikDAO also; however in such decisions the voting weight is
not necessarily proportional to one's TCKO holdings (guaranteed to be
sub-linear in one's TCKO holdings). Since TCKT is an ID token, it allows us
to enforce the sub-linear voting weight.

### Supply Cap
There will be 100M TCKOs minted ever, distributed over 5 rounds of 20M TCKOs
each.

Inside the contract, we keep track of another variable `distroStage`, which
ranges between 0 and 7 inclusive, and can be mapped to the `distroRound` as
follows.

> distroRound :=  distroStage / 2 + (distroStage == 0 ? 1 : 2)

The `distroStage` has 8 values, corresponding to the beginning and the
ending of the 5 distribution rounds; see `DistroStage` enum.
The `distroStage` can only be incremented, and only by `dev.kimlikdao.eth`
by calling the `incrementDistroStage()` method of this contract.

In distribution rounds 3 and 4, 20M TCKOs are minted to `kimlikdao.eth`
automatically, to be sold / distributed to the public by `kimlikdao.eth`.
In the rest of the rounds (1, 2, and 5), the minting is manually managed
by `dev.kimlikdao.eth`, however the total minted TCKOs is capped at
distroRound * 20M TCKOs at any moment during the lifetime of the contract.
Additionally, in round 2, the `presale2Contract` is also given minting
rights, again respecting the 20M * distroRound supply cap.

Since the `releaseRound` cannot be incremented beyond 5, this ensures that
there can be at most 100M TCKOs minted.

### Lockup
Each mint to external parties results in some unlocked and some locked
TCKOs, and the ratio is fixed globally. Only the 40M TCKOs minted to
`kimlikdao.eth` across rounds 3 and 4 are fully unlocked.

The unlocking schedule is as follows:
| Minted in round  |  Unlock time    |
|------------------|-----------------|
|   Round 1        |  End of round 3 |
|   Round 2        |  End of round 4 |
|   Round 3        |  Unlocked       |
|   Round 4        |  Unlocked       |
|   Round 5        |  Year 2028      |

```
Define:
  (D1) distroRound := distroStage / 2 + (distroStage == 0 ? 1 : 2)

Facts:
  (F1) 1 <= distroRound <= 5

Invariants:
  (I1) supplyCap() <= 20M * 1M * distroRound
  (I2) sum_a(balanceOf(a)) == totalSupply <= totalMinted
  (I3) totalMinted <= supplyCap()
  (I4) balanceOf(KILITLI_TCKO) == KilitliTCKO.totalSupply()
```
(F1) follows because DistroStage has 8 values and floor(7/2) + 2 = 5.
Combining (F1) and (I1) gives the 100M TCKO supply cap.

### Voting
TCKOs support three concurrent snapshots, allowing users to participate
in three polls / voting at the same time. The voting contract should call
the `snapshot0()` method at the beginning of the voting. When a user votes,
their voting weight is obtained by calling the

> `snapshot0BalanceOf(address)`,
> `snapshot1BalanceOf(address)` or
> `snapshot2BalanceOf(address)`

methods. All operations are constant time, moreover use the same amount of
storage as just keeping the TCKO balances. This is achieved by packing the
snapshot values, ticks and the user balance all into the same EVM word.
