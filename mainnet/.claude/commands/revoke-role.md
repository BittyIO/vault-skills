Revoke the ASSET_MANAGER_ROLE from an address on a BittyVault on Ethereum mainnet. Owner-only operation (DEFAULT_ADMIN_ROLE).

**Usage:** `/revoke-role <address>`

- `<address>` — Ethereum address to revoke the asset manager role from

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as `<address>`.
If empty, stop and print: "Usage: /revoke-role <address>"

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "SAFE_ADDRESS=${SAFE_ADDRESS:?SAFE_ADDRESS is not set}" && \
echo "PROPOSER_PRIVATE_KEY=${PROPOSER_PRIVATE_KEY:?PROPOSER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Check if address has the role

The ASSET_MANAGER_ROLE hash is `0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce` (keccak256 of "ASSET_MANAGER_ROLE").

```bash
cast call $VAULT_ADDRESS \
  "hasRole(bytes32,address)(bool)" \
  "0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce" \
  "<address>" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

If `false`, stop and print: "Address <address> does not have ASSET_MANAGER_ROLE."

### 3. Show preview and ask for confirmation

Print:
```
This is Ethereum mainnet.

Vault           : $VAULT_ADDRESS
Revoking role   : ASSET_MANAGER_ROLE
From address    : <address>

This address will no longer be able to execute any operations on the vault.
```

Ask: "Proceed with revoking role? (yes/no)"
If no, stop.

### 4. Call revokeRole

```bash
CALLDATA=$(cast calldata \
  "revokeRole(bytes32,address)" \
  "0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce" \
  "<address>")
```

```bash
NONCE=$(cast call $SAFE_ADDRESS "nonce()(uint256)" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY")

SAFE_TX_HASH=$(cast call $SAFE_ADDRESS \
  "getTransactionHash(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,uint256)(bytes32)" \
  "$VAULT_ADDRESS" "0" "$CALLDATA" "0" "0" "0" "0" \
  "0x0000000000000000000000000000000000000000" \
  "0x0000000000000000000000000000000000000000" \
  "$NONCE" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY")

PROPOSER=$(cast wallet address --private-key "$PROPOSER_PRIVATE_KEY")
SIG=$(cast wallet sign --no-hash "$SAFE_TX_HASH" --private-key "$PROPOSER_PRIVATE_KEY")

curl -s -X POST \
  "https://safe-transaction-mainnet.safe.global/api/v1/safes/$SAFE_ADDRESS/multisig-transactions/" \
  -H "Content-Type: application/json" \
  -d '{"to": "$VAULT_ADDRESS", "value": "0", "data": "$CALLDATA", "operation": 0, "safeTxGas": "0", "baseGas": "0", "gasPrice": "0", "gasToken": "0x0000000000000000000000000000000000000000", "refundReceiver": "0x0000000000000000000000000000000000000000", "nonce": $NONCE, "contractTransactionHash": "$SAFE_TX_HASH", "sender": "$PROPOSER", "signature": "$SIG"}'
```

If the transaction reverts, print the revert reason and stop.

### 5. Verify and show result

```bash
cast call $VAULT_ADDRESS \
  "hasRole(bytes32,address)(bool)" \
  "0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce" \
  "<address>" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
Role revoked!
  Safe     : $SAFE_ADDRESS
  Tx hash  : $SAFE_TX_HASH
  Queue    : https://app.safe.global/transactions/queue?safe=eth:$SAFE_ADDRESS

Owners can review and execute at the Safe UI link above.
  Address   : <address>
  Role      : ASSET_MANAGER_ROLE (removed)
```
