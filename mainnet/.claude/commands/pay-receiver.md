Trigger a payment to a receiver from a BittyVault on Ethereum mainnet. Can be called by anyone (or restricted to a trigger address).

**Usage:** `/pay-receiver <name> [amount]`

- `<name>` — name of the receiver to pay
- `[amount]` — optional: pay a specific amount instead of the full configured amount (human-readable). If omitted, pays the full configured amount.

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: first token is `<name>`, optional second token is `<amount>`.
If `<name>` is missing, stop and print: "Usage: /pay-receiver <name> [amount]"

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "OWNER_PRIVATE_KEY=${OWNER_PRIVATE_KEY:?OWNER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Show preview and ask for confirmation

Print:
```
This is Ethereum mainnet — real funds will be sent.

Vault    : $VAULT_ADDRESS
Receiver : <name>
Amount   : <amount if specified, otherwise "full configured amount">
```

Ask: "Proceed with payment? (yes/no)"
If no, stop.

### 3. Execute payment

If `<amount>` was provided, resolve the asset decimals and convert to raw, then call `payReceiverAmount`:

```bash
cast send $VAULT_ADDRESS \
  "payReceiverAmount(string,uint256)" \
  "<name>" \
  "<amount_raw>" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

If `<amount>` was NOT provided, call `payReceiver`:

```bash
cast send $VAULT_ADDRESS \
  "payReceiver(string)" \
  "<name>" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop. Common reasons:
- `ReceiverNotFound()` — no receiver with that name
- `ReceiverNotStartYet()` — start timestamp hasn't been reached
- `ReceiverInDuration()` — still within the duration window from last payment
- `InsufficientBalance()` — vault doesn't have enough of the asset
- `ReceiverProtectionNotEnded()` — new receiver protection period hasn't elapsed

### 4. Show result

Print:
```
Payment sent!
  Tx hash   : <tx_hash>
  Etherscan : https://etherscan.io/tx/<tx_hash>
  Receiver  : <name>
```
