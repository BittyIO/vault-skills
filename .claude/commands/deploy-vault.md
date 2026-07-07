Deploy a new BittyVault on Sepolia via the factory at `0x000000005d581dBc2558d32D90E13FAb5d55daAE`.

**Usage:** `/deploy-vault <owner_address> [vault_name]`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as:
- First token → `<owner>` (an Ethereum address, required)
- Remaining tokens → `<vault_name>` (optional, may contain spaces; defaults to `""` if omitted)

If `<owner>` is missing, stop and tell the user: "Usage: /deploy-vault <owner_address> [vault_name]"

---

## Hardcoded Sepolia configuration

| Role | Address |
|------|---------|
| Factory | `0x000000005d581dBc2558d32D90E13FAb5d55daAE` |
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` |
| WETH_UNI | `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14` |
| WETH_AAVE | `0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c` |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` |
| Lending (Aave V3) | `0x472eDb79A83cC8470473Df20dD49a85E91769b98` |
| Staking (Lido V2) | `0x91F7682054cfE444A1E0e84F654010E2F7a69421` |
| AMM (Uniswap V3) | `0x68Edd39302545C2DFd3a8B25e36Da8059bacbD26` |
| Intent (CoW Swap V1) | `0xb1579963b9353B0a5E2efc26746C5aAf870dC048` |

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
- Protocols: all guard-registered (Aave V3, Lido V2, Uniswap V3, CoW Swap V1)
- Assets: all guard-registered (WETH, WETH_UNI, WETH_AAVE, WBTC, USDT, USDC)

Ask: "Proceed with deployment? (yes/no)"

If the user says no, stop.

### 4. Deploy the vault

```bash
cast send 0x000000005d581dBc2558d32D90E13FAb5d55daAE \
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
cast call 0x000000005d581dBc2558d32D90E13FAb5d55daAE \
  "computeVaultAddress(address,string)(address)" \
  "<owner>" "<vault_name>" \
  --rpc-url "<rpc_url>"
```

Save the output as `<vault_address>`.

### 6. Save vault address to .env

Update `.env` so all other skills can use it without repeating the address:

- If `VAULT_ADDRESS` already exists in `.env`, replace that line.
- Otherwise append `VAULT_ADDRESS=<vault_address>` to `.env`.

### 7. Print a deployment summary

Print:
- Transaction hash (from step 4)
- Vault address (from step 5)
- Sepolia Etherscan link: `https://sepolia.etherscan.io/address/<vault_address>`
- Owner: `<owner>`
- Asset manager: `<asset_manager>`
- VAULT_ADDRESS saved to `.env` ✓
