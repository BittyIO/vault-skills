Update an existing payment receiver in a BittyVault on Ethereum mainnet. Owner-only operation (DEFAULT_ADMIN_ROLE).

Cannot update receivers marked as immutable.

**Usage:** `/update-receiver <name> <receiver_address> <asset> <amount> <payment_count> <start_timestamp> <duration_seconds> [trigger] [immutable] [pay_insufficient]`

- `<name>` — name of the existing receiver to update
- Remaining fields are the same as `/add-receiver`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` into the fields above. At minimum, the first 7 are required.
If any required field is missing, stop and print: "Usage: /update-receiver <name> <receiver_address> <asset> <amount> <payment_count> <start_timestamp> <duration_seconds> [trigger] [immutable] [pay_insufficient]"

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
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

### 3. Convert amount to raw units

- 18 decimals: `cast to-unit <amount>ether wei`
- Other decimals: compute `<amount> * 10^<decimals>` as integer

Save as `<amount_raw>`.

### 4. Resolve start timestamp

If `<start_timestamp>` is `now`, use `$(date +%s)`.

### 5. Set defaults for optional parameters

- `<trigger>`: default `0x0000000000000000000000000000000000000000`
- `<immutable>`: default `false`
- `<pay_insufficient>`: default `false`

### 6. Show preview and ask for confirmation

Print:
```
This is Ethereum mainnet — real funds will be affected.

Vault                    : $VAULT_ADDRESS
Updating receiver        : <name>
New receiver address     : <receiver_address>
Asset                    : <asset_symbol> (<asset_address>)
Amount per payment       : <amount> <asset_symbol> (<amount_raw> raw)
Payment count            : <payment_count>
Start timestamp          : <start_timestamp>
Duration between payments: <duration_seconds> seconds
Trigger                  : <trigger>
Immutable                : <immutable>
Pay with insufficient    : <pay_insufficient>
```

Ask: "Proceed with updating receiver? (yes/no)"
If no, stop.

### 7. Call updateReceiver on the vault

```bash
CALLDATA=$(cast calldata \
  "updateReceiver(string,(address,address,address,uint256,uint8,uint256,uint256,bool,bool))" \
  "<name>" \
  "(<receiver_address>,<trigger>,<asset_address>,<amount_raw>,<payment_count>,<start_timestamp>,<duration_seconds>,<immutable>,<pay_insufficient>)")
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

### 8. Show result

Print:
```
Receiver updated!
  Safe     : $SAFE_ADDRESS
  Tx hash  : $SAFE_TX_HASH
  Queue    : https://app.safe.global/transactions/queue?safe=eth:$SAFE_ADDRESS

Owners can review and execute at the Safe UI link above.
  Name      : <name>
  Recipient : <receiver_address>
  Asset     : <asset_symbol>
  Amount    : <amount> per payment x <payment_count> payments
```
