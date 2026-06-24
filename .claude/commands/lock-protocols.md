Permanently disable adding new protocols to a BittyVault on Sepolia. Owner-only operation (DEFAULT_ADMIN_ROLE).

**This is IRREVERSIBLE.** After locking, no new protocols can be added. Existing protocols can still be removed.

**Usage:** `/lock-protocols`

No arguments needed.

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "OWNER_PRIVATE_KEY=${OWNER_PRIVATE_KEY:?OWNER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Check if already disabled

```bash
cast call $VAULT_ADDRESS "isAddingProtocolsDisabled()(bool)" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

If `true`, stop and print: "Adding protocols is already disabled on this vault."

### 3. Fetch current protocols

```bash
cast call $VAULT_ADDRESS "getLendingProtocols()(address[])" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call $VAULT_ADDRESS "getStakingProtocols()(address[])" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call $VAULT_ADDRESS "getAMMProtocols()(address[])" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

### 4. Show warning and ask for confirmation

Print:
```
WARNING: This action is IRREVERSIBLE.

Vault               : $VAULT_ADDRESS
Lending protocols   : <lending_list>
Staking protocols   : <staking_list>
AMM protocols       : <amm_list>

After locking:
  - No new protocols can ever be added to this vault
  - Existing protocols can still be removed
  - The asset manager can only interact with currently registered protocols
```

Ask: "Type 'LOCK' to confirm, or anything else to cancel:"
If the user does not type exactly `LOCK`, stop.

### 5. Call disableAddingProtocols

```bash
cast send $VAULT_ADDRESS \
  "disableAddingProtocols()" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 6. Verify and show result

```bash
cast call $VAULT_ADDRESS "isAddingProtocolsDisabled()(bool)" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
Protocols locked!
  Tx hash   : <tx_hash>
  Etherscan : https://sepolia.etherscan.io/tx/<tx_hash>
  Adding protocols is now permanently disabled.
```
