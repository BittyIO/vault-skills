Claim finalised staking withdrawals (Lido) into a BittyVault. Step 2 of `/unstake` for
protocols that settle later.

**Usage:** `/claim-withdrawals [request_id …]`

- `[request_id …]` — optional ids to claim. Omitted: every pending id of every staking protocol
  the vault holds a position in.

Arguments: $ARGUMENTS

Run every command from the repo root.

---

## Steps

### 1. Preflight — needs the `YIELD` permission (bit 1)

A locked vault refuses it: a lock leaves the asset manager's grant dormant until the owner
unlocks.

```bash
bin/bitty preflight 1
```

If it prints an `Error:`, show it and stop.

### 2. Find the pending withdrawals

```bash
bin/bitty protocols staking held
bin/bitty pending <protocol>                # for each
```

Skip protocols with no pending ids (Sky never has any — it settles at once).

- No ids anywhere → stop: `Nothing to claim — the vault has no pending withdrawals.`
- Ids given in the arguments → keep only those; an id that is not pending anywhere is an error
  (`Error: request <id> is not pending for this vault.`).

Lido claims only the FINALISED ones among the ids it is given and skips the rest without
reverting, so there is no need to check finality first: whatever is still pending after the claim
is simply not finalised yet. A claim pays out WETH.

### 3. Preview and confirm

```
Claim withdrawals
  Vault    : <vault>
  <name> (<protocol>): ids <id, id, …>
```

Ask: "Claim? (yes/no)". Stop on anything but yes.

### 4. Send — one transaction per protocol

```bash
bin/bitty send "claimWithdrawals(address,uint256[])" <protocol> "[<id>,<id>,…]"
```

On a revert, show the reason and stop.

### 5. Result

```bash
bin/bitty pending <protocol>
bin/bitty balance <WETH address from bin/bitty token WETH>
```

```
Claimed from <name>.
  Tx             : <hash and explorer link>
  Claimed ids    : <ids that are no longer pending>
  Not yet final  : <ids still pending, or "none"> — run /claim-withdrawals again later
  WETH balance   : <human>
```
