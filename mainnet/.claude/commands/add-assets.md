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
echo "SAFE_ADDRESS=${SAFE_ADDRESS:?SAFE_ADDRESS is not set}" && \
echo "PROPOSER_PRIVATE_KEY=${PROPOSER_PRIVATE_KEY:?PROPOSER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Check if adding assets is disabled

```bash
cast call $VAULT_ADDRESS "isAddingAssetsDisabled()(bool)" \
  --rpc-url "<rpc_url>"
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
  --rpc-url "<rpc_url>"

cast call $VAULT_ADDRESS "getStableCoins()(address[])" \
  --rpc-url "<rpc_url>"
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
CALLDATA=$(cast calldata \
  "addAssets(address[])" \
  "[<addr1>,<addr2>,...]")
```

```bash
NONCE=$(cast call $SAFE_ADDRESS "nonce()(uint256)" \
  --rpc-url "<rpc_url>")

SAFE_TX_HASH=$(cast call $SAFE_ADDRESS \
  "getTransactionHash(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,uint256)(bytes32)" \
  "$VAULT_ADDRESS" "0" "$CALLDATA" "0" "0" "0" "0" \
  "0x0000000000000000000000000000000000000000" \
  "0x0000000000000000000000000000000000000000" \
  "$NONCE" \
  --rpc-url "<rpc_url>")

PROPOSER=$(cast wallet address --private-key "$PROPOSER_PRIVATE_KEY")
SIG=$(cast wallet sign --no-hash "$SAFE_TX_HASH" --private-key "$PROPOSER_PRIVATE_KEY")

curl -s -X POST \
  "https://safe-transaction-mainnet.safe.global/api/v1/safes/$SAFE_ADDRESS/multisig-transactions/" \
  -H "Content-Type: application/json" \
  -d '{"to": "$VAULT_ADDRESS", "value": "0", "data": "$CALLDATA", "operation": 0, "safeTxGas": "0", "baseGas": "0", "gasPrice": "0", "gasToken": "0x0000000000000000000000000000000000000000", "refundReceiver": "0x0000000000000000000000000000000000000000", "nonce": $NONCE, "contractTransactionHash": "$SAFE_TX_HASH", "sender": "$PROPOSER", "signature": "$SIG"}'
```

If the transaction reverts, print the revert reason and stop.

### 7. Verify and show result

```bash
cast call $VAULT_ADDRESS "getAssets()(address[])" \
  --rpc-url "<rpc_url>"

cast call $VAULT_ADDRESS "getStableCoins()(address[])" \
  --rpc-url "<rpc_url>"
```

Print:
```
Assets added!
  Safe     : $SAFE_ADDRESS
  Tx hash  : $SAFE_TX_HASH
  Queue    : https://app.safe.global/transactions/queue?safe=eth:$SAFE_ADDRESS

Owners can review and execute at the Safe UI link above.
  Updated assets: <new_asset_list>
```
