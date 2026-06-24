Remove a payment receiver from a BittyVault on Sepolia. Owner-only operation (DEFAULT_ADMIN_ROLE).

Cannot remove receivers marked as immutable.

**Usage:** `/remove-receiver <name>`

- `<name>` — name of the receiver to remove

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as `<name>`.
If empty, stop and print: "Usage: /remove-receiver <name>"

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
Vault    : $VAULT_ADDRESS
Removing : receiver "<name>"
```

Ask: "Proceed with removing this receiver? (yes/no)"
If no, stop.

### 3. Call removeReceiver on the vault

```bash
cast send $VAULT_ADDRESS \
  "removeReceiver(string)" \
  "<name>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop. Common reasons:
- `ReceiverNotFound()` — no receiver with that name exists
- `ReceiverImmutable()` — the receiver was created as immutable and cannot be removed

### 4. Show result

Print:
```
Receiver removed!
  Tx hash   : <tx_hash>
  Etherscan : https://sepolia.etherscan.io/tx/<tx_hash>
  Removed   : "<name>"
```
