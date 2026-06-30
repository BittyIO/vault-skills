Set the minimum balance floor for an asset in a BittyVault on Sepolia. Owner-only operation (DEFAULT_ADMIN_ROLE).

The vault will refuse any sell trade that would leave less than this amount of the asset. Set to `0` to allow selling the full balance.

**Usage:** `/set-minimal-balance <asset> <min_balance>`

- `<asset>` — token symbol (WETH, WBTC, USDT, USDC) or raw `0x…` address
- `<min_balance>` — minimum token balance that must remain after any sell (human-readable, e.g. `10` for 10 WETH). Use `0` to remove the floor.

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as two parts: asset, min_balance.
If either is missing, stop and print: "Usage: /set-minimal-balance <asset> <min_balance>"

---

## Hardcoded Sepolia configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| WETH_UNI | `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14` | 18 |
| WETH_AAVE | `0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c` | 18 |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` | 6 |

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "SAFE_ADDRESS=${SAFE_ADDRESS:?SAFE_ADDRESS is not set}" && \
echo "PROPOSER_PRIVATE_KEY=${PROPOSER_PRIVATE_KEY:?PROPOSER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Resolve asset address and decimals

If `<asset>` matches a known symbol (case-insensitive), use the table above.
If `<asset>` starts with `0x`, fetch its decimals:

```bash
cast call <asset_address> "decimals()(uint8)" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
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
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

### 5. Show preview and ask for confirmation

Print:
```
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

### 7. Verify and show result

```bash
cast call $VAULT_ADDRESS \
  "minimalBalance(address)(uint256)" \
  "<asset_address>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
Minimal balance updated!
  Safe     : $SAFE_ADDRESS
  Tx hash  : $SAFE_TX_HASH
  Queue    : https://app.safe.global/transactions/queue?safe=sep:$SAFE_ADDRESS

Owners can review and execute at the Safe UI link above.
  Asset     : <asset_symbol>
  New floor : <verified_min_balance> (raw)
```
