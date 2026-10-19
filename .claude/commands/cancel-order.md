Cancel a CoW Swap limit order of a BittyVault on Sepolia.

**Usage:** `/cancel-order <order_uid>`

- `<order_uid>` — the 56-byte CoW order UID printed by `/limit-sell` or `/limit-buy`

Arguments: $ARGUMENTS

If missing, stop and print usage.

---

CoW's API cannot soft-cancel an eip1271 order, so the vault invalidates the UID on the CoW settlement
contract itself with `cancelIntentOrder` — one on-chain transaction, after which the order can never
settle. Any live asset manager may cancel (no permission bit needed). An order that is already filled
or expired needs no cancel.

---

## Steps

### 1. Check environment and resolve the intent protocol

```bash
: "${PRIVATE_KEY:?PRIVATE_KEY is not set — run /new-assetmanager first}"
: "${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
GUARD=$(cast call $VAULT_ADDRESS "guard()(address)" --rpc-url "<rpc_url>")
for p in $(cast call $GUARD "getProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[],'); do
  [ "$(cast call $GUARD "protocolCategory(address)(uint8)" $p --rpc-url "<rpc_url>")" = 4 ] && INTENT_PROTOCOL=$p
done
```

### 2. Look up the order

```bash
curl -s "https://api.cow.fi/sepolia/api/v1/orders/<order_uid>"
```

Check `owner` is `$VAULT_ADDRESS` (stop otherwise) and show `status`, sell/buy tokens and amounts,
`validTo`. If `status` is `fulfilled`, `expired` or `cancelled`, stop: nothing to cancel.

### 3. Confirm

Ask: "Cancel order <order_uid>? (yes/no)"

### 4. Cancel on-chain

```bash
cast send $VAULT_ADDRESS "cancelIntentOrder(address,bytes)" \
  $INTENT_PROTOCOL <order_uid> \
  --rpc-url "<rpc_url>" --private-key "$PRIVATE_KEY"
```

### 5. Show result

```
Order cancelled!
  Tx       : https://sepolia.etherscan.io/tx/<tx_hash>
  Order    : https://explorer.cow.fi/sepolia/orders/<order_uid>
```
