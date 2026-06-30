Remove protocols from a BittyVault on Sepolia. Owner-only operation (DEFAULT_ADMIN_ROLE).

**Usage:** `/remove-protocols <type> <address1> [address2] ...`

- `<type>` — protocol type: `lending`, `staking`, or `amm`
- `<address>` — protocol contract address(es) to remove

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: first token is `<type>`, remaining tokens are protocol addresses.
If `<type>` or at least one address is missing, stop and print: "Usage: /remove-protocols <lending|staking|amm> <address1> [address2] ..."

---

## Steps

### 1. Check environment variables

```bash
echo "SAFE_ADDRESS=${SAFE_ADDRESS:?SAFE_ADDRESS is not set}" && \
echo "PROPOSER_PRIVATE_KEY=${PROPOSER_PRIVATE_KEY:?PROPOSER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Validate protocol type

`<type>` must be one of: `lending`, `staking`, `amm` (case-insensitive).
If invalid, stop and print: "Error: Invalid protocol type '<type>'. Use: lending, staking, or amm"

### 3. Fetch current protocols of that type

Based on `<type>`, call the appropriate getter:

- `lending`: `cast call $VAULT_ADDRESS "getLendingProtocols()(address[])" --rpc-url "<rpc_url>"`
- `staking`: `cast call $VAULT_ADDRESS "getStakingProtocols()(address[])" --rpc-url "<rpc_url>"`
- `amm`: `cast call $VAULT_ADDRESS "getAMMProtocols()(address[])" --rpc-url "<rpc_url>"`

### 4. Show preview and ask for confirmation

Print:
```
Vault              : $VAULT_ADDRESS
Protocol type      : <type>
Current protocols  : <current_list>
Removing           : [<addr1>, <addr2>, ...]
```

Ask: "Proceed with removing protocols? (yes/no)"
If no, stop.

### 5. Call the appropriate remove function

Based on `<type>`:

- `lending`:
```bash
CALLDATA=$(cast calldata \
  "removeLendingProtocols(address[])" "[<addr1>,<addr2>,...]")
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

- `staking`:
```bash
CALLDATA=$(cast calldata \
  "removeStakingProtocols(address[])" "[<addr1>,<addr2>,...]")
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

- `amm`:
```bash
CALLDATA=$(cast calldata \
  "removeAMMProtocols(address[])" "[<addr1>,<addr2>,...]")
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

Re-fetch protocols using the same getter as step 3.

Print:
```
Protocols removed!
  Safe     : $SAFE_ADDRESS
  Tx hash  : $SAFE_TX_HASH
  Queue    : https://app.safe.global/transactions/queue?safe=sep:$SAFE_ADDRESS

Owners can review and execute at the Safe UI link above.
  Remaining protocols  : <updated_list>
```
