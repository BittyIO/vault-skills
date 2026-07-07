Cancel an active CoW Swap TWAP order on a BittyVault on Ethereum mainnet.

**Usage:** `/cancel-twap <twap_id>`

- `<twap_id>` — the bytes32 TWAP ID returned by `/twap-sell` or `/twap-buy`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: first token is `<twap_id>`. If missing, stop and print usage.

---

## Hardcoded mainnet configuration

CoW Swap intent protocol (mainnet): `0x81C47B11bD6c1092b9341a4Db5001D1CdB487239`

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set}"
```

### 2. Show preview and ask for confirmation

```
⚠ Cancel CoW Swap TWAP — MAINNET
Vault            : $VAULT_ADDRESS
TWAP ID          : <twap_id>
Intent protocol  : 0x81C47B11bD6c1092b9341a4Db5001D1CdB487239
```

Ask: "Cancel this TWAP on MAINNET? (yes/no)" — if no, stop.

### 3. Call cancelTwap on the vault

```bash
cast send $VAULT_ADDRESS \
  "cancelTwap(address,bytes32)" \
  "0x81C47B11bD6c1092b9341a4Db5001D1CdB487239" \
  "<twap_id>" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

### 4. Show result

```
TWAP cancelled!
  Tx hash    : <tx_hash>
  Etherscan  : https://etherscan.io/tx/<tx_hash>
  TWAP ID    : <twap_id>

Future slots will not execute. Any remaining allowance is revoked.
```
