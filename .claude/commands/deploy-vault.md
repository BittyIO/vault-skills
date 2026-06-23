Deploy a new BittyVault on Sepolia via the factory at `0x00000000c0CbD44E9115D80A61745A4fbd7E2C9E`.

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
| Factory | `0x00000000c0CbD44E9115D80A61745A4fbd7E2C9E` |
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` |
| WETH_UNI | `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14` |
| WETH_AAVE | `0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c` |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` |
| Lending protocol | `0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436` |
| Staking protocol | `0x2Db440cF6215d68d44736A287B253F4461399aa0` |
| AMM protocol | `0x4f0016270Cc88E18CdC1fA7B7c8b4D1ffde7Ad0E` |

---

## Steps

### 1. Check environment variables

Run the following and stop with a clear error if any are missing or empty:
```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
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
- Assets (non-stable): WETH, WETH_UNI, WETH_AAVE, WBTC
- Stablecoins: USDT, USDC
- Lending protocols: 1
- Staking protocols: 1
- AMM protocols: 1

Ask: "Proceed with deployment? (yes/no)"

If the user says no, stop.

### 4. Deploy the vault

```bash
cast send 0x00000000c0CbD44E9115D80A61745A4fbd7E2C9E \
  "deployVault(address,string,address,address[],address[],address[],address[],address[])" \
  "<owner>" \
  "<vault_name>" \
  "<asset_manager>" \
  "[0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c,0x29f2D40B0605204364af54EC677bD022dA425d03]" \
  "[0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0,0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8]" \
  "[0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436]" \
  "[0x2Db440cF6215d68d44736A287B253F4461399aa0]" \
  "[0x4f0016270Cc88E18CdC1fA7B7c8b4D1ffde7Ad0E]" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

If the transaction fails, print the revert reason and stop.

### 5. Compute and display the vault address

```bash
cast call 0x00000000c0CbD44E9115D80A61745A4fbd7E2C9E \
  "computeVaultAddress(address,string)(address)" \
  "<owner>" "<vault_name>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
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
