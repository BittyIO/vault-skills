Add a payment receiver to a BittyVault on Sepolia. Owner-only operation (DEFAULT_ADMIN_ROLE).

Receivers define scheduled or triggered payments from the vault to a specific address.

**Usage:** `/add-receiver <name> <receiver_address> <asset> <amount> <payment_count> <start_timestamp> <duration_seconds> [trigger] [immutable] [pay_insufficient]`

- `<name>` — unique name for the receiver
- `<receiver_address>` — address that receives payments
- `<asset>` — token symbol (WETH, WBTC, USDT, USDC) or raw `0x…` address
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

## Hardcoded Sepolia configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` | 6 |

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "OWNER_PRIVATE_KEY=${OWNER_PRIVATE_KEY:?OWNER_PRIVATE_KEY is not set}" && \
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
cast send $VAULT_ADDRESS \
  "addReceiver(string,(address,address,address,uint256,uint8,uint256,uint256,bool,bool))" \
  "<name>" \
  "(<receiver_address>,<trigger>,<asset_address>,<amount_raw>,<payment_count>,<start_timestamp>,<duration_seconds>,<immutable>,<pay_insufficient>)" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 8. Show result

Print:
```
Receiver added!
  Tx hash   : <tx_hash>
  Etherscan : https://sepolia.etherscan.io/tx/<tx_hash>
  Name      : <name>
  Recipient : <receiver_address>
  Asset     : <asset_symbol>
  Amount    : <amount> per payment x <payment_count> payments
```
