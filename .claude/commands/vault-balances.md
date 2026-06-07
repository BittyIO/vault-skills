Show all assets and their balances in the vault — wallet balance, supplied to Aave, and staked in Lido.

**Usage:** `/vault-balances`

No arguments needed. Reads `$VAULT_ADDRESS` from env.

---

## Hardcoded Sepolia configuration

Lending protocol: `0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436`

Staking protocol: `0x2Db440cF6215d68d44736A287B253F4461399aa0`

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Fetch the asset and stablecoin lists from the vault

```bash
cast call $VAULT_ADDRESS "getAssets()(address[])" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call $VAULT_ADDRESS "getStableCoins()(address[])" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Combine both lists into a single list of token addresses to inspect. Label each as `asset` or `stablecoin`.

### 3. For each token, fetch all three balance types

For every token address in the combined list, run the following in parallel:

**Vault wallet balance:**
```bash
cast call <token_address> \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

**Supplied balance (Aave):**
```bash
cast call $VAULT_ADDRESS \
  "getSuppliedBalance(address,address)(uint256)" \
  "0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436" \
  "<token_address>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

**Staked balance (Lido):**
```bash
cast call $VAULT_ADDRESS \
  "getStakedBalance(address,address)(uint256)" \
  "0x2Db440cF6215d68d44736A287B253F4461399aa0" \
  "<token_address>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

**Token decimals and symbol** (to display human-readable amounts):
```bash
cast call <token_address> "decimals()(uint8)" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call <token_address> "symbol()(string)" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Convert each raw balance to human-readable by dividing by `10^decimals`. Show at least 4 significant decimal places.

### 4. Display the results

Print a summary header:
```
Vault: $VAULT_ADDRESS
Network: Sepolia
```

Then print a table with one row per token:

```
Symbol   Type        Wallet          Supplied (Aave)  Staked (Lido)   Total
-------- ----------- --------------- ---------------- --------------- ---------------
WETH     asset       1.2340          0.5000           0.0000          1.7340
WBTC     asset       0.0100          0.0000           0.0000          0.0100
USDC     stablecoin  500.0000        0.0000           0.0000          500.0000
USDT     stablecoin  0.0000          250.0000         0.0000          250.0000
...
```

- `Total` = Wallet + Supplied + Staked
- Skip a token row entirely if all three balances are 0
- If the asset list is empty, print: "No assets registered in this vault."

Finally print a pending unstake section if there are any:

```bash
cast call $VAULT_ADDRESS \
  "getUnstakeRequestIds(address)(uint256[])" \
  "0x2Db440cF6215d68d44736A287B253F4461399aa0" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

If the result is non-empty, print:
```
Pending unstake request IDs: <ids>
Run /claim-unstaked to collect once finalized.
```
