Set the minimum balance floor for an asset in a BittyVault on Ethereum mainnet. Owner-only operation (DEFAULT_ADMIN_ROLE).

The vault will refuse any sell trade that would leave less than this amount of the asset. Set to `0` to allow selling the full balance.

**Usage:** `/set-minimal-balance <asset> <min_balance>`

- `<asset>` — token symbol (WETH, WBTC, USDT, USDC, USDS) or raw `0x…` address
- `<min_balance>` — minimum token balance that must remain after any sell (human-readable, e.g. `10` for 10 WETH). Use `0` to remove the floor.

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as two parts: asset, min_balance.
If either is missing, stop and print: "Usage: /set-minimal-balance <asset> <min_balance>"

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
echo "SAFE_ADDRESS=${SAFE_ADDRESS:?SAFE_ADDRESS is not set}" && \
echo "PROPOSER_PRIVATE_KEY=${PROPOSER_PRIVATE_KEY:?PROPOSER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Resolve asset address and decimals

If `<asset>` matches a known symbol (case-insensitive), use the table above.
If `<asset>` starts with `0x`, fetch its decimals:

```bash
cast call <asset_address> "decimals()(uint8)" \
  --rpc-url "<rpc_url>"
```

### 3. Convert amount to raw units

- 18 decimals: `cast to-unit <min_balance>ether wei`
- Other decimals: `<min_balance> * 10^<decimals>` as integer

Save as `<min_balance_raw>`.

### 4. Fetch current minimal balance

```bash
cast call $VAULT_ADDRESS \
  "minimalBalance(address)(uint256)" \
  "<asset_address>" \
  --rpc-url "<rpc_url>"
```

### 5. Show preview and ask for confirmation

Print:
```
⚠ This is Ethereum mainnet — real funds will be affected.

Vault           : $VAULT_ADDRESS
Asset           : <asset_symbol> (<asset_address>)
Current floor   : <current_min_balance> (raw)
New floor       : <min_balance> <asset_symbol> (<min_balance_raw> raw)
```

Ask: "Proceed with updating minimal balance? (yes/no)"
If no, stop.

### 6. Call setMinimalBalance

```bash
CALLDATA=$(cast calldata \
  "setMinimalBalance(address,uint256)" \
  "<asset_address>" \
  "<min_balance_raw>")
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
cast call $VAULT_ADDRESS \
  "minimalBalance(address)(uint256)" \
  "<asset_address>" \
  --rpc-url "<rpc_url>"
```

Print:
```
Minimal balance updated!
  Safe     : $SAFE_ADDRESS
  Tx hash  : $SAFE_TX_HASH
  Queue    : https://app.safe.global/transactions/queue?safe=eth:$SAFE_ADDRESS

Owners can review and execute at the Safe UI link above.
  Asset     : <asset_symbol>
  New floor : <verified_min_balance> (raw)
```
