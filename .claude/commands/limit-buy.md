Place a gasless CoW Swap limit buy order from a BittyVault on Sepolia: receive exactly `buy_amount`, spending at most `sell_amount_max`.

**Usage:** `/limit-buy <from_asset> <to_asset> <buy_amount> <sell_amount_max> [valid_duration]`

- `<from_asset>` — token to spend: symbol (WETH, WBTC, USDT, USDC) or raw `0x…`
- `<to_asset>` — token to receive: symbol or raw `0x…`
- `<buy_amount>` — exact amount to receive (human-readable)
- `<sell_amount_max>` — maximum amount to spend
- `[valid_duration]` — `1h`, `6h`, `24h` (default), `7d`

Arguments: $ARGUMENTS

If the first 4 are missing, stop and print usage.

---

Same mechanism as `/limit-sell` — signed off-chain by the asset manager, posted with
`signingScheme: eip1271`, validated by the vault's CoW clone at settlement — with `kind: buy`. The
vault must hold the full `sell_amount_max` for the order to validate.

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

### 2. Resolve tokens, amounts and expiry

Convert `<buy_amount>` → `<buy_raw>` (to-token decimals) and `<sell_amount_max>` → `<sell_raw>`
(from-token decimals). Check the vault's from-token `balanceOf` covers `<sell_raw>`; stop if not.

```bash
VALID_TO=$(( $(date +%s) + <seconds> ))   # 1h 3600 · 6h 21600 · 24h 86400 · 7d 604800
```

### 3. Preview and confirm

```
CoW limit BUY (gasless)
Vault       : $VAULT_ADDRESS
Buy         : <buy_amount> <to> (<buy_raw> raw)
Spend (max) : <sell_amount_max> <from> (<sell_raw> raw)
Valid until : <date of VALID_TO>
```

Ask: "Sign and post this order? (yes/no)"

### 4. Sign and post

```bash
RPC_URL="<rpc_url>" ./scripts/cow.sh limit $VAULT_ADDRESS \
  <from_address> <to_address> <sell_raw> <buy_raw> $VALID_TO buy
```

See `/limit-sell` step 4 for the script's error messages.

### 5. Show result

```
Limit buy posted!
  Order UID   : <UID>
  Explorer    : <EXPLORER>
  Buy         : <buy_amount> <to>
  Spend (max) : <sell_amount_max> <from>
  Expires     : <date>

Cancel with /cancel-order <UID>
```
