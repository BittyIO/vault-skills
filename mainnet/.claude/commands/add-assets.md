Add assets to a BittyVault on Ethereum mainnet. Owner-only operation (DEFAULT_ADMIN_ROLE).

**Usage:** `/add-assets <asset1> [asset2] [asset3] ...`

- Each `<asset>` — token symbol (WETH, WBTC, USDC, USDT, USDS) or a raw `0x…` address

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as a space-separated list of assets.
If empty, stop and print: "Usage: /add-assets <asset1> [asset2] ..."

---

## Hardcoded mainnet configuration

| Symbol | Address |
|--------|---------|
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` |
| WBTC | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` |
| USDS | `0xdC035D45d973E3EC169d2276DDab16f1e407384F` |

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
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
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
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call $VAULT_ADDRESS "getStableCoins()(address[])" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

### 5. Show preview and ask for confirmation

Print:
```
This is Ethereum mainnet — real funds will be affected.

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
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 7. Verify and show result

```bash
cast call $VAULT_ADDRESS "getAssets()(address[])" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call $VAULT_ADDRESS "getStableCoins()(address[])" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
Assets added!
  Tx hash       : <tx_hash>
  Etherscan     : https://etherscan.io/tx/<tx_hash>
  Updated assets: <new_asset_list>
```
