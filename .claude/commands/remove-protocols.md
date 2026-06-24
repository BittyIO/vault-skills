Remove protocols from a BittyVault on Sepolia. Owner-only operation (DEFAULT_ADMIN_ROLE).

**Usage:** `/remove-protocols <type> <address1> [address2] ...`

- `<type>` — protocol type: `lending`, `staking`, or `amm`
- `<address>` — protocol contract address(es) to remove

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: first token is `<type>`, remaining tokens are protocol addresses.
If `<type>` or at least one address is missing, stop and print: "Usage: /remove-protocols <lending|staking|amm> <address1> [address2] ..."

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "OWNER_PRIVATE_KEY=${OWNER_PRIVATE_KEY:?OWNER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Validate protocol type

`<type>` must be one of: `lending`, `staking`, `amm` (case-insensitive).
If invalid, stop and print: "Error: Invalid protocol type '<type>'. Use: lending, staking, or amm"

### 3. Fetch current protocols of that type

Based on `<type>`, call the appropriate getter:

- `lending`: `cast call $VAULT_ADDRESS "getLendingProtocols()(address[])" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"`
- `staking`: `cast call $VAULT_ADDRESS "getStakingProtocols()(address[])" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"`
- `amm`: `cast call $VAULT_ADDRESS "getAMMProtocols()(address[])" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"`

### 4. Show preview and ask for confirmation

Print:
```
Vault              : $VAULT_ADDRESS
Protocol type      : <type>
Current protocols  : <current_list>
Removing           : [<addr1>, <addr2>, ...]
```

Ask: "Proceed with removing protocols? (yes/no)"
If no, stop.

### 5. Call the appropriate remove function

Based on `<type>`:

- `lending`:
```bash
cast send $VAULT_ADDRESS \
  "removeLendingProtocols(address[])" "[<addr1>,<addr2>,...]" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

- `staking`:
```bash
cast send $VAULT_ADDRESS \
  "removeStakingProtocols(address[])" "[<addr1>,<addr2>,...]" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

- `amm`:
```bash
cast send $VAULT_ADDRESS \
  "removeAMMProtocols(address[])" "[<addr1>,<addr2>,...]" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 6. Verify and show result

Re-fetch protocols using the same getter as step 3.

Print:
```
Protocols removed!
  Tx hash              : <tx_hash>
  Etherscan            : https://sepolia.etherscan.io/tx/<tx_hash>
  Remaining protocols  : <updated_list>
```
