Grant the ASSET_MANAGER_ROLE to an address on a BittyVault on Ethereum mainnet. Owner-only operation (DEFAULT_ADMIN_ROLE).

The asset manager address cannot be the same as the owner address.

**Usage:** `/grant-role <address>`

- `<address>` — Ethereum address to grant the asset manager role to

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as `<address>`.
If empty, stop and print: "Usage: /grant-role <address>"

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "OWNER_PRIVATE_KEY=${OWNER_PRIVATE_KEY:?OWNER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Check if address already has the role

The ASSET_MANAGER_ROLE hash is `0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce` (keccak256 of "ASSET_MANAGER_ROLE").

```bash
cast call $VAULT_ADDRESS \
  "hasRole(bytes32,address)(bool)" \
  "0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce" \
  "<address>" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

If `true`, stop and print: "Address <address> already has ASSET_MANAGER_ROLE."

### 3. Show preview and ask for confirmation

Print:
```
This is Ethereum mainnet.

Vault           : $VAULT_ADDRESS
Granting role   : ASSET_MANAGER_ROLE
To address      : <address>

This address will be able to execute yield and trading operations on the vault.
```

Ask: "Proceed with granting role? (yes/no)"
If no, stop.

### 4. Call grantRole

```bash
cast send $VAULT_ADDRESS \
  "grantRole(bytes32,address)" \
  "0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce" \
  "<address>" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop. Common reasons:
- `OwnerAndAssetManagerMustDiffer()` — cannot grant asset manager role to the vault owner

### 5. Verify and show result

```bash
cast call $VAULT_ADDRESS \
  "hasRole(bytes32,address)(bool)" \
  "0x7613a25ecc738585a232ad50a301178f12b3ba8d3c8deb6a0dfa0418b2964fce" \
  "<address>" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
Role granted!
  Tx hash   : <tx_hash>
  Etherscan : https://etherscan.io/tx/<tx_hash>
  Address   : <address>
  Role      : ASSET_MANAGER_ROLE
```
