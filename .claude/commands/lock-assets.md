Permanently disable adding new assets to a BittyVault on Sepolia. Owner-only operation (DEFAULT_ADMIN_ROLE).

**This is IRREVERSIBLE.** After locking, no new assets can be added. Existing assets can still be removed.

**Usage:** `/lock-assets`

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
cast call $VAULT_ADDRESS "isAddingAssetsDisabled()(bool)" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

If `true`, stop and print: "Adding assets is already disabled on this vault."

### 3. Fetch current assets

```bash
cast call $VAULT_ADDRESS "getAssets()(address[])" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call $VAULT_ADDRESS "getStableCoins()(address[])" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

### 4. Show warning and ask for confirmation

Print:
```
WARNING: This action is IRREVERSIBLE.

Vault          : $VAULT_ADDRESS
Current assets : <asset_list>

After locking:
  - No new assets can ever be added to this vault
  - Existing assets can still be removed
  - The asset manager can only trade assets currently in the vault
```

Ask: "Type 'LOCK' to confirm, or anything else to cancel:"
If the user does not type exactly `LOCK`, stop.

### 5. Call disableAddingAssets

```bash
cast send $VAULT_ADDRESS \
  "disableAddingAssets()" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 6. Verify and show result

```bash
cast call $VAULT_ADDRESS "isAddingAssetsDisabled()(bool)" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
Assets locked!
  Tx hash   : <tx_hash>
  Etherscan : https://sepolia.etherscan.io/tx/<tx_hash>
  Adding assets is now permanently disabled.
```
