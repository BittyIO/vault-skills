Set rebalance limits for an asset in a BittyVault on Ethereum mainnet. Owner-only operation (DEFAULT_ADMIN_ROLE).

Controls how the asset manager can trade a specific asset: minimum balance to keep, cooldown between swaps, and max sell amount per swap.

**Usage:** `/set-rebalance-config <asset> <min_balance> <min_duration_seconds> <max_amount>`

- `<asset>` — token symbol (WETH, WBTC, USDC, USDT, USDS) or raw `0x…` address
- `<min_balance>` — minimum token balance that must remain after a sell (human-readable, e.g. `10` for 10 WETH). Use `0` for no minimum.
- `<min_duration_seconds>` — seconds between rebalances for this asset. Use `0` for no cooldown.
- `<max_amount>` — maximum sell amount per rebalance (human-readable). Use `0` for no limit.

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as four parts: asset, min_balance, min_duration_seconds, max_amount.
If any are missing, stop and print: "Usage: /set-rebalance-config <asset> <min_balance> <min_duration> <max_amount>"

---

## Hardcoded mainnet configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | 18 |
| WBTC | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` | 8 |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | 6 |
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` | 6 |
| USDS | `0xdC035D45d973E3EC169d2276DDab16f1e407384F` | 18 |

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "OWNER_PRIVATE_KEY=${OWNER_PRIVATE_KEY:?OWNER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Resolve asset address and decimals

If `<asset>` matches a known symbol (case-insensitive), use the table above.
If `<asset>` starts with `0x`, fetch its decimals:

```bash
cast call <asset_address> "decimals()(uint8)" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

### 3. Convert amounts to raw units

- `<min_balance>`: convert using token decimals (e.g. for 18 decimals: `cast to-unit <min_balance>ether wei`)
- `<max_amount>`: convert using token decimals (same method)
- `<min_duration_seconds>`: use as-is (already in seconds)

Save as `<min_balance_raw>`, `<min_duration>`, `<max_amount_raw>`.

### 4. Fetch current rebalance config

```bash
cast call $VAULT_ADDRESS \
  "rebalanceConfigs(address)((uint256,uint256,uint256))" \
  "<asset_address>" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

### 5. Show preview and ask for confirmation

Print:
```
This is Ethereum mainnet — real funds will be affected.

Vault           : $VAULT_ADDRESS
Asset           : <asset_symbol> (<asset_address>)

Current config:
  minimalBalance  : <current_min_balance> (raw)
  minimalDuration : <current_min_duration> seconds
  maxAmount       : <current_max_amount> (raw)

New config:
  minimalBalance  : <min_balance> <asset_symbol> (<min_balance_raw> raw)
  minimalDuration : <min_duration> seconds
  maxAmount       : <max_amount> <asset_symbol> (<max_amount_raw> raw)
```

Ask: "Proceed with updating rebalance config? (yes/no)"
If no, stop.

### 6. Call setRebalanceConfig

```bash
cast send $VAULT_ADDRESS \
  "setRebalanceConfig(address,(uint256,uint256,uint256))" \
  "<asset_address>" \
  "(<min_balance_raw>,<min_duration>,<max_amount_raw>)" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 7. Verify and show result

```bash
cast call $VAULT_ADDRESS \
  "rebalanceConfigs(address)((uint256,uint256,uint256))" \
  "<asset_address>" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
Rebalance config updated!
  Tx hash         : <tx_hash>
  Etherscan       : https://etherscan.io/tx/<tx_hash>
  Asset           : <asset_symbol>
  minimalBalance  : <verified_min_balance> (raw)
  minimalDuration : <verified_min_duration> seconds
  maxAmount       : <verified_max_amount> (raw)
```
