Cancel an active CoW Swap limit order on a BittyVault on Ethereum mainnet.

**Usage:** `/cancel-order <order_id>`

- `<order_id>` — the bytes32 orderId returned by `/limit-sell` or `/limit-buy`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: first token is `<order_id>`. If missing, stop and print usage.

---

## Hardcoded mainnet configuration

CoW Swap intent protocol: resolved from the vault on-chain (see step 2).
CoW Swap explorer (mainnet): `https://explorer.cow.fi/`

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set}"
```

### 2. Encode the cancel data

```bash
INTENT_PROTOCOL=$(cast call $VAULT_ADDRESS "getIntentProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[] ' | cut -d, -f1)
CANCEL_DATA=$(cast abi-encode "f(bytes32)" "<order_id>")
```

If `$INTENT_PROTOCOL` is empty, stop: "Error: no CoW Swap protocol registered on this vault. Ask the vault owner to add it via the web app (Manage → Protocols)."

### 3. Show preview and ask for confirmation

```
⚠ Cancel CoW Swap limit order — MAINNET
Vault            : $VAULT_ADDRESS
Order ID         : <order_id>
Intent protocol  : $INTENT_PROTOCOL
CoW Explorer     : https://explorer.cow.fi/orders/<order_id>
```

Ask: "Cancel this order on MAINNET? (yes/no)" — if no, stop.

### 4. Call cancelLimitOrder on the vault

```bash
cast send $VAULT_ADDRESS \
  "cancelLimitOrder(address,bytes)" \
  "$INTENT_PROTOCOL" \
  "$CANCEL_DATA" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

### 5. Show result

```
Order cancelled!
  Tx hash      : <tx_hash>
  Etherscan    : https://etherscan.io/tx/<tx_hash>
  Order ID     : <order_id>
```
