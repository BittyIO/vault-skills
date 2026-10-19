Create a gasless CoW Swap TWAP sell on a BittyVault on Sepolia: the total is split into `n_parts` equal sells, one per `interval`.

**Usage:** `/twap-sell <from_asset> <to_asset> <total_sell> <min_per_part> <n_parts> <interval>`

- `<from_asset>` — token to sell: symbol (WETH, WBTC, USDT, USDC) or `0x…`
- `<to_asset>` — token to receive: symbol or `0x…`
- `<total_sell>` — total amount to sell across all parts (human-readable)
- `<min_per_part>` — minimum receive amount per part (price floor per slot)
- `<n_parts>` — number of parts (e.g. `7`)
- `<interval>` — seconds per part (e.g. `3600` hourly, `86400` daily)

Arguments: $ARGUMENTS

If any are missing, stop and print usage.

---

## How it works

The asset manager signs the **whole schedule once** (an EIP-712 `TwapOrder`). Part `i` is a
fill-or-kill sell of `total_sell / n_parts`, valid until `start + (i+1) × interval`, and the vault's
CoW clone rebuilds it from the schedule to validate it — so every part reuses the one signature.
Nothing is placed on-chain except a one-time `approveIntentRelayer` for the sell token.

Each part must be **posted** to CoW when its window opens. This skill posts part 1; run
`/post-twap-part <schedule_file>` at each later interval (or schedule it with `/loop <interval>s
/post-twap-part <schedule_file>`). The schedule and signature are kept in `.twaps/` (git-ignored).

## Sepolia tokens

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 |
| USDC | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` | 6 |

---

## Steps

### 1. Check environment

```bash
: "${PRIVATE_KEY:?PRIVATE_KEY is not set — run /new-assetmanager first}"
: "${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Resolve amounts

`<sell_per_part_raw>` = raw `<total_sell>` ÷ `<n_parts>` (integer, from-token decimals);
`<min_per_part_raw>` = raw `<min_per_part>` (to-token decimals). The vault must hold at least one
part's sell amount whenever a part settles; check `balanceOf` covers the total and warn if not.

### 3. Preview and confirm

```
CoW TWAP SELL (gasless)
Vault         : $VAULT_ADDRESS
Total sell    : <total_sell> <from> in <n_parts> parts
Per part      : <sell_per_part> <from> → at least <min_per_part> <to>
Interval      : <interval>s  (ends <date of now + n_parts × interval>)
```

Ask: "Sign the schedule and post part 1? (yes/no)"

### 4. Sign the schedule and post part 1

```bash
RPC_URL="<rpc_url>" ./scripts/cow.sh twap-new $VAULT_ADDRESS \
  <from_address> <to_address> <sell_per_part_raw> <min_per_part_raw> <n_parts> <interval>
```

It prints `FILE=` (the schedule), then `PART=`, `UID=`, `VALID_TO=`, `EXPLORER=`. Errors are as in
`/limit-sell` step 4.

### 5. Show result

```
TWAP created!
  Schedule  : <FILE>
  Part 1/<n> : <UID>  (valid until <date of VALID_TO>)
  Explorer  : <EXPLORER>

Post later parts: /post-twap-part <FILE>
Cancel:           /cancel-twap <FILE>
```
