Grant the ASSET_MANAGER_ROLE to an address on a BittyVault on Sepolia. Owner-only operation (DEFAULT_ADMIN_ROLE).

The asset manager address cannot be the same as the owner address.

**Usage:** `/grant-role <address>`

- `<address>` — Ethereum address to grant the asset manager role to

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as `<address>`.
If empty, stop and print: "Usage: /grant-role <address>"

---

## Steps

### 1. Check environment variables

```bash
echo "SAFE_ADDRESS=${SAFE_ADDRESS:?SAFE_ADDRESS is not set}" && \
echo "PROPOSER_PRIVATE_KEY=${PROPOSER_PRIVATE_KEY:?PROPOSER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Check if address already has the role

The ASSET_MANAGER_ROLE hash is `0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce` (keccak256 of "ASSET_MANAGER_ROLE").

```bash
cast call $VAULT_ADDRESS \
  "hasRole(bytes32,address)(bool)" \
  "0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce" \
  "<address>" \
  --rpc-url "<rpc_url>"
```

If `true`, stop and print: "Address <address> already has ASSET_MANAGER_ROLE."

### 3. Show preview and ask for confirmation

Print:
```
Vault           : $VAULT_ADDRESS
Granting role   : ASSET_MANAGER_ROLE
To address      : <address>

This address will be able to execute yield and trading operations on the vault.
```

Ask: "Proceed with granting role? (yes/no)"
If no, stop.

### 4. Call grantRole

```bash
CALLDATA=$(cast calldata \
  "grantRole(bytes32,address)" \
  "0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce" \
  "<address>")
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

If the transaction reverts, print the revert reason and stop. Common reasons:
- `OwnerAndAssetManagerMustDiffer()` — cannot grant asset manager role to the vault owner

### 5. Verify and show result

```bash
cast call $VAULT_ADDRESS \
  "hasRole(bytes32,address)(bool)" \
  "0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce" \
  "<address>" \
  --rpc-url "<rpc_url>"
```

Print:
```
Role granted!
  Safe     : $SAFE_ADDRESS
  Tx hash  : $SAFE_TX_HASH
  Queue    : https://app.safe.global/transactions/queue?safe=sep:$SAFE_ADDRESS

Owners can review and execute at the Safe UI link above.
  Address   : <address>
  Role      : ASSET_MANAGER_ROLE
```
