Supply an asset from a BittyVault into the Aave lending protocol on Ethereum mainnet.

**Usage:** `/supply <asset> <amount>`

- `<asset>` — token symbol (WETH, WBTC, USDC, USDT, USDS) or a raw `0x…` address
- `<amount>` — human-readable amount (e.g. `1.5` for 1.5 WETH)

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as two parts: asset, amount.
If any are missing, stop and print: "Usage: /supply <asset> <amount>"

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
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

Then resolve the lending protocol registered on the vault:

```bash
LENDING_PROTOCOL=$(cast call $VAULT_ADDRESS "getLendingProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[] ' | cut -d, -f1)
```

If `$LENDING_PROTOCOL` is empty, stop: `Error: no Aave lending protocol registered on this vault.`

### 2. Resolve asset address and decimals

If `<asset>` matches a known symbol (case-insensitive), use the table above.
If `<asset>` starts with `0x`, use it directly — then fetch its decimals:

```bash
cast call <asset_address> "decimals()(uint8)" \
  --rpc-url "<rpc_url>"
```

### 3. Convert amount to token units (smallest unit / wei)

Use `cast to-unit` for 18-decimal tokens or multiply for others:

- 18 decimals: `cast to-unit <amount>ether wei` (this outputs integer wei)
- Other decimals: compute `<amount> * 10^<decimals>` as an integer (no decimals in result)

Save the result as `<amount_raw>`.

### 4. Check vault's token balance

```bash
cast call <asset_address> \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

If the balance is less than `<amount_raw>`, stop and print:
```
Error: Vault balance insufficient.
  Vault balance : <balance> (raw units)
  Requested     : <amount_raw> (raw units)
Deposit funds into the vault before supplying.
```

### 5. Check current supplied balance (before)

```bash
cast call $VAULT_ADDRESS \
  "getSuppliedBalance(address,address)(uint256)" \
  "$LENDING_PROTOCOL" \
  "<asset_address>" \
  --rpc-url "<rpc_url>"
```

Save as `<supplied_before>`.

### 6. Show preview and ask for confirmation

Print:
```
⚠ This is Ethereum mainnet — real funds will be used.

Vault           : $VAULT_ADDRESS
Asset           : <asset_symbol> (<asset_address>)
Amount          : <amount> <asset_symbol> (<amount_raw> raw)
Lending protocol: $LENDING_PROTOCOL
Currently supplied: <supplied_before> (raw)
```

Ask: "Proceed with supply? (yes/no)"
If no, stop.

### 7. Call supply on the vault

```bash
cast send $VAULT_ADDRESS \
  "supply(address,address,uint256)" \
  "$LENDING_PROTOCOL" \
  "<asset_address>" \
  "<amount_raw>" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 8. Verify and show result

After the transaction confirms, fetch the new supplied balance:

```bash
cast call $VAULT_ADDRESS \
  "getSuppliedBalance(address,address)(uint256)" \
  "$LENDING_PROTOCOL" \
  "<asset_address>" \
  --rpc-url "<rpc_url>"
```

Print a final summary:
```
Supply successful!
  Tx hash          : <tx_hash>
  Etherscan        : https://etherscan.io/tx/<tx_hash>
  Asset supplied   : <amount> <asset_symbol>
  Supplied before  : <supplied_before> (raw)
  Supplied after   : <supplied_after> (raw)
```
