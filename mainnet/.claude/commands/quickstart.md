End-to-end setup that walks through the BittyVault deployment and basic operations on Ethereum mainnet:
generate asset manager → deploy vault → fund vault → supply → withdraw → stake → unstake → rebalance.

⚠ **This operates on Ethereum mainnet with real ETH and tokens. Proceed with caution.**

**Usage:** `/quickstart <owner_address> <vault_name>`

- `<owner_address>` — wallet that will own the vault (your hardware wallet / safe address)
- `<vault_name>` — name for the vault (e.g. `MyVault`)

Arguments: $ARGUMENTS

Parse first token as `<owner>`, second token as `<vault_name>`.
If `<owner>` or `<vault_name>` is missing, stop and print: "Usage: /quickstart <owner_address> <vault_name>"

---

## Hardcoded mainnet configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | 18 |
| WBTC | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` | 8 |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | 6 |
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` | 6 |
| USDS | `0xdC035D45d973E3EC169d2276DDab16f1e407384F` | 18 |

| Role | Address |
|------|---------|
| Factory | `0x00000086892600a65782e5E1F11dedE2Eac0cB6c` |
| Lending protocol (Aave V3) | `0x1ee9040bD2E2418a4CbC8754865D595920EF9301` |
| Staking protocol (Lido V2) | `0xcEecA8ba582180d014378AAFcaA5f324C77BE2A7` |
| AMM protocol (UniswapV3) | `0xcC07F93057755f0E655B8411ee55a1192E385684` |
| Sky V1 protocol | `0xb3fF9DF07F2901D97c07146d18093dE914141AD3` |

UniswapV3 NonfungiblePositionManager (mainnet): `0xC36442b4a4522E871399CD717aBDD847Ab11FE88`

---

## Steps

### 1. Check environment variables

```bash
```

Print the setup plan to the user:
```
⚠ BittyVault Mainnet Quickstart
================================
Owner        : <owner>
Vault name   : <vault_name>
Network      : Ethereum mainnet (REAL FUNDS)

Steps:
  1. Set up AI asset manager keypair
  2. Fund the asset manager with ETH
  3. Deploy vault
  4. Fund vault (wrap ETH → WETH and send to vault)
  5. Check vault balances

After setup, use the individual skills to manage your vault:
  /supply, /withdraw, /stake, /unstake, /rebalance,
  /add-liquidity, /remove-liquidity, /claim-fees, /vault-balances
```

Ask: "Ready to begin? (yes/no)"
If no, stop.

---

### Step 1 — Set up AI asset manager

Print: `[1/5] Setting up AI asset manager...`

Ask the user:
```
How would you like to set up the asset manager?
  [1] Generate a new keypair
  [2] Enter an existing private key
```

**If the user chose option 1 (Generate):**

```bash
cast wallet new
```

Parse the output and extract `<asset_manager_address>` and `<private_key>`.

**If the user chose option 2 (Enter existing):**

Ask the user to paste their private key. Accept it as `<private_key>`.

Derive the address:
```bash
cast wallet address --private-key "<private_key>"
```

Save the output as `<asset_manager_address>`.

**Then (both paths):**

Save to `.env` (replace existing `PRIVATE_KEY` if present, otherwise append):
```
PRIVATE_KEY=<private_key>
```

Print:
```
✓ Asset manager configured
  Address : <asset_manager_address>
  Key     : <first_6_chars>...<last_4_chars> (saved to .env)
```

---

### Step 2 — Fund the asset manager

Print:
```
[2/5] Fund the asset manager with ETH.

  Send ETH to this address from your wallet:
  <asset_manager_address>

  You need enough ETH to cover:
  - Gas for vault deployment (~0.01 ETH)
  - WETH to fund the vault (your chosen amount)
  - Gas for future transactions

  Enter "done" when the transfer has confirmed.
```

Wait for the user to enter done before proceeding.

Then check the asset manager ETH balance and print it:
```bash
cast balance <asset_manager_address> \
  --rpc-url "<rpc_url>"
```

Print: `✓ Balance confirmed: <balance> wei`

---

### Step 3 — Deploy vault

Print: `[3/5] Deploying vault...`

```bash
cast send 0x00000086892600a65782e5E1F11dedE2Eac0cB6c \
  "deployVaultAllSelected(address,string,address[])" \
  "<owner>" \
  "<vault_name>" \
  "[<asset_manager_address>]" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

Compute the vault address:
```bash
cast call 0x00000086892600a65782e5E1F11dedE2Eac0cB6c \
  "computeVaultAddress(address,string)(address)" \
  "<owner>" "<vault_name>" \
  --rpc-url "<rpc_url>"
```

Save as `<vault_address>`. Write `VAULT_ADDRESS=<vault_address>` to `.env`.

Print:
```
✓ Vault deployed
  Address  : <vault_address>
  Etherscan: https://etherscan.io/address/<vault_address>
```

---

### Step 4 — Fund the vault

Print: `[4/5] Funding vault — how much ETH would you like to wrap into WETH and send to the vault?`

Ask the user for the amount. Accept it as `<fund_amount>`.

Check asset manager ETH balance:
```bash
ASSET_MANAGER=$(cast wallet address --private-key "$PRIVATE_KEY")
cast balance "$ASSET_MANAGER" --rpc-url "<rpc_url>"
```

If balance < `<fund_amount>` ETH (in wei), stop and print:
```
Error: Asset manager has insufficient ETH to fund the vault.
  Balance  : <balance>
  Required : <fund_amount> ETH + gas
Please send ETH to <asset_manager_address> and retry.
```

Convert to wei: `AMOUNT_RAW=$(cast to-unit <fund_amount>ether wei)`

Wrap and transfer WETH to the vault:

```bash
cast send 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 "deposit()" --value "$AMOUNT_RAW" \
  --rpc-url "<rpc_url>" --private-key "$PRIVATE_KEY"
cast send 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 "transfer(address,uint256)" "$VAULT_ADDRESS" "$AMOUNT_RAW" \
  --rpc-url "<rpc_url>" --private-key "$PRIVATE_KEY"
```

Print:
```
✓ Vault funded
  WETH : <fund_amount> ETH wrapped and sent
```

---

### Step 5 — Check vault balances

Print: `[5/5] Checking vault balances...`

Fetch the asset and stablecoin lists and display balances (same as /vault-balances).

---

### Final summary

Print:

```
===========================================
  BittyVault Mainnet Setup Complete!
===========================================
  Vault         : <vault_address>
  Vault name    : <vault_name>
  Owner         : <owner>
  Asset manager : <asset_manager_address>
  Network       : Ethereum mainnet

  ✓ 1. Asset manager configured
  ✓ 2. Asset manager funded
  ✓ 3. Vault deployed
  ✓ 4. Vault funded with WETH
  ✓ 5. Balances verified

  Available skills:
    /vault-balances    — view all vault balances
    /supply            — supply to Aave
    /withdraw          — withdraw from Aave
    /stake             — stake in Lido
    /unstake           — request unstake from Lido
    /claim-unstaked    — claim finalized unstake
    /rebalance         — swap tokens via UniswapV3
    /add-liquidity     — add UniswapV3 liquidity
    /remove-liquidity  — remove UniswapV3 liquidity
    /claim-fees        — collect UniswapV3 fees
===========================================
```
