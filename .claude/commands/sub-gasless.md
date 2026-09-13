Set the gasless (relayer fee) budget for a BittyVault **sub-vault**, as the **sub owner**, on Sepolia.

**Usage:** `/sub-gasless <daily_limit> <max_fee_per_op>`

- `<daily_limit>` — the sub-vault's daily gasless budget, a `uint64` (whole units, non-negative)
- `<max_fee_per_op>` — the per-operation fee cap, a `uint64` (whole units, non-negative)

Here `$VAULT_ADDRESS` is the **sub-vault** address, and `$PRIVATE_KEY` is the **sub owner's** key (the sub owner is `owner()` of the sub-vault).

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as two parts: daily_limit, max_fee_per_op.
If either is missing, stop and print: "Usage: /sub-gasless <daily_limit> <max_fee_per_op>"

Validate both parse as non-negative integers (they are `uint64`). If either is not, stop and print:
```
Error: both <daily_limit> and <max_fee_per_op> must be non-negative integers.
```

The contract caps these values: `setGasless` reverts `GasBudgetTooHigh()` if `<daily_limit>` exceeds the system daily maximum, or `FeeExceedsPerOpCap()` if `<max_fee_per_op>` exceeds the system per-operation cap. Surface the revert reason if it fails.

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set — the sub owner's key}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — set it to the SUB-VAULT address}"
```

### 2. Read current gasless config (before)

```bash
cast call $VAULT_ADDRESS "gaslessConfig()(bool,uint256,uint256)" --rpc-url "<rpc_url>"
```

This returns `(enabled, dailyLimit, maxFeePerOp)`. Save them as `<enabled>`, `<daily_before>`, `<fee_before>`.

### 3. Show preview and ask for confirmation

Print:
```
Sub-vault        : $VAULT_ADDRESS
Gasless enabled  : <enabled>
Daily limit      : <daily_before> → <daily_limit>
Max fee per op   : <fee_before> → <max_fee_per_op>
```

Ask: "Update the sub-vault gasless config? (yes/no)"
If no, stop.

### 4. Call setGasless on the sub-vault

```bash
cast send $VAULT_ADDRESS \
  "setGasless(uint64,uint64)" \
  <daily_limit> \
  <max_fee_per_op> \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop. Common reasons:
- `NotSubOwner()` — this key is not the sub owner of the sub-vault
- `GasBudgetTooHigh()` — `<daily_limit>` exceeds the system daily maximum
- `FeeExceedsPerOpCap()` — `<max_fee_per_op>` exceeds the system per-operation cap

### 5. Verify and show result

```bash
cast call $VAULT_ADDRESS "gaslessConfig()(bool,uint256,uint256)" --rpc-url "<rpc_url>"
```

Print a final summary:
```
Gasless config updated!
  Tx hash        : <tx_hash>
  Etherscan      : https://sepolia.etherscan.io/tx/<tx_hash>
  Daily limit    : <daily_after>
  Max fee per op : <fee_after>
```
