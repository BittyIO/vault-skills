Permanently disable adding new assets to a BittyVault on Sepolia. Owner-only operation (DEFAULT_ADMIN_ROLE).

**This is IRREVERSIBLE.** After locking, no new assets can be added. Existing assets can still be removed.

**Usage:** `/lock-assets`

No arguments needed.

---

## Steps

### 1. Check environment variables

```bash
echo "SAFE_ADDRESS=${SAFE_ADDRESS:?SAFE_ADDRESS is not set}" && \
echo "PROPOSER_PRIVATE_KEY=${PROPOSER_PRIVATE_KEY:?PROPOSER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Check if already disabled

```bash
cast call $VAULT_ADDRESS "isAddingAssetsDisabled()(bool)" \
  --rpc-url "<rpc_url>"
```

If `true`, stop and print: "Adding assets is already disabled on this vault."

### 3. Fetch current assets

```bash
cast call $VAULT_ADDRESS "getAssets()(address[])" \
  --rpc-url "<rpc_url>"

cast call $VAULT_ADDRESS "getStableCoins()(address[])" \
  --rpc-url "<rpc_url>"
```

### 4. Show warning and ask for confirmation

Print:
```
WARNING: This action is IRREVERSIBLE.

Vault          : $VAULT_ADDRESS
Current assets : <asset_list>

After locking:
  - No new assets can ever be added to this vault
  - Existing assets can still be removed
  - The asset manager can only trade assets currently in the vault
```

Ask: "Type 'LOCK' to confirm, or anything else to cancel:"
If the user does not type exactly `LOCK`, stop.

### 5. Call disableAddingAssets

```bash
CALLDATA=$(cast calldata \
  "disableAddingAssets()")
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
  "https://safe-transaction-sepolia.safe.global/api/v1/safes/$SAFE_ADDRESS/multisig-transactions/" \
  -H "Content-Type: application/json" \
  -d '{"to": "$VAULT_ADDRESS", "value": "0", "data": "$CALLDATA", "operation": 0, "safeTxGas": "0", "baseGas": "0", "gasPrice": "0", "gasToken": "0x0000000000000000000000000000000000000000", "refundReceiver": "0x0000000000000000000000000000000000000000", "nonce": $NONCE, "contractTransactionHash": "$SAFE_TX_HASH", "sender": "$PROPOSER", "signature": "$SIG"}'
```

If the transaction reverts, print the revert reason and stop.

### 6. Verify and show result

```bash
cast call $VAULT_ADDRESS "isAddingAssetsDisabled()(bool)" \
  --rpc-url "<rpc_url>"
```

Print:
```
Assets locked!
  Safe     : $SAFE_ADDRESS
  Tx hash  : $SAFE_TX_HASH
  Queue    : https://app.safe.global/transactions/queue?safe=sep:$SAFE_ADDRESS

Owners can review and execute at the Safe UI link above.
  Adding assets is now permanently disabled.
```
