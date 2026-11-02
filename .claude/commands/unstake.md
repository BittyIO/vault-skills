Unstake an asset from a staking protocol back into a BittyVault.

- **Sky** (USDC) settles at once: the USDC is back in the vault when the transaction lands.
- **Lido** (WETH) is two-step: this requests the withdrawal and returns request ids; once Lido
  finalises them (usually days), run `/claim-withdrawals` to receive the ETH.

**Usage:** `/unstake <asset> <amount|max>`

- `<asset>` — `WETH` (Lido) or `USDC` (Sky), or a raw `0x…` address
- `<amount>` — human-readable amount, or `max` for the whole staked position

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: asset, amount. If either is missing, stop and print the usage line.

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

### 2. Resolve the asset and find the position

```bash
bin/bitty token <asset>
bin/bitty protocols staking held
bin/bitty position <protocol> <address>     # for each held protocol
```

Keep the protocols with a non-zero position in this asset. None → stop:
`Error: the vault has no <symbol> staked.` Several → ask which.

Note the pending ids before sending, to tell the new ones apart afterwards:
```bash
bin/bitty pending <protocol>
```

### 3. Amount

- `max` → pass `115792089237316195423570985008687907853269984665640564039457584007913129639935`
  (`type(uint256).max`).
- Otherwise `bin/bitty raw <amount> <decimals>`; stop if it exceeds the position.

### 4. Preview and confirm

```
Unstake
  Vault    : <vault>
  Asset    : <amount or "all"> <symbol>
  From     : <name> (<protocol>), position <position, human>
  Settles  : <"now" for Sky | "two-step — claim with /claim-withdrawals after Lido finalises" for Lido>
```

On **Sepolia** with Lido, warn: the Lido withdrawal queue is paused there, so this will revert.

Ask: "Unstake? (yes/no)". Stop on anything but yes.

### 5. Send

```bash
bin/bitty send "withdraw(address,address,uint256)" <protocol> <address> <amount_raw>
```

On a revert, show the reason and stop.

### 6. Result

```bash
bin/bitty position <protocol> <address>
bin/bitty pending <protocol>
bin/bitty balance <address>
```

```
Unstaked from <name>.
  Tx             : <hash and explorer link>
  Still staked   : <position, human>
  New request ids: <ids not in the list from step 2>     (Lido only)
  Wallet balance : <balance, human>
```

For Lido: `Run /claim-withdrawals once Lido has finalised the request.`
