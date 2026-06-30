Add protocols to a BittyVault on Ethereum mainnet. Owner-only operation (DEFAULT_ADMIN_ROLE).

**Usage:** `/add-protocols <type> <address1> [address2] ...`

- `<type>` — protocol type: `lending`, `staking`, `amm`, or `intent`
- `<address>` — protocol contract address(es)

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: first token is `<type>`, remaining tokens are protocol addresses.
If `<type>` or at least one address is missing, stop and print: "Usage: /add-protocols <lending|staking|amm|intent> <address1> [address2] ..."

---

## Hardcoded mainnet configuration

| Protocol | Type | Address |
|----------|------|---------|
| Aave V3 | lending | `0x1ee9040bD2E2418a4CbC8754865D595920EF9301` |
| Lido V2 | staking | `0xcEecA8ba582180d014378AAFcaA5f324C77BE2A7` |
| Uniswap V3 | amm | `0xcC07F93057755f0E655B8411ee55a1192E385684` |
| Sky V1 | sky | `0xb3fF9DF07F2901D97c07146d18093dE914141AD3` |
| CoW Swap V1 | intent | `0xBB75486D48d93023DC377746e1d0be1D81C2a037` |

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "SAFE_ADDRESS=${SAFE_ADDRESS:?SAFE_ADDRESS is not set}" && \
echo "PROPOSER_PRIVATE_KEY=${PROPOSER_PRIVATE_KEY:?PROPOSER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Check if adding protocols is disabled

```bash
cast call $VAULT_ADDRESS "isAddingProtocolsDisabled()(bool)" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

If `true`, stop and print:
```
Error: Adding protocols has been permanently disabled on this vault.
```

### 3. Validate protocol type

`<type>` must be one of: `lending`, `staking`, `amm` (case-insensitive).
If invalid, stop and print: "Error: Invalid protocol type '<type>'. Use: lending, staking, or amm"

### 4. Fetch current protocols of that type

Based on `<type>`, call the appropriate getter:

- `lending`: `cast call $VAULT_ADDRESS "getLendingProtocols()(address[])" --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"`
- `staking`: `cast call $VAULT_ADDRESS "getStakingProtocols()(address[])" --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"`
- `amm`: `cast call $VAULT_ADDRESS "getAMMProtocols()(address[])" --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"`

### 5. Show preview and ask for confirmation

Print:
```
This is Ethereum mainnet — real funds will be affected.

Vault              : $VAULT_ADDRESS
Protocol type      : <type>
Current protocols  : <current_list>
Adding             : [<addr1>, <addr2>, ...]
```

Ask: "Proceed with adding protocols? (yes/no)"
If no, stop.

### 6. Call the appropriate add function

Based on `<type>`:

- `lending`:
```bash
CALLDATA=$(cast calldata \
  "addLendingProtocols(address[])" "[<addr1>,<addr2>,...]")
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

- `staking`:
```bash
CALLDATA=$(cast calldata \
  "addStakingProtocols(address[])" "[<addr1>,<addr2>,...]")
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

- `amm`:
```bash
CALLDATA=$(cast calldata \
  "addAMMProtocols(address[])" "[<addr1>,<addr2>,...]")
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

### 7. Verify and show result

Re-fetch protocols using the same getter as step 4.

Print:
```
Protocols added!
  Safe     : $SAFE_ADDRESS
  Tx hash  : $SAFE_TX_HASH
  Queue    : https://app.safe.global/transactions/queue?safe=eth:$SAFE_ADDRESS

Owners can review and execute at the Safe UI link above.
  Updated protocols  : <new_list>
```
