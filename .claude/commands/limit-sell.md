Place a gasless CoW Swap limit sell order from a BittyVault on Sepolia: sell exactly `sell_amount`, receive at least `buy_amount_min`.

**Usage:** `/limit-sell <from_asset> <to_asset> <sell_amount> <buy_amount_min> [valid_duration]`

- `<from_asset>` — token to sell: symbol (WETH, WBTC, USDT, USDC) or raw `0x…`
- `<to_asset>` — token to buy: symbol or raw `0x…`
- `<sell_amount>` — exact amount to sell (human-readable)
- `<buy_amount_min>` — minimum amount to receive
- `[valid_duration]` — `1h`, `6h`, `24h` (default), `7d`

Arguments: $ARGUMENTS

If the first 4 are missing, stop and print usage.

---

## How it works

Nothing is placed on-chain. The asset manager signs the CoW order off-chain (EIP-712) and it is posted
to CoW's orderbook with `signingScheme: eip1271`, the vault as owner and receiver. At settlement CoW
calls the vault's `isValidSignature`; the vault's CoW clone re-checks the order and that the signer is
the owner or a manager with `PERM_INTENT`, that the buy token is allowed, and that the vault still
holds the sell amount. Fill-or-kill, 0.2% partner fee via the order's appData.

`scripts/cow.sh` does the signing and posting, and runs the clone's own check before anything is
posted. The only on-chain transaction is a one-time `approveIntentRelayer` per sell token.

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

Convert both amounts to raw units with each token's decimals. Check the vault's `balanceOf` of the sell
token covers `<sell_raw>`; stop if not.

`1h` → 3600, `6h` → 21600, `24h` → 86400, `7d` → 604800:
```bash
VALID_TO=$(( $(date +%s) + <seconds> ))
```

### 3. Preview and confirm

```
CoW limit SELL (gasless)
Vault       : $VAULT_ADDRESS
Sell        : <sell_amount> <from> (<sell_raw> raw)
Buy (min)   : <buy_amount_min> <to> (<buy_raw> raw)
Valid until : <date of VALID_TO>
```

Ask: "Sign and post this order? (yes/no)"

### 4. Sign and post

```bash
RPC_URL="<rpc_url>" ./scripts/cow.sh limit $VAULT_ADDRESS \
  <from_address> <to_address> <sell_raw> <buy_raw> $VALID_TO sell
```

It prints `UID=` and `EXPLORER=`. If it stops with "CoW is not enabled on this vault yet", the owner must
call `updateProtocols([<protocol>],[])` on the vault (the script prints the address). If it stops with
"the vault would reject this order", the key lacks `PERM_INTENT`, its grant has expired, the buy token
is not allowed, or the balance is short.

### 5. Show result

```
Limit sell posted!
  Order UID : <UID>
  Explorer  : <EXPLORER>
  Sell      : <sell_amount> <from>
  Buy (min) : <buy_amount_min> <to>
  Expires   : <date>

Cancel with /cancel-order <UID>
```
