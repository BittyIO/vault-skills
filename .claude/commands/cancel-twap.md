Cancel an active CoW Swap TWAP order on a BittyVault on Sepolia. Returns any unfilled sell token allowance to the vault.

**Usage:** `/cancel-twap <twap_id>`

- `<twap_id>` — the bytes32 TWAP ID returned by `/twap-sell` or `/twap-buy`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: first token is `<twap_id>`. If missing, stop and print usage.

---

## Hardcoded Sepolia configuration

CoW Swap intent protocol (Sepolia): `0x034ef104B0c483EB71Ba2aD91a1de6224AdF4F70`

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set}"
```

### 2. Show preview and ask for confirmation

```
Cancel CoW Swap TWAP order
Vault            : $VAULT_ADDRESS
TWAP ID          : <twap_id>
Intent protocol  : 0x034ef104B0c483EB71Ba2aD91a1de6224AdF4F70
```

Ask: "Cancel this TWAP? (yes/no)" — if no, stop.

### 3. Call cancelTwap on the vault

```bash
cast send $VAULT_ADDRESS \
  "cancelTwap(address,bytes32)" \
  "0x034ef104B0c483EB71Ba2aD91a1de6224AdF4F70" \
  "<twap_id>" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 4. Show result

```
TWAP cancelled!
  Tx hash      : <tx_hash>
  Etherscan    : https://sepolia.etherscan.io/tx/<tx_hash>
  TWAP ID      : <twap_id>

Any remaining sell token allowance has been revoked. Future slots will not execute.
```
