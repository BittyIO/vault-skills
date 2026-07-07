Cancel an active CoW Swap limit order on a BittyVault on Ethereum mainnet.

**Usage:** `/cancel-order <order_id>`

- `<order_id>` — the bytes32 orderId returned by `/limit-sell` or `/limit-buy`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: first token is `<order_id>`. If missing, stop and print usage.

---

## Hardcoded mainnet configuration

CoW Swap intent protocol (mainnet): `0xDf923AEFEe2Ac3a995C66f6998C52680154C56Ca`
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
CANCEL_DATA=$(cast abi-encode "f(bytes32)" "<order_id>")
```

### 3. Show preview and ask for confirmation

```
⚠ Cancel CoW Swap limit order — MAINNET
Vault            : $VAULT_ADDRESS
Order ID         : <order_id>
Intent protocol  : 0xDf923AEFEe2Ac3a995C66f6998C52680154C56Ca
CoW Explorer     : https://explorer.cow.fi/orders/<order_id>
```

Ask: "Cancel this order on MAINNET? (yes/no)" — if no, stop.

### 4. Call cancelLimitOrder on the vault

```bash
cast send $VAULT_ADDRESS \
  "cancelLimitOrder(address,bytes)" \
  "0xDf923AEFEe2Ac3a995C66f6998C52680154C56Ca" \
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
