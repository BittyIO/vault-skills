Set the new-receiver protection duration on a BittyVault on Ethereum mainnet. Owner-only operation (DEFAULT_ADMIN_ROLE).

This sets a time-lock window: after a new receiver is added, payments to it are blocked until the protection period has elapsed. This gives the owner time to review and remove a malicious receiver before it can receive funds.

**Usage:** `/set-receiver-protection <duration_seconds>`

- `<duration_seconds>` — protection period in seconds (e.g. `86400` for 1 day, `604800` for 1 week). Use `0` to disable.

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as `<duration_seconds>`.
If empty, stop and print: "Usage: /set-receiver-protection <duration_seconds>"

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "OWNER_PRIVATE_KEY=${OWNER_PRIVATE_KEY:?OWNER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Show preview and ask for confirmation

Convert `<duration_seconds>` to a human-readable format (e.g. "1 day", "7 days", "1 hour").

Print:
```
This is Ethereum mainnet.

Vault                : $VAULT_ADDRESS
New protection period: <duration_seconds> seconds (<human_readable>)

New receivers will be unable to receive payments for this duration after being added.
Set to 0 to disable protection.
```

Ask: "Proceed with setting receiver protection? (yes/no)"
If no, stop.

### 3. Call setNewReceiverProtection

```bash
cast send $VAULT_ADDRESS \
  "setNewReceiverProtection(uint256)" \
  "<duration_seconds>" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 4. Show result

Print:
```
Receiver protection updated!
  Tx hash             : <tx_hash>
  Etherscan           : https://etherscan.io/tx/<tx_hash>
  Protection duration : <duration_seconds> seconds (<human_readable>)
```
