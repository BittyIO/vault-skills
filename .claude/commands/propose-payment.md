Propose a new scheduled payment on a BittyVault on Sepolia, as a **payout operator**. The proposal sits pending until the vault owner approves it (in the Bitty web app); only then can it pay.

**Usage:** `/propose-payment <recipient> <asset> <amount> <every_days> [count]`

- `<recipient>` — address to pay
- `<asset>` — asset symbol (e.g. USDC) or address; must satisfy the vault's risk controls (with a non-zero scheduled cap, stablecoins only)
- `<amount>` — amount per payment (human-readable)
- `<every_days>` — payment interval in days (minimum 7 for recurring payments)
- `[count]` — number of payments (default 12; use `unlimited` for a never-ending payment)

Arguments: $ARGUMENTS

If any of the first four tokens is missing, stop and print: "Usage: /propose-payment <recipient> <asset> <amount> <every_days> [count]"

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set — the payout operator's key}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set}"
```

### 2. Verify the caller is a payout operator

```bash
cast call $VAULT_ADDRESS "isPayoutOperator(address)(bool)" "<caller_address>" --rpc-url "<rpc_url>"
```

If `false`, stop and print: "This key is not a payout operator of the vault. The owner grants operator seats in the Bitty web app."

### 3. Resolve the asset

If `<asset>` is a symbol, resolve it against `getAssets()(address[])` / `getStableCoins()(address[])` and each token's `symbol()(string)`. Read `decimals()(uint8)` and convert `<amount>` to raw units.

### 4. Show preview and ask for confirmation

Print:
```
Vault     : $VAULT_ADDRESS
Recipient : <recipient>
Asset     : <symbol> (<asset_address>)
Amount    : <amount> per payment
Every     : <every_days> days
Payments  : <count or "unlimited">
Status    : will await OWNER APPROVAL before it can pay
```

Ask: "Propose this payment? (yes/no)"
If no, stop.

### 5. Send the proposal

The scheduled payment is a struct, in this exact field order:
`(scheduledPaymentAddress, remainingPaymentCount, isImmutable, payWithInsufficientBalance, trigger, assetAddress, amount, startTimestamp, paymentInterval)`

- `remainingPaymentCount` — `<count>`, or `255` for unlimited
- `isImmutable` — `false` (operators propose plain payments; permanence is the owner's call)
- `payWithInsufficientBalance` — `true` (skip zero-balance periods without consuming them)
- `trigger` — `0x0000000000000000000000000000000000000000` (anyone may trigger when due)
- `startTimestamp` — now + 10 minutes (unix seconds; must not be in the past at inclusion)
- `paymentInterval` — `<every_days> * 86400`

```bash
cast send $VAULT_ADDRESS \
  "addScheduledPayment((address,uint8,bool,bool,address,address,uint256,uint256,uint256))" \
  "(<recipient>,<count_raw>,false,true,0x0000000000000000000000000000000000000000,<asset_address>,<amount_raw>,<start_ts>,<interval_secs>)" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop. Common reasons:
- `NotPayoutOperator()` — the key holds no operator seat on this vault
- `PaymentNotStableCoin()` — the vault's scheduled cap is active and the asset isn't a registered stablecoin
- `PaymentExceedsRiskCap()` — amount exceeds the vault's maxScheduledValue cap
- `ScheduledPaymentIntervalTooShort()` — interval under 7 days with more than one payment
- `ScheduledPaymentStartTimestampInPast()` — start timestamp already passed
- `AssetAddressNotContract()` — the asset address has no code

### 6. Show result

Decode the `ScheduledPaymentAdded(uint256 indexed id, ...)` event from the receipt for the new id, then print:
```
Payment proposed!
  Tx hash    : <tx_hash>
  Etherscan  : https://sepolia.etherscan.io/tx/<tx_hash>
  Payment id : <id>
  Next step  : the vault owner must approve it in the Bitty web app before it can pay.
```
