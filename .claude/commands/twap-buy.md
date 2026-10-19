Create a gasless CoW Swap TWAP buy (DCA) on a BittyVault on Sepolia: spend `sell_per_part` of one token every `interval`, receiving at least `total_buy / n_parts` each time.

**Usage:** `/twap-buy <from_asset> <to_asset> <total_buy> <sell_per_part> <n_parts> <interval>`

- `<from_asset>` — token to spend: symbol (WETH, WBTC, USDT, USDC) or `0x…`
- `<to_asset>` — token to accumulate: symbol or `0x…`
- `<total_buy>` — minimum total to receive across all parts (human-readable)
- `<sell_per_part>` — amount spent per part
- `<n_parts>` — number of DCA intervals (e.g. `30`)
- `<interval>` — seconds per part (e.g. `86400` daily)

Arguments: $ARGUMENTS

If any are missing, stop and print usage.

---

A TWAP buy is a TWAP sell seen from the other side: every part is a fill-or-kill **sell** of
`<sell_per_part>` with a floor of `<total_buy> / <n_parts>`. Follow `/twap-sell` from step 1, with:

- `<sell_per_part_raw>` = raw `<sell_per_part>` (from-token decimals)
- `<min_per_part_raw>` = raw `<total_buy>` ÷ `<n_parts>` (to-token decimals, integer)

and preview it as:
```
CoW TWAP BUY / DCA (gasless)
Vault        : $VAULT_ADDRESS
Accumulate   : at least <total_buy> <to> over <n_parts> parts
Per part     : spend <sell_per_part> <from> → at least <total_buy / n_parts> <to>
Interval     : <interval>s  (ends <date>)
```
