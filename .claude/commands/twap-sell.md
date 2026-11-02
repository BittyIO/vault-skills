Create a CoW Swap TWAP sell for a BittyVault: sell `total_sell` in `n_parts` equal parts,
one every `interval`, each receiving at least `min_per_part`. Gasless — the asset manager signs the whole schedule ONCE; part 0 is posted now and the Bitty API posts each later part as its slot opens.

**Usage:** `/twap-sell <from_asset> <to_asset> <total_sell> <min_per_part> <n_parts> <interval>`

- `<from_asset>` — token to sell: symbol (WETH, WBTC, USDC, USDT) or raw `0x…`
- `<to_asset>` — token to receive: symbol or raw `0x…`
- `<total_sell>` — total to sell across all parts (human-readable)
- `<min_per_part>` — the least each part accepts, before the 0.2% fee
- `<n_parts>` — number of parts (2 or more)
- `<interval>` — time between parts: seconds, or `15m`, `1h`, `1d` …  (at least 5 minutes)

Each part can fill only inside its own slot: part `i` opens at `start + i·interval` and expires at
`start + (i+1)·interval`. A part that does not fill in its slot is skipped, not carried over.

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
- `bin/bitty raw <total_sell> <from_decimals>` → `<total_raw>`;
  `<sell_per_part> = <total_raw> // <n_parts>` (the remainder stays in the vault).
- `bin/bitty raw <min_per_part> <to_decimals>` → `<min_raw>`; the fee comes out of what is bought:
  `<buy_per_part> = <min_raw> * 9980 // 10000`.
- Stop if `<n_parts>` < 2, an amount is 0, the tokens are the same, the buy token is not allowed, or
  `<sell_per_part> * <n_parts>` exceeds the wallet balance. (Each part is checked against the
  balance when it settles, so the vault must keep enough for the parts still to come.)

### 3. Preview and confirm

```
TWAP sell (CoW)
  Vault       : <vault>
  Sell        : <human of sell_per_part> <from_symbol> × <n_parts> = <human total> <from_symbol>
  Each part ≥ : <min_per_part> <to_symbol> before fee, <human of buy_per_part> after the 0.2% fee
  Every       : <interval>, the last part expiring <n_parts × interval> from now
```

If the CoW relayer has no allowance for `<from_symbol>` yet, say a one-off `approveIntentSpender`
transaction is sent first. Ask: "Start TWAP? (yes/no)". Stop on anything but yes.

### 4. Sign, post part 0, schedule the rest

```bash
bin/bitty twap <from_address> <to_address> <sell_per_part> <buy_per_part> <duration> <n_parts> sell
```

It prints `APP_DATA=…` (the schedule's id), `START=…`, `PART0_UID=…` and `SCHEDULED=…`. On an
`Error:`, show it and stop. If `SCHEDULED=no`, the Bitty API did not take the schedule: only part 0 is
live and no later part will be posted. The output then lists every part as `PART_UID=…`; tell the
user to cancel them all with `/cancel-order <uid> …` (the schedule's signature is public in part 0,
so anyone could post a later part) and to try again.

### 5. Result

```
TWAP started — <n_parts> parts, one every <interval>.
  Schedule  : <APP_DATA>
  Part 0    : <COW_EXPLORER from bin/bitty env><PART0_UID>
  Cancel    : /cancel-twap <APP_DATA>
```
