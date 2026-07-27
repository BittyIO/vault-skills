Trigger a scheduled payment from a BittyVault on Sepolia. Permissionless — anyone may call it once the payment is due (unless the payment has a trigger address, in which case only that address can).

**Usage:** `/pay-scheduled <id> [amount]`

- `<id>` — the scheduled payment's numeric id
- `[amount]` — optional: pay a partial amount instead of the full configured amount (human-readable). Partial payments require the payment to have a trigger address, and the caller must be that trigger.

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: first token is `<id>`, optional second token is `<amount>`.
If `<id>` is missing or not a number, stop and print: "Usage: /pay-scheduled <id> [amount]"

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set}"
```

### 2. Show preview and ask for confirmation

Print:
```
Vault      : $VAULT_ADDRESS
Payment id : <id>
Amount     : <amount if specified, otherwise "full configured amount">
```

Ask: "Proceed with payment? (yes/no)"
If no, stop.

### 3. Execute payment

If `<amount>` was provided, resolve the payment's asset decimals and convert to raw, then call `payScheduledAmount`:

```bash
cast send $VAULT_ADDRESS \
  "payScheduledAmount(uint256,uint256)" \
  "<id>" \
  "<amount_raw>" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If `<amount>` was NOT provided, call `payScheduled`:

```bash
cast send $VAULT_ADDRESS \
  "payScheduled(uint256)" \
  "<id>" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop. Common reasons:
- `ScheduledPaymentNotFound()` — no payment with that id
- `PaymentNotApproved()` — the payment is an operator proposal the owner has not approved yet
- `ScheduledPaymentNotStartYet()` — start timestamp hasn't been reached
- `ScheduledPaymentInInterval()` — still within the interval window since the last payment
- `ScheduledPaymentPaymentCountZero()` — the payment has no payments remaining
- `ProtectionPeriodNotEnded()` — the payment's protection window hasn't elapsed yet
- `ScheduledPaymentTriggerError()` — the payment has a trigger address and the caller isn't it
- `PayScheduledPaymentAmountTriggerEmpty()` — partial amounts need a trigger address configured
- `InsufficientBalance()` — vault doesn't have enough of the asset

### 4. Show result

Print:
```
Payment sent!
  Tx hash    : <tx_hash>
  Etherscan  : https://sepolia.etherscan.io/tx/<tx_hash>
  Payment id : <id>
```
