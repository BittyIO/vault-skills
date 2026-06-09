End-to-end demo that walks through the full BittyVault lifecycle on Sepolia:
generate asset manager → deploy vault → fund vault → swap → supply → withdraw → stake → unstake.

**Usage:** `/quickstart <owner_address> <vault_name> [demo_amount]`

- `<owner_address>` — wallet that will own the vault (your hardware wallet / safe address)
- `<vault_name>` — name for the vault (e.g. `MyVault`)
- `[demo_amount]` — WETH amount to use for each operation (default: `0.01`)

Arguments: $ARGUMENTS

Parse first token as `<owner>`, second token as `<vault_name>`, third optional token as `<demo_amount>` (default `0.01`).
If `<owner>` or `<vault_name>` is missing, stop and print: "Usage: /quickstart <owner_address> <vault_name> [demo_amount]"

---

## Hardcoded Sepolia configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` | 6 |

| Role | Address |
|------|---------|
| Factory | `0x000000007aBb59ca6E74308f1860557eDe1A285d` |
| Lending protocol | `0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436` |
| Staking protocol | `0x2Db440cF6215d68d44736A287B253F4461399aa0` |
| AMM protocol | `0x642810409Aa6b2854777bf321adfb8B131cD91D0` |

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}"
```

Print the demo plan to the user:
```
BittyVault Quickstart
=====================
Owner        : <owner>
Vault name   : <vault_name>
Demo amount  : <demo_amount> WETH per operation
Network      : Sepolia

Steps:
  1.  Generate AI asset manager keypair
  2.  Get Sepolia ETH from Google faucet
  3.  Deploy vault
  4.  Fund vault (wrap ETH → WETH, WETH_UNI, WETH_AAVE and send to vault)
  5.  Swap <demo_amount> WETH → USDC
  6.  Swap USDC → WETH
  7.  Supply WETH_AAVE to Aave
  8.  Withdraw WETH_AAVE from Aave
  9.  Stake <demo_amount> WETH in Lido
  10. Request unstake from Lido
  11. Claim unstaked WETH (polls until Lido finalizes)
```

Ask: "Ready to begin? (yes/no)"
If no, stop.

Then ask:
```
How would you like to run each step?
  [1] Auto   — I'll run every command for you
  [2] Manual — Show me each command; I'll run it myself and tell you when done
```

Save the answer as `<mode>` (`auto` or `manual`).

---

## Execution rule — applied to EVERY step below

Before running any `cast send` transaction in a step:

**If `<mode>` is `auto`:** run the command directly.

**If `<mode>` is `manual`:**
1. Print the exact command the user needs to run, substituting all variable values so it is copy-pasteable.
2. Print: `Run the command above in your terminal, then reply "done" (or "skip" to skip this step).`
3. Wait for the user's reply before continuing.
   - `done` → proceed (run any follow-up read-only verification commands yourself).
   - `skip` → note "⏭ Step skipped" in the final summary and move to the next step.

Read-only `cast call` commands (balance checks, etc.) are always run by Claude regardless of mode.

After every `cast send` (whether run by Claude or reported as done by the user), print the Etherscan link:
```
  Etherscan: https://sepolia.etherscan.io/tx/<transactionHash>
```
In auto mode, parse `transactionHash` from the `cast send` output. In manual mode, ask: `Paste the transaction hash (or press Enter to skip):` and use whatever the user provides.

---

### Step 1 — Generate AI asset manager

Print: `[1/11] Generating AI asset manager keypair...`

Generate a new keypair:
```bash
cast wallet new
```

Parse the output and extract `<asset_manager_address>` and `<private_key>`.

Save to `.env` (replace existing `PRIVATE_KEY` if present, otherwise append):
```
PRIVATE_KEY=<private_key>
```

Print:
```
✓ Asset manager generated
  Address : <asset_manager_address>
  Key     : <first_6_chars>...<last_4_chars> (saved to .env)
```

---

### Step 2 — Get Sepolia ETH from faucet

Print:
```
[2/11] Fund the asset manager with Sepolia ETH.

  Open the Google Sepolia faucet in your browser:
  https://cloud.google.com/application/web3/faucet/ethereum/sepolia

  Paste this address into the faucet form:
  <asset_manager_address>

  The faucet sends 0.05 ETH — enough to cover the full quickstart.
  Wait for the transaction to confirm, then enter done to continue.
```

Wait for the user to enter done before proceeding.

Then check the asset manager ETH balance and print it:
```bash
cast balance <asset_manager_address> \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print: `✓ Balance confirmed: <balance> wei`

---

### Step 3 — Deploy vault

Print: `[3/11] Deploying vault...`

```bash
cast send 0x000000007aBb59ca6E74308f1860557eDe1A285d \
  "deployVault(address,string,address,address[],address[],address[],address[],address[])" \
  "<owner>" \
  "<vault_name>" \
  "<asset_manager_address>" \
  "[0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c,0x29f2D40B0605204364af54EC677bD022dA425d03]" \
  "[0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0,0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8]" \
  "[0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436]" \
  "[0x2Db440cF6215d68d44736A287B253F4461399aa0]" \
  "[0x642810409Aa6b2854777bf321adfb8B131cD91D0]" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

Compute the vault address:
```bash
cast call 0x000000007aBb59ca6E74308f1860557eDe1A285d \
  "computeVaultAddress(address,string)(address)" \
  "<owner>" "<vault_name>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Save as `<vault_address>`. Write `VAULT_ADDRESS=<vault_address>` to `.env`.

Print:
```
✓ Vault deployed
  Address  : <vault_address>
  Etherscan: https://sepolia.etherscan.io/address/<vault_address>
```

---

### Step 4 — Fund the vault

Print: `[4/11] Funding vault — wrapping ETH into WETH, WETH_UNI, WETH_AAVE...`

Check asset manager ETH balance:
```bash
ASSET_MANAGER=$(cast wallet address --private-key "$PRIVATE_KEY")
cast balance "$ASSET_MANAGER" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

If balance < `<demo_amount * 3>` ETH (in wei), stop and print:
```
Error: Asset manager has insufficient ETH to fund the vault.
  Balance  : <balance>
  Required : <demo_amount * 3> ETH + gas
Please send ETH to <asset_manager_address> and retry.
```

Convert `<demo_amount>` to wei: `AMOUNT_RAW=$(cast to-unit <demo_amount>ether wei)`

Wrap and transfer each token to the vault:

```bash
# WETH
cast send 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 "deposit()" --value "$AMOUNT_RAW" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" --private-key "$PRIVATE_KEY"
cast send 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 "transfer(address,uint256)" "$VAULT_ADDRESS" "$AMOUNT_RAW" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" --private-key "$PRIVATE_KEY"

# WETH_UNI
cast send 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14 "deposit()" --value "$AMOUNT_RAW" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" --private-key "$PRIVATE_KEY"
cast send 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14 "transfer(address,uint256)" "$VAULT_ADDRESS" "$AMOUNT_RAW" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" --private-key "$PRIVATE_KEY"

# WETH_AAVE
cast send 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c "deposit()" --value "$AMOUNT_RAW" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" --private-key "$PRIVATE_KEY"
cast send 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c "transfer(address,uint256)" "$VAULT_ADDRESS" "$AMOUNT_RAW" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" --private-key "$PRIVATE_KEY"
```

Print:
```
✓ Vault funded
  WETH      : <demo_amount> ETH wrapped and sent
  WETH_UNI  : <demo_amount> ETH wrapped and sent
  WETH_AAVE : <demo_amount> ETH wrapped and sent
```

---

### Step 5 — Swap WETH → USDC

Print: `[5/11] Swapping <demo_amount> WETH → USDC...`

Convert `<demo_amount>` to wei:
```bash
WETH_RAW=$(cast to-unit <demo_amount>ether wei)
```

Capture balances before:
```bash
WETH_BEFORE=$(cast call 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 "balanceOf(address)(uint256)" <vault_address> --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
USDC_BEFORE=$(cast call 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8 "balanceOf(address)(uint256)" <vault_address> --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
```

Build UniswapV3 path (WETH → USDC, fee 3000):
```bash
WETH_NO_0X="7b79995e5f793A07Bc00c21412e50Ecae098E7f9"
USDC_NO_0X="94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8"
PATH_HEX="0x${WETH_NO_0X}000BB8${USDC_NO_0X}"
```

Encode data (use `1` for buyAmountMin — the vault reverts on `0`):
```bash
DATA=$(cast abi-encode \
  "f(address,uint256,address,uint256,bytes)" \
  "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9" \
  "$WETH_RAW" \
  "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8" \
  "1" \
  "$PATH_HEX")
```

Execute:
```bash
cast send <vault_address> \
  "rebalance(address,address,address,uint256,uint256,bytes)" \
  "0x642810409Aa6b2854777bf321adfb8B131cD91D0" \
  "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9" \
  "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8" \
  "$WETH_RAW" "1" "$DATA" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

Capture balances after and save `<usdc_balance>`:
```bash
WETH_AFTER=$(cast call 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 "balanceOf(address)(uint256)" <vault_address> --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
USDC_AFTER=$(cast call 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8 "balanceOf(address)(uint256)" <vault_address> --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
```

Print:
```
✓ Swapped WETH → USDC
  Token      Before (raw)         After (raw)
  WETH       <WETH_BEFORE>        <WETH_AFTER>
  USDC       <USDC_BEFORE>        <USDC_AFTER>
```

---

### Step 6 — Swap USDC → WETH

Print: `[6/11] Swapping USDC → WETH...`

Use the full `USDC_AFTER` from step 4 as `<usdc_balance>`. Capture balances before:
```bash
WETH_BEFORE=$WETH_AFTER
USDC_BEFORE=$USDC_AFTER
```

Build the reverse path (USDC → WETH, fee 3000):
```bash
PATH_HEX="0x${USDC_NO_0X}000BB8${WETH_NO_0X}"

DATA=$(cast abi-encode \
  "f(address,uint256,address,uint256,bytes)" \
  "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8" \
  "$USDC_BEFORE" \
  "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9" \
  "1" \
  "$PATH_HEX")
```

Execute:
```bash
cast send <vault_address> \
  "rebalance(address,address,address,uint256,uint256,bytes)" \
  "0x642810409Aa6b2854777bf321adfb8B131cD91D0" \
  "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8" \
  "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9" \
  "$USDC_BEFORE" "1" "$DATA" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

Capture balances after:
```bash
WETH_AFTER=$(cast call 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 "balanceOf(address)(uint256)" <vault_address> --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
USDC_AFTER=$(cast call 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8 "balanceOf(address)(uint256)" <vault_address> --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
```

Print:
```
✓ Swapped USDC → WETH
  Token      Before (raw)         After (raw)
  WETH       <WETH_BEFORE>        <WETH_AFTER>
  USDC       <USDC_BEFORE>        <USDC_AFTER>
```

---

### Step 7 — Supply WETH_AAVE to Aave

Print: `[7/11] Supplying WETH_AAVE to Aave...`

Note: USDC is frozen on Aave Sepolia (error 51). Use WETH_AAVE (`0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c`) instead.

Capture balances before:
```bash
WETH_AAVE_WALLET_BEFORE=$(cast call 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c "balanceOf(address)(uint256)" <vault_address> --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
WETH_AAVE_SUPPLIED_BEFORE=$(cast call <vault_address> "getSuppliedBalance(address,address)(uint256)" "0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436" "0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
```

Supply `<demo_amount>` WETH_AAVE:
```bash
SUPPLY_AMT=$(cast to-unit <demo_amount>ether wei)
cast send <vault_address> \
  "supply(address,address,uint256)" \
  "0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436" \
  "0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c" \
  "$SUPPLY_AMT" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

Capture balances after:
```bash
WETH_AAVE_WALLET_AFTER=$(cast call 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c "balanceOf(address)(uint256)" <vault_address> --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
WETH_AAVE_SUPPLIED_AFTER=$(cast call <vault_address> "getSuppliedBalance(address,address)(uint256)" "0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436" "0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
```

Print:
```
✓ Supplied WETH_AAVE to Aave
  Token                  Before (raw)         After (raw)
  WETH_AAVE (wallet)     <WETH_AAVE_WALLET_BEFORE>   <WETH_AAVE_WALLET_AFTER>
  WETH_AAVE (Aave)       <WETH_AAVE_SUPPLIED_BEFORE> <WETH_AAVE_SUPPLIED_AFTER>
```

---

### Step 8 — Withdraw WETH_AAVE from Aave

Print: `[8/11] Withdrawing WETH_AAVE from Aave...`

Reuse `WETH_AAVE_WALLET_AFTER` and `WETH_AAVE_SUPPLIED_AFTER` from step 6 as the before values:
```bash
WETH_AAVE_WALLET_BEFORE=$WETH_AAVE_WALLET_AFTER
WETH_AAVE_SUPPLIED_BEFORE=$WETH_AAVE_SUPPLIED_AFTER
```

Withdraw it all:
```bash
SUPPLIED=$(cast call <vault_address> \
  "getSuppliedBalance(address,address)(uint256)" \
  "0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436" \
  "0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')

cast send <vault_address> \
  "withdraw(address,address,uint256)" \
  "0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436" \
  "0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c" \
  "$SUPPLIED" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

Capture balances after:
```bash
WETH_AAVE_WALLET_AFTER=$(cast call 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c "balanceOf(address)(uint256)" <vault_address> --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
WETH_AAVE_SUPPLIED_AFTER=$(cast call <vault_address> "getSuppliedBalance(address,address)(uint256)" "0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436" "0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
```

Print:
```
✓ Withdrawn WETH_AAVE from Aave
  Token                  Before (raw)         After (raw)
  WETH_AAVE (wallet)     <WETH_AAVE_WALLET_BEFORE>   <WETH_AAVE_WALLET_AFTER>
  WETH_AAVE (Aave)       <WETH_AAVE_SUPPLIED_BEFORE> <WETH_AAVE_SUPPLIED_AFTER>
```

---

### Step 9 — Stake WETH in Lido

Print: `[9/11] Staking <demo_amount> WETH in Lido...`

Capture balances before:
```bash
WETH_BEFORE=$(cast call 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 "balanceOf(address)(uint256)" <vault_address> --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
LIDO_STAKED_BEFORE=$(cast call <vault_address> "getStakedBalance(address,address)(uint256)" "0x2Db440cF6215d68d44736A287B253F4461399aa0" "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
```

```bash
cast send <vault_address> \
  "stake(address,address,uint256)" \
  "0x2Db440cF6215d68d44736A287B253F4461399aa0" \
  "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9" \
  "$WETH_RAW" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

Capture balances after:
```bash
WETH_AFTER=$(cast call 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 "balanceOf(address)(uint256)" <vault_address> --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
LIDO_STAKED_AFTER=$(cast call <vault_address> "getStakedBalance(address,address)(uint256)" "0x2Db440cF6215d68d44736A287B253F4461399aa0" "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
```

Print:
```
✓ Staked WETH in Lido
  Token              Before (raw)    After (raw)
  WETH (wallet)      <WETH_BEFORE>   <WETH_AFTER>
  WETH (Lido stake)  <LIDO_STAKED_BEFORE>  <LIDO_STAKED_AFTER>
```

---

### Step 10 — Request unstake from Lido

Print: `[10/11] Requesting unstake from Lido...`

First check if the Lido withdrawal queue is paused (known Sepolia limitation):
```bash
UNSTETH=0x1583C7b3f4C3B008720E6BcE5726336b0aB25fdd
IS_PAUSED=$(cast call $UNSTETH "isPaused()(bool)" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY")
```

If `IS_PAUSED` is `true`, skip this step and step 10. Print:
```
⚠ Skipped — Lido withdrawal queue is paused on Sepolia.
  Stake is held in stETH inside the vault's Lido protocol clone.
  Run /unstake and /claim-unstaked when Lido Sepolia is operational.
```

Otherwise fetch staked balance and unstake:
```bash
WETH_BEFORE=$WETH_AFTER
LIDO_STAKED_BEFORE=$LIDO_STAKED_AFTER

STAKED=$(cast call <vault_address> \
  "getStakedBalance(address,address)(uint256)" \
  "0x2Db440cF6215d68d44736A287B253F4461399aa0" \
  "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')

cast send <vault_address> \
  "unstake(address,address,uint256)" \
  "0x2Db440cF6215d68d44736A287B253F4461399aa0" \
  "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9" \
  "$STAKED" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

Capture balances after and fetch pending request IDs:
```bash
WETH_AFTER=$(cast call 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 "balanceOf(address)(uint256)" <vault_address> --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
LIDO_STAKED_AFTER=$(cast call <vault_address> "getStakedBalance(address,address)(uint256)" "0x2Db440cF6215d68d44736A287B253F4461399aa0" "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')

cast call <vault_address> \
  "getUnstakeRequestIds(address)(uint256[])" \
  "0x2Db440cF6215d68d44736A287B253F4461399aa0" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
✓ Unstake requested — pending IDs: <request_ids>
  Token              Before (raw)         After (raw)
  WETH (wallet)      <WETH_BEFORE>        <WETH_AFTER>
  WETH (Lido stake)  <LIDO_STAKED_BEFORE> <LIDO_STAKED_AFTER>
```

---

### Step 11 — Claim unstaked WETH from Lido

If step 10 was skipped (withdrawal queue paused), also skip step 11 and go to the final summary.

Print:
```
[11/11] Waiting for Lido withdrawal to finalize...
(This can take minutes to hours on Sepolia — polling every 30 seconds)
```

Format the request IDs as a Solidity array: `[id1,id2,...]`.

Poll by attempting a dry-run simulation every 30 seconds until it succeeds or 60 attempts (30 min) have elapsed:

```bash
cast call <vault_address> \
  "claimUnstaked(address,uint256[])" \
  "0x2Db440cF6215d68d44736A287B253F4461399aa0" \
  "<request_ids_array>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --from "$(cast wallet address --private-key $PRIVATE_KEY)"
```

- If the simulation succeeds (no revert), proceed to claim.
- If it still reverts after 60 attempts, skip the claim, note it in the summary, and tell the user to run `/claim-unstaked` manually later.

Once simulation passes, capture WETH before and execute the claim:
```bash
WETH_BEFORE=$WETH_AFTER

cast send <vault_address> \
  "claimUnstaked(address,uint256[])" \
  "0x2Db440cF6215d68d44736A287B253F4461399aa0" \
  "<request_ids_array>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

Capture WETH after:
```bash
WETH_AFTER=$(cast call 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 "balanceOf(address)(uint256)" <vault_address> --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" | awk '{print $1}')
```

Print:
```
✓ Claimed unstaked WETH
  Token         Before (raw)    After (raw)
  WETH (wallet) <WETH_BEFORE>   <WETH_AFTER>
```

---

### Final summary

Print:

```
===========================================
  BittyVault Quickstart Complete!
===========================================
  Vault         : <vault_address>
  Vault name    : <vault_name>
  Owner         : <owner>
  Asset manager : <asset_manager_address>

  ✓  1. Asset manager generated
  ✓  2. Sepolia ETH received from faucet
  ✓  3. Vault deployed
  ✓  4. Vault funded (WETH + WETH_UNI + WETH_AAVE)
  ✓  5. Swapped WETH → USDC
  ✓  6. Swapped USDC → WETH
  ✓  7. Supplied WETH_AAVE to Aave
  ✓  8. Withdrew WETH_AAVE from Aave
  ✓  9. Staked WETH in Lido
  ✓ 10. Unstake requested from Lido  (or "⚠ Skipped — Lido withdrawal queue paused on Sepolia")
  ✓ 11. Claimed unstaked WETH        (or "⚠ Skipped" / "⏳ Pending — run /claim-unstaked later")

  Run /vault-balances to see the current vault state.
===========================================
```
