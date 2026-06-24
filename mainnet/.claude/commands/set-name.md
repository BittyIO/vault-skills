Set the name of a BittyVault on Ethereum mainnet. Owner-only operation (DEFAULT_ADMIN_ROLE).

**Usage:** `/set-name <new_name>`

- `<new_name>` — the new name for the vault (may contain spaces)

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as `<new_name>` (the entire string).
If empty, stop and print: "Usage: /set-name <new_name>"

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "OWNER_PRIVATE_KEY=${OWNER_PRIVATE_KEY:?OWNER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Fetch the current vault name

```bash
cast call $VAULT_ADDRESS "name()(string)" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Save as `<current_name>`.

### 3. Show preview and ask for confirmation

Print:
```
This is Ethereum mainnet.

Vault        : $VAULT_ADDRESS
Current name : <current_name>
New name     : <new_name>
```

Ask: "Proceed with renaming? (yes/no)"
If no, stop.

### 4. Call setName on the vault

```bash
cast send $VAULT_ADDRESS \
  "setName(string)" \
  "<new_name>" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 5. Verify and show result

```bash
cast call $VAULT_ADDRESS "name()(string)" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
Name updated!
  Tx hash    : <tx_hash>
  Etherscan  : https://etherscan.io/tx/<tx_hash>
  Old name   : <current_name>
  New name   : <verified_name>
```
