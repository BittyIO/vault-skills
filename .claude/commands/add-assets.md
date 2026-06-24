Add assets to a BittyVault on Sepolia. Owner-only operation (DEFAULT_ADMIN_ROLE).

**Usage:** `/add-assets <asset1> [asset2] [asset3] ...`

- Each `<asset>` — token symbol (WETH, WBTC, USDT, USDC) or a raw `0x…` address

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as a space-separated list of assets.
If empty, stop and print: "Usage: /add-assets <asset1> [asset2] ..."

---

## Hardcoded Sepolia configuration

| Symbol | Address |
|--------|---------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` |
| WETH_UNI | `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14` |
| WETH_AAVE | `0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c` |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` |

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "OWNER_PRIVATE_KEY=${OWNER_PRIVATE_KEY:?OWNER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Check if adding assets is disabled

```bash
cast call $VAULT_ADDRESS "isAddingAssetsDisabled()(bool)" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

If `true`, stop and print:
```
Error: Adding assets has been permanently disabled on this vault.
```

### 3. Resolve asset addresses

For each asset in the list:
- If it matches a known symbol (case-insensitive), use the table above.
- If it starts with `0x`, use it directly.

Build the Solidity array: `[<addr1>,<addr2>,...]`

### 4. Fetch current assets

```bash
cast call $VAULT_ADDRESS "getAssets()(address[])" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call $VAULT_ADDRESS "getStableCoins()(address[])" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

### 5. Show preview and ask for confirmation

Print:
```
Vault           : $VAULT_ADDRESS
Current assets  : <current_asset_list>
Adding          : <resolved_addresses>
```

Ask: "Proceed with adding assets? (yes/no)"
If no, stop.

### 6. Call addAssets on the vault

```bash
cast send $VAULT_ADDRESS \
  "addAssets(address[])" \
  "[<addr1>,<addr2>,...]" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 7. Verify and show result

```bash
cast call $VAULT_ADDRESS "getAssets()(address[])" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call $VAULT_ADDRESS "getStableCoins()(address[])" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
Assets added!
  Tx hash       : <tx_hash>
  Etherscan     : https://sepolia.etherscan.io/tx/<tx_hash>
  Updated assets: <new_asset_list>
```
