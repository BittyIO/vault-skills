Deploy a new BittyVault on Ethereum mainnet via the factory at `0x00000000c0CbD44E9115D80A61745A4fbd7E2C9E`.

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
| Factory | `0x00000000c0CbD44E9115D80A61745A4fbd7E2C9E` |
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` |
| WBTC | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` |
| USDS | `0xdC035D45d973E3EC169d2276DDab16f1e407384F` |
| Lending protocol (Aave V3) | `0xAab4d99E2D040769765adF962A3581B4db4ad8c0` |
| Staking protocol (Lido V2) | `0xeB3f9d8ea1bB306526a1e3E979798F03D7dA47E2` |
| AMM protocol (UniswapV3) | `0xe3F9C4141E85C6B3E1C210a68d1A237E47327947` |
| Sky V1 protocol | `0xa025A56aABca6682fFfE4E0b7030F24f31a4b8f6` |

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
- Network: Ethereum mainnet
- Assets (non-stable): WETH, WBTC
- Stablecoins: USDC, USDT, USDS
- Lending protocols: Aave V3
- Staking protocols: Lido V2
- AMM protocols: UniswapV3
- Sky V1 protocol

⚠ **This is Ethereum mainnet — real funds will be used. Double-check all addresses.**

Ask: "Proceed with deployment? (yes/no)"

If the user says no, stop.

### 4. Deploy the vault

```bash
cast send 0x00000000c0CbD44E9115D80A61745A4fbd7E2C9E \
  "deployVault(address,string,address,address[],address[],address[],address[],address[])" \
  "<owner>" \
  "<vault_name>" \
  "<asset_manager>" \
  "[0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599]" \
  "[0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,0xdAC17F958D2ee523a2206206994597C13D831ec7,0xdC035D45d973E3EC169d2276DDab16f1e407384F]" \
  "[0xAab4d99E2D040769765adF962A3581B4db4ad8c0]" \
  "[0xeB3f9d8ea1bB306526a1e3E979798F03D7dA47E2]" \
  "[0xe3F9C4141E85C6B3E1C210a68d1A237E47327947]" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

If the transaction fails, print the revert reason and stop.

### 5. Compute and display the vault address

```bash
cast call 0x00000000c0CbD44E9115D80A61745A4fbd7E2C9E \
  "computeVaultAddress(address,string)(address)" \
  "<owner>" "<vault_name>" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
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
