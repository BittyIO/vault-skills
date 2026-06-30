Set the new-receiver protection duration on a BittyVault on Sepolia. Owner-only operation (DEFAULT_ADMIN_ROLE).

This sets a time-lock window: after a new receiver is added, payments to it are blocked until the protection period has elapsed. This gives the owner time to review and remove a malicious receiver before it can receive funds.

**Usage:** `/set-receiver-protection <duration_seconds>`

- `<duration_seconds>` — protection period in seconds (e.g. `86400` for 1 day, `604800` for 1 week). Use `0` to disable.

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as `<duration_seconds>`.
If empty, stop and print: "Usage: /set-receiver-protection <duration_seconds>"

---

## Steps

### 1. Check environment variables

```bash
echo "SAFE_ADDRESS=${SAFE_ADDRESS:?SAFE_ADDRESS is not set}" && \
echo "PROPOSER_PRIVATE_KEY=${PROPOSER_PRIVATE_KEY:?PROPOSER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Show preview and ask for confirmation

Convert `<duration_seconds>` to a human-readable format (e.g. "1 day", "7 days", "1 hour").

Print:
```
Vault                : $VAULT_ADDRESS
New protection period: <duration_seconds> seconds (<human_readable>)

New receivers will be unable to receive payments for this duration after being added.
Set to 0 to disable protection.
```

Ask: "Proceed with setting receiver protection? (yes/no)"
If no, stop.

### 3. Call setNewReceiverProtection

```bash
CALLDATA=$(cast calldata \
  "setNewReceiverProtection(uint256)" \
  "<duration_seconds>")
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

### 4. Show result

Print:
```
Receiver protection updated!
  Safe     : $SAFE_ADDRESS
  Tx hash  : $SAFE_TX_HASH
  Queue    : https://app.safe.global/transactions/queue?safe=sep:$SAFE_ADDRESS

Owners can review and execute at the Safe UI link above.
  Protection duration : <duration_seconds> seconds (<human_readable>)
```
