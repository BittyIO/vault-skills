Place a CoW Swap limit SELL order for a BittyVault: sell exactly `sell_amount`, receive at
least `buy_amount_min`, filled by CoW solvers off-chain. Gasless to place — the asset manager signs the order; no transaction unless the CoW relayer first needs an allowance on the sell token.

**Usage:** `/limit-sell <from_asset> <to_asset> <sell_amount> <buy_amount_min> [valid_for]`

- `<from_asset>` — token to sell: symbol (WETH, WBTC, USDC, USDT) or raw `0x…`
- `<to_asset>` — token to buy: symbol or raw `0x…`
- `<sell_amount>` — exact amount to sell (human-readable)
- `<buy_amount_min>` — the least you accept for it, before the 0.2% fee
- `[valid_for]` — `1h`, `6h`, `24h` (default), `7d`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: from_asset, to_asset, sell_amount, buy_amount_min, optional valid_for. If any
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

- `bin/bitty raw <sell_amount> <from_decimals>` → `<sell_raw>`
- `bin/bitty raw <buy_amount_min> <to_decimals>` → `<buy_min_raw>`
- Stop if the tokens are the same, an amount is 0, `<sell_raw>` exceeds the wallet balance (CoW
  checks the vault can cover it, and so does the vault at settlement), or the buy token is not
  allowed.

The 0.2% partner fee comes out of what is bought, so the order asks for the floor less the fee:

```bash
python3 -c 'print(<buy_min_raw> * 9980 // 10000)'      # → <buy_raw>
```

Expiry: `valid_for` in seconds (`1h`=3600, `6h`=21600, `24h`=86400, `7d`=604800) added to now:

```bash
python3 -c 'import time; print(int(time.time()) + <seconds>)'   # → <valid_to>
```

### 3. Preview and confirm

```
Limit sell (CoW)
  Vault      : <vault>
  Sell       : <sell_amount> <from_symbol>  (<sell_raw> raw)
  Receive ≥  : <buy_amount_min> <to_symbol> before fee, <human of buy_raw> after the 0.2% fee
  Price ≥    : <buy_amount_min / sell_amount> <to_symbol> per <from_symbol>
  Valid until: <valid_to as a local date>
```

If the CoW relayer does not yet have an allowance for `<from_symbol>`, say that a one-off
`approveIntentSpender` transaction is sent first. Ask: "Place order? (yes/no)". Stop on anything
but yes.

### 4. Sign and post

```bash
bin/bitty limit sell <from_address> <to_address> <sell_raw> <buy_raw> <valid_to>
```

It approves the relayer when needed, registers the fee-bearing appData with CoW, signs the order
with the asset manager's key, posts it with `signingScheme=eip1271` (the vault is the signer), and
prints the order UID. On an `Error:`, show it and stop. `InvalidEip1271Signature` from CoW means the
vault refused the order — usually the balance dropped, the grant changed, or the vault's CoW clone is older than 1.0.4
(the owner upgrades it in the Bitty app); rerun the preflight.

### 5. Result

```
Limit sell placed.
  Order UID : <uid>
  Explorer  : <COW_EXPLORER from bin/bitty env><uid>
  Cancel    : /cancel-intent-order <uid>
```
