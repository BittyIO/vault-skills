Withdraw a supplied asset from a lending protocol (Aave v3) back into a BittyVault.

**Usage:** `/withdraw <asset> <amount|max>`

- `<asset>` — token symbol (WETH, WBTC, USDC, USDT) or a raw `0x…` address
- `<amount>` — human-readable amount, or `max` to withdraw everything supplied

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: asset, amount. If either is missing, stop and print the usage line.

Run every command from the repo root.

---

## Steps

### 1. Preflight — needs the `SUPPLY` permission (bit 2)

A locked vault refuses it: a lock leaves the asset manager's grant dormant until the owner
unlocks. (The owner can still withdraw, in the Bitty app.)

```bash
bin/bitty preflight 2
```

If it prints an `Error:`, show it and stop.

### 2. Resolve the asset

```bash
bin/bitty token <asset>
```

### 3. Find where it is supplied

```bash
bin/bitty protocols lending held        # every lending protocol the vault has a position in
```

For each, read the position:
```bash
bin/bitty position <protocol> <address>
```

Keep the ones with a non-zero position. None → stop: `Error: the vault has no <symbol> supplied.`
Several → list them with their positions and ask which.

### 4. Amount

- `max` → pass `115792089237316195423570985008687907853269984665640564039457584007913129639935`
  (`type(uint256).max`): the protocol withdraws the whole position, interest included.
- Otherwise `bin/bitty raw <amount> <decimals>`; stop if it exceeds the position.

### 5. Preview and confirm

```
Withdraw
  Vault     : <vault>
  Asset     : <amount or "all"> <symbol>
  From      : <name> (<protocol>), position <position, human>
```

Ask: "Withdraw? (yes/no)". Stop on anything but yes.

### 6. Send

```bash
bin/bitty send "withdraw(address,address,uint256)" <protocol> <address> <amount_raw>
```

On a revert, show the reason and stop. Aave error `32` means the pool lacks liquidity right now —
try a smaller amount.

### 7. Result

```bash
bin/bitty position <protocol> <address>
bin/bitty balance <address>
```

```
Withdrew <symbol> from <name>.
  Tx            : <hash and explorer link>
  Still supplied: <position, human>
  Wallet balance: <balance, human>
```
