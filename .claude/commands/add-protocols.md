Add protocols to a BittyVault on Sepolia. Owner-only operation (DEFAULT_ADMIN_ROLE).

**Usage:** `/add-protocols <type> <address1> [address2] ...`

- `<type>` — protocol type: `lending`, `staking`, or `amm`
- `<address>` — protocol contract address(es)

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: first token is `<type>`, remaining tokens are protocol addresses.
If `<type>` or at least one address is missing, stop and print: "Usage: /add-protocols <lending|staking|amm> <address1> [address2] ..."

---

## Hardcoded Sepolia configuration

| Protocol | Type | Address |
|----------|------|---------|
| Aave V3 | lending | `0xDF2d39981A4A72586a109b0A54331b0A07Fa3B44` |
| Lido V2 | staking | `0x7b38439Eb757E1eC3849b7C7033C7d67A733bbe1` |
| UniswapV3 | amm | `0x3Dc6038190092a4FA62c5203D00410f07d2221a4` |

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "OWNER_PRIVATE_KEY=${OWNER_PRIVATE_KEY:?OWNER_PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Check if adding protocols is disabled

```bash
cast call $VAULT_ADDRESS "isAddingProtocolsDisabled()(bool)" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

If `true`, stop and print:
```
Error: Adding protocols has been permanently disabled on this vault.
```

### 3. Validate protocol type

`<type>` must be one of: `lending`, `staking`, `amm` (case-insensitive).
If invalid, stop and print: "Error: Invalid protocol type '<type>'. Use: lending, staking, or amm"

### 4. Fetch current protocols of that type

Based on `<type>`, call the appropriate getter:

- `lending`: `cast call $VAULT_ADDRESS "getLendingProtocols()(address[])" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"`
- `staking`: `cast call $VAULT_ADDRESS "getStakingProtocols()(address[])" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"`
- `amm`: `cast call $VAULT_ADDRESS "getAMMProtocols()(address[])" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"`

### 5. Show preview and ask for confirmation

Print:
```
Vault              : $VAULT_ADDRESS
Protocol type      : <type>
Current protocols  : <current_list>
Adding             : [<addr1>, <addr2>, ...]
```

Ask: "Proceed with adding protocols? (yes/no)"
If no, stop.

### 6. Call the appropriate add function

Based on `<type>`:

- `lending`:
```bash
cast send $VAULT_ADDRESS \
  "addLendingProtocols(address[])" "[<addr1>,<addr2>,...]" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

- `staking`:
```bash
cast send $VAULT_ADDRESS \
  "addStakingProtocols(address[])" "[<addr1>,<addr2>,...]" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

- `amm`:
```bash
cast send $VAULT_ADDRESS \
  "addAMMProtocols(address[])" "[<addr1>,<addr2>,...]" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$OWNER_PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 7. Verify and show result

Re-fetch protocols using the same getter as step 4.

Print:
```
Protocols added!
  Tx hash            : <tx_hash>
  Etherscan          : https://sepolia.etherscan.io/tx/<tx_hash>
  Updated protocols  : <new_list>
```
