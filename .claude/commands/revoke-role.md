Revoke the ASSET_MANAGER_ROLE from an address on a BittyVault on Sepolia. Owner-only operation (DEFAULT_ADMIN_ROLE).

**Usage:** `/revoke-role <address>`

- `<address>` — Ethereum address to revoke the asset manager role from

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as `<address>`.
If empty, stop and print: "Usage: /revoke-role <address>"

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "OWNER_PRIVATE_KEY=${OWNER_PRIVATE_KEY:?OWNER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Check if address has the role

The ASSET_MANAGER_ROLE hash is `0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce` (keccak256 of "ASSET_MANAGER_ROLE").

```bash
cast call $VAULT_ADDRESS \
  "hasRole(bytes32,address)(bool)" \
  "0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce" \
  "<address>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

If `false`, stop and print: "Address <address> does not have ASSET_MANAGER_ROLE."

### 3. Show preview and ask for confirmation

Print:
```
Vault           : $VAULT_ADDRESS
Revoking role   : ASSET_MANAGER_ROLE
From address    : <address>

This address will no longer be able to execute any operations on the vault.
```

Ask: "Proceed with revoking role? (yes/no)"
If no, stop.

### 4. Call revokeRole

```bash
cast send $VAULT_ADDRESS \
  "revokeRole(bytes32,address)" \
  "0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce" \
  "<address>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 5. Verify and show result

```bash
cast call $VAULT_ADDRESS \
  "hasRole(bytes32,address)(bool)" \
  "0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce" \
  "<address>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
Role revoked!
  Tx hash   : <tx_hash>
  Etherscan : https://sepolia.etherscan.io/tx/<tx_hash>
  Address   : <address>
  Role      : ASSET_MANAGER_ROLE (removed)
```
