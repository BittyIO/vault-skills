Withdraw a supplied asset from the Aave lending protocol back into a BittyVault on Sepolia.

**Usage:** `/withdraw <asset> <amount>`

- `<asset>` — token symbol (WETH, WBTC, USDT, USDC) or a raw `0x…` address
- `<amount>` — human-readable amount (e.g. `1.5`), or `max` to withdraw everything

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as two parts: asset, amount.
If any are missing, stop and print: "Usage: /withdraw <asset> <amount>"

---

## Sepolia tokens

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 |
| USDC | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` | 6 |

---

## Steps

### 1. Check environment and resolve the lending protocol

```bash
: "${PRIVATE_KEY:?PRIVATE_KEY is not set — run /new-assetmanager first}"
: "${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
GUARD=$(cast call $VAULT_ADDRESS "guard()(address)" --rpc-url "<rpc_url>")
for p in $(cast call $GUARD "getProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[],'); do
  [ "$(cast call $GUARD "protocolCategory(address)(uint8)" $p --rpc-url "<rpc_url>")" = 2 ] && LENDING_PROTOCOL=$p
done
```

### 2. Read the position and resolve the amount

```bash
cast call $VAULT_ADDRESS "getBalances(address[],address[])(uint256[])" \
  "[$LENDING_PROTOCOL]" "[<asset_address>]" --rpc-url "<rpc_url>"
```

Save as `<supplied_before>`. If it is 0, stop: "Nothing supplied for <symbol>."
`max` → `<supplied_before>`. Otherwise convert `<amount>` to raw units with the token's decimals; if it
exceeds `<supplied_before>`, stop and show both.

### 3. Preview and confirm

Print vault, asset, amount and `<supplied_before>`. Ask: "Proceed with withdraw? (yes/no)"

### 4. Withdraw

```bash
cast send $VAULT_ADDRESS "withdraw(address,address,uint256)" \
  $LENDING_PROTOCOL <asset_address> <amount_raw> \
  --rpc-url "<rpc_url>" --private-key "$PRIVATE_KEY"
```

Any live asset manager may withdraw — no permission bit is needed, since the funds land back in the vault.

### 5. Show result

Re-read the position and the vault's token balance (`balanceOf`), then print:
```
Withdraw successful!
  Tx            : https://sepolia.etherscan.io/tx/<tx_hash>
  Withdrawn     : <amount> <symbol>
  Position      : <supplied_before> → <supplied_after> (raw)
  Vault balance : <balance_after> (raw)
```
