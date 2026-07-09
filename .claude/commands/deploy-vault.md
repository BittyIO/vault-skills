Deploy a new BittyVault on Sepolia via the factory at `0x000000007B06f7C74A9c25a6E98dA37806f4DBA3`.

**Usage:** `/deploy-vault <owner_address> [vault_name]`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as:
- First token → `<owner>` (an Ethereum address, required)
- Remaining tokens → `<vault_name>` (optional, may contain spaces; defaults to `""` if omitted)

If `<owner>` is missing, stop and tell the user: "Usage: /deploy-vault <owner_address> [vault_name]"

---

## Sepolia configuration

| Role | Address |
|------|---------|
| Factory | `0x000000007B06f7C74A9c25a6E98dA37806f4DBA3` |

The vault is created with **all assets and protocols currently registered in the guard**, via `deployVaultAllSelected` — the factory resolves that set on-chain at deploy time, so no asset/protocol addresses are hardcoded here. Step 6 reads the resulting set back from the deployed vault.

---

## Steps

### 1. Check environment variables

Run the following and stop with a clear error if any are missing or empty:
```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}"
```

### 2. Derive the asset manager address from the AI agent's private key

```bash
cast wallet address --private-key "$PRIVATE_KEY"
```

Save the output as `<asset_manager>`. Print it so the user can confirm it looks correct before proceeding.

### 3. Preview the deployment and ask for confirmation

Show the user a summary table:
- Owner: `<owner>`
- Vault name: `<vault_name>`
- Asset manager: `<asset_manager>`
- Network: Sepolia
- Assets & protocols: all currently registered in the guard (resolved on-chain by the factory at deploy time)

Ask: "Proceed with deployment? (yes/no)"

If the user says no, stop.

### 4. Deploy the vault

```bash
cast send 0x000000007B06f7C74A9c25a6E98dA37806f4DBA3 \
  "deployVaultAllSelected(address,string,address[])" \
  "<owner>" \
  "<vault_name>" \
  "[<asset_manager>]" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction fails, print the revert reason and stop.

### 5. Compute and display the vault address

```bash
cast call 0x000000007B06f7C74A9c25a6E98dA37806f4DBA3 \
  "computeVaultAddress(address,string)(address)" \
  "<owner>" "<vault_name>" \
  --rpc-url "<rpc_url>"
```

Save the output as `<vault_address>`.

### 6. Read the registered assets and protocols from the new vault

Confirm what the factory actually registered — read on-chain from the vault, not hardcoded:

```bash
cast call <vault_address> "getAssets()(address[])" --rpc-url "<rpc_url>"
cast call <vault_address> "getStableCoins()(address[])" --rpc-url "<rpc_url>"
cast call <vault_address> "getLendingProtocols()(address[])" --rpc-url "<rpc_url>"
cast call <vault_address> "getStakingProtocols()(address[])" --rpc-url "<rpc_url>"
cast call <vault_address> "getAMMProtocols()(address[])" --rpc-url "<rpc_url>"
cast call <vault_address> "getIntentProtocols()(address[])" --rpc-url "<rpc_url>"
```

### 7. Save vault address to .env

Update `.env` so all other skills can use it without repeating the address:

- If `VAULT_ADDRESS` already exists in `.env`, replace that line.
- Otherwise append `VAULT_ADDRESS=<vault_address>` to `.env`.

### 8. Print a deployment summary

Print:
- Transaction hash (from step 4)
- Vault address (from step 5)
- Sepolia Etherscan link: `https://sepolia.etherscan.io/address/<vault_address>`
- Owner: `<owner>`
- Asset manager: `<asset_manager>`
- Registered assets & protocols (from step 6)
- VAULT_ADDRESS saved to `.env` ✓
