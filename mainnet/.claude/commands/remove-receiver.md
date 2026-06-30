Remove a payment receiver from a BittyVault on Ethereum mainnet. Owner-only operation (DEFAULT_ADMIN_ROLE).

Cannot remove receivers marked as immutable.

**Usage:** `/remove-receiver <name>`

- `<name>` — name of the receiver to remove

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as `<name>`.
If empty, stop and print: "Usage: /remove-receiver <name>"

---

## Steps

### 1. Check environment variables

```bash
echo "SAFE_ADDRESS=${SAFE_ADDRESS:?SAFE_ADDRESS is not set}" && \
echo "PROPOSER_PRIVATE_KEY=${PROPOSER_PRIVATE_KEY:?PROPOSER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Show preview and ask for confirmation

Print:
```
This is Ethereum mainnet.

Vault    : $VAULT_ADDRESS
Removing : receiver "<name>"
```

Ask: "Proceed with removing this receiver? (yes/no)"
If no, stop.

### 3. Call removeReceiver on the vault

```bash
CALLDATA=$(cast calldata \
  "removeReceiver(string)" \
  "<name>")
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

If the transaction reverts, print the revert reason and stop. Common reasons:
- `ReceiverNotFound()` — no receiver with that name exists
- `ReceiverImmutable()` — the receiver was created as immutable and cannot be removed

### 4. Show result

Print:
```
Receiver removed!
  Safe     : $SAFE_ADDRESS
  Tx hash  : $SAFE_TX_HASH
  Queue    : https://app.safe.global/transactions/queue?safe=eth:$SAFE_ADDRESS

Owners can review and execute at the Safe UI link above.
  Removed   : "<name>"
```
