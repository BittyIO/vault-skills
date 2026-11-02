Place a CoW Swap limit BUY order for a BittyVault: receive exactly `buy_amount`, spending at
most `sell_amount_max`, filled by CoW solvers off-chain. Gasless to place — the asset manager signs the order; no transaction unless the CoW relayer first needs an allowance on the sell token.

**Usage:** `/limit-buy <from_asset> <to_asset> <buy_amount> <sell_amount_max> [valid_for]`

- `<from_asset>` — token to spend: symbol (WETH, WBTC, USDC, USDT) or raw `0x…`
- `<to_asset>` — token to receive: symbol or raw `0x…`
- `<buy_amount>` — exact amount to receive (human-readable)
- `<sell_amount_max>` — the most you spend for it, before the 0.2% fee
- `[valid_for]` — `1h`, `6h`, `24h` (default), `7d`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: from_asset, to_asset, buy_amount, sell_amount_max, optional valid_for. If any
of the first four is missing, stop and print the usage line.

Run every command from the repo root.

---

## Steps

### 1. Preflight — needs the `INTENT` permission (bit 8)

```bash
bin/bitty preflight 8
```

If it prints an `Error:`, show it and stop. Otherwise show its summary.

### 2. Resolve both assets and the amounts

```bash
bin/bitty token <from_asset>
bin/bitty token <to_asset>
bin/bitty balance <from_address>
bin/bitty call "isAssetAllowed(address)(bool)" <to_address>
```

- `bin/bitty raw <buy_amount> <to_decimals>` → `<buy_raw>`
- `bin/bitty raw <sell_amount_max> <from_decimals>` → `<sell_max_raw>`

The 0.2% partner fee is added to what is spent, so the order may spend the cap plus the fee:

```bash
python3 -c 'print(<sell_max_raw> * 10020 // 10000)'    # → <sell_raw>
```

Stop if the tokens are the same, an amount is 0, `<sell_raw>` exceeds the wallet balance (the vault
must cover the whole cap for CoW to accept the order), or the buy token is not allowed.

Expiry: `valid_for` in seconds (`1h`=3600, `6h`=21600, `24h`=86400, `7d`=604800) added to now:

```bash
python3 -c 'import time; print(int(time.time()) + <seconds>)'   # → <valid_to>
```

### 3. Preview and confirm

```
Limit buy (CoW)
  Vault      : <vault>
  Receive    : <buy_amount> <to_symbol>  (<buy_raw> raw)
  Spend ≤    : <sell_amount_max> <from_symbol> before fee, <human of sell_raw> with the 0.2% fee
  Price ≤    : <sell_amount_max / buy_amount> <from_symbol> per <to_symbol>
  Valid until: <valid_to as a local date>
```

If the CoW relayer does not yet have an allowance for `<from_symbol>`, say that a one-off
`approveIntentSpender` transaction is sent first. Ask: "Place order? (yes/no)". Stop on anything
but yes.

### 4. Sign and post

```bash
bin/bitty limit buy <from_address> <to_address> <sell_raw> <buy_raw> <valid_to>
```

It approves the relayer when needed, registers the fee-bearing appData, signs the order with the
asset manager's key, posts it as an `eip1271` order from the vault, and prints the order UID. On an
`Error:`, show it and stop.

### 5. Result

```
Limit buy placed.
  Order UID : <uid>
  Explorer  : <COW_EXPLORER from bin/bitty env><uid>
  Cancel    : /cancel-intent-order <uid>
```
