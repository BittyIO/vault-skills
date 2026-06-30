Remove assets from a BittyVault on Sepolia. Owner-only operation (DEFAULT_ADMIN_ROLE).

**Usage:** `/remove-assets <asset1> [asset2] [asset3] ...`

- Each `<asset>` — token symbol (WETH, WBTC, USDT, USDC) or a raw `0x…` address

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as a space-separated list of assets.
If empty, stop and print: "Usage: /remove-assets <asset1> [asset2] ..."

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
echo "SAFE_ADDRESS=${SAFE_ADDRESS:?SAFE_ADDRESS is not set}" && \
echo "PROPOSER_PRIVATE_KEY=${PROPOSER_PRIVATE_KEY:?PROPOSER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Resolve asset addresses

For each asset in the list:
- If it matches a known symbol (case-insensitive), use the table above.
- If it starts with `0x`, use it directly.

Build the Solidity array: `[<addr1>,<addr2>,...]`

### 3. Fetch current assets

```bash
cast call $VAULT_ADDRESS "getAssets()(address[])" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call $VAULT_ADDRESS "getStableCoins()(address[])" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

### 4. Show preview and ask for confirmation

Print:
```
Vault           : $VAULT_ADDRESS
Current assets  : <current_asset_list>
Removing        : <resolved_addresses>
```

Ask: "Proceed with removing assets? (yes/no)"
If no, stop.

### 5. Call removeAssets on the vault

```bash
CALLDATA=$(cast calldata \
  "removeAssets(address[])" \
  "[<addr1>,<addr2>,...]")
```

```bash
NONCE=$(cast call $SAFE_ADDRESS "nonce()(uint256)" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY")

SAFE_TX_HASH=$(cast call $SAFE_ADDRESS \
  "getTransactionHash(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,uint256)(bytes32)" \
  "$VAULT_ADDRESS" "0" "$CALLDATA" "0" "0" "0" "0" \
  "0x0000000000000000000000000000000000000000" \
  "0x0000000000000000000000000000000000000000" \
  "$NONCE" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY")

PROPOSER=$(cast wallet address --private-key "$PROPOSER_PRIVATE_KEY")
SIG=$(cast wallet sign --no-hash "$SAFE_TX_HASH" --private-key "$PROPOSER_PRIVATE_KEY")

curl -s -X POST \
  "https://safe-transaction-sepolia.safe.global/api/v1/safes/$SAFE_ADDRESS/multisig-transactions/" \
  -H "Content-Type: application/json" \
  -d '{"to": "$VAULT_ADDRESS", "value": "0", "data": "$CALLDATA", "operation": 0, "safeTxGas": "0", "baseGas": "0", "gasPrice": "0", "gasToken": "0x0000000000000000000000000000000000000000", "refundReceiver": "0x0000000000000000000000000000000000000000", "nonce": $NONCE, "contractTransactionHash": "$SAFE_TX_HASH", "sender": "$PROPOSER", "signature": "$SIG"}'
```

If the transaction reverts, print the revert reason and stop.

### 6. Verify and show result

```bash
cast call $VAULT_ADDRESS "getAssets()(address[])" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call $VAULT_ADDRESS "getStableCoins()(address[])" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
Assets removed!
  Safe     : $SAFE_ADDRESS
  Tx hash  : $SAFE_TX_HASH
  Queue    : https://app.safe.global/transactions/queue?safe=sep:$SAFE_ADDRESS

Owners can review and execute at the Safe UI link above.
  Remaining assets: <updated_asset_list>
```
