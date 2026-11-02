Create a CoW Swap TWAP buy (DCA) for a BittyVault: spend `sell_per_part` of one token every
`interval` for `n_parts` parts, accumulating at least `total_buy` of another. Gasless — the asset
manager signs the whole schedule ONCE; part 0 is posted now and the Bitty API posts each later part
as its slot opens.

Under the hood every part is a fill-or-kill SELL of `sell_per_part` with a floor of
`total_buy / n_parts` — the contract's TWAP parts are always sells.

**Usage:** `/twap-buy <from_asset> <to_asset> <total_buy> <sell_per_part> <n_parts> <interval>`

- `<from_asset>` — token to spend: symbol (WETH, WBTC, USDC, USDT) or raw `0x…`
- `<to_asset>` — token to accumulate: symbol or raw `0x…`
- `<total_buy>` — the least to receive across all parts, before the 0.2% fee (human-readable)
- `<sell_per_part>` — what each part spends
- `<n_parts>` — number of parts (2 or more)
- `<interval>` — time between parts: seconds, or `15m`, `1h`, `1d` …  (at least 5 minutes)

Part `i` can fill only between `start + i·interval` and `start + (i+1)·interval`; a part that does
not fill in its slot is skipped.

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as the six values above. If any is missing, stop and print the usage line.

Run every command from the repo root.

---

## Steps

### 1. Preflight — needs the `INTENT` permission (bit 8)

```bash
bin/bitty preflight 8
```

If it prints an `Error:`, show it and stop. Otherwise show its summary.

### 2. Resolve and size the schedule

```bash
bin/bitty token <from_asset>
bin/bitty token <to_asset>
bin/bitty balance <from_address>
bin/bitty call "isAssetAllowed(address)(bool)" <to_address>
```

- `<interval>` → seconds (`<duration>`); stop if under 300.
- `bin/bitty raw <sell_per_part> <from_decimals>` → `<sell_raw>`.
- `bin/bitty raw <total_buy> <to_decimals>` → `<total_buy_raw>`; per part, less the fee:
  `<buy_per_part> = (<total_buy_raw> // <n_parts>) * 9980 // 10000`.
- Stop if `<n_parts>` < 2, an amount is 0, the tokens are the same, the buy token is not allowed, or
  `<sell_raw> * <n_parts>` exceeds the wallet balance.

### 3. Preview and confirm

```
TWAP buy (CoW)
  Vault       : <vault>
  Spend       : <sell_per_part> <from_symbol> × <n_parts> = <total> <from_symbol>
  Receive ≥   : <total_buy> <to_symbol> in all before fee (<human of buy_per_part> per part after it)
  Every       : <interval>, the last part expiring <n_parts × interval> from now
```

If the CoW relayer has no allowance for `<from_symbol>` yet, say a one-off `approveIntentSpender`
transaction is sent first. Ask: "Start TWAP? (yes/no)". Stop on anything but yes.

### 4. Sign, post part 0, schedule the rest

```bash
bin/bitty twap <from_address> <to_address> <sell_raw> <buy_per_part> <duration> <n_parts> buy
```

It prints `APP_DATA=…`, `START=…`, `PART0_UID=…` and `SCHEDULED=…`. On an `Error:`, show it and stop.
If `SCHEDULED=no`, the Bitty API did not take the schedule: only part 0 is live and no later part
will be posted. The output then lists every part as `PART_UID=…`; tell the user to cancel them all
with `/cancel-order <uid> …` (the schedule's signature is public in part 0) and to try again.

### 5. Result

```
TWAP buy started — <n_parts> parts, one every <interval>.
  Schedule  : <APP_DATA>
  Part 0    : <COW_EXPLORER from bin/bitty env><PART0_UID>
  Cancel    : /cancel-twap <APP_DATA>
```
