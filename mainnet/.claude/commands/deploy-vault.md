Deploy a new BittyVault on Ethereum mainnet via the factory at `0x000000000a8dC1844B9741Ba9FB6576410640Bfc`.

**Usage:** `/deploy-vault <owner_address> [vault_name]`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as:
- First token → `<owner>` (an Ethereum address, required)
- Remaining tokens → `<vault_name>` (optional, may contain spaces; defaults to `""` if omitted)

If `<owner>` is missing, stop and tell the user: "Usage: /deploy-vault <owner_address> [vault_name]"

---

## Hardcoded mainnet configuration

| Role | Address |
|------|---------|
| Factory | `0x000000000a8dC1844B9741Ba9FB6576410640Bfc` |
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` |
| WBTC | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` |
| USDS | `0xdC035D45d973E3EC169d2276DDab16f1e407384F` |
| Lending (Aave V3) | `0x66716637fF73C14C6536E494099D4a8Ea0e71206` |
| Staking (Lido V2) | `0x68ED00Bd31E64ae77c19F9712dd1B27d4AA083b9` |
| AMM (Uniswap V3) | `0x581ea6f54F14AC823f9541f761483263e8CfeB4a` |
| Sky V1 | `0x26E671D35FCdC095E72Ebe40a3051bf4b90a56F7` |

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
- Network: Ethereum mainnet
- Protocols: all guard-registered (Aave V3, Lido V2, Uniswap V3, Sky V1)
- Assets: all guard-registered (WETH, WBTC, USDC, USDT, USDS)

⚠ **This is Ethereum mainnet — real funds will be used. Double-check all addresses.**

Ask: "Proceed with deployment? (yes/no)"

If the user says no, stop.

### 4. Deploy the vault

```bash
cast send 0x000000000a8dC1844B9741Ba9FB6576410640Bfc \
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
cast call 0x000000000a8dC1844B9741Ba9FB6576410640Bfc \
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
- Etherscan link: `https://etherscan.io/address/<vault_address>`
- Owner: `<owner>`
- Asset manager: `<asset_manager>`
- VAULT_ADDRESS saved to `.env` ✓
