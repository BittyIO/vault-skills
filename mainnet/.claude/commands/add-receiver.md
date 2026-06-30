Add a payment receiver to a BittyVault on Ethereum mainnet. Owner-only operation (DEFAULT_ADMIN_ROLE).

Receivers define scheduled or triggered payments from the vault to a specific address.

**Usage:** `/add-receiver <name> <receiver_address> <asset> <amount> <payment_count> <start_timestamp> <duration_seconds> [trigger] [immutable] [pay_insufficient]`

- `<name>` — unique name for the receiver
- `<receiver_address>` — address that receives payments
- `<asset>` — token symbol (WETH, WBTC, USDC, USDT, USDS) or raw `0x…` address
- `<amount>` — human-readable payment amount per payment (e.g. `1.5`)
- `<payment_count>` — number of payments (1-255)
- `<start_timestamp>` — unix timestamp when payments can begin (use `now` for current time)
- `<duration_seconds>` — minimum seconds between payments
- `[trigger]` — optional trigger address (only this address can trigger payment). Use `0x0` or omit for no trigger.
- `[immutable]` — optional `true`/`false` (default `false`). If true, receiver cannot be updated or removed.
- `[pay_insufficient]` — optional `true`/`false` (default `false`). If true, payment won't revert on insufficient balance.

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` into the fields above. At minimum, the first 7 are required.
If any required field is missing, stop and print usage.

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
echo "SAFE_ADDRESS=${SAFE_ADDRESS:?SAFE_ADDRESS is not set}" && \
echo "PROPOSER_PRIVATE_KEY=${PROPOSER_PRIVATE_KEY:?PROPOSER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Resolve asset address and decimals

If `<asset>` matches a known symbol (case-insensitive), use the table above.
If `<asset>` starts with `0x`, fetch its decimals:

```bash
cast call <asset_address> "decimals()(uint8)" \
  --rpc-url "<rpc_url>"
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
Receiver name            : <name>
Receiver address         : <receiver_address>
Asset                    : <asset_symbol> (<asset_address>)
Amount per payment       : <amount> <asset_symbol> (<amount_raw> raw)
Payment count            : <payment_count>
Start timestamp          : <start_timestamp>
Duration between payments: <duration_seconds> seconds
Trigger                  : <trigger> (0x0 = anyone can trigger)
Immutable                : <immutable>
Pay with insufficient    : <pay_insufficient>
```

Ask: "Proceed with adding receiver? (yes/no)"
If no, stop.

### 7. Call addReceiver on the vault

The Receiver struct is: `(address receiverAddress, address trigger, address assetAddress, uint256 amount, uint8 paymentCount, uint256 startTimestamp, uint256 durationTimestamp, bool isImmutable, bool payWithInsufficientBalance)`

```bash
CALLDATA=$(cast calldata \
  "addReceiver(string,(address,address,address,uint256,uint8,uint256,uint256,bool,bool))" \
  "<name>" \
  "(<receiver_address>,<trigger>,<asset_address>,<amount_raw>,<payment_count>,<start_timestamp>,<duration_seconds>,<immutable>,<pay_insufficient>)")
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

If the transaction reverts, print the revert reason and stop.

### 8. Show result

Print:
```
Receiver added!
  Safe     : $SAFE_ADDRESS
  Tx hash  : $SAFE_TX_HASH
  Queue    : https://app.safe.global/transactions/queue?safe=eth:$SAFE_ADDRESS

Owners can review and execute at the Safe UI link above.
  Name      : <name>
  Recipient : <receiver_address>
  Asset     : <asset_symbol>
  Amount    : <amount> per payment x <payment_count> payments
```
