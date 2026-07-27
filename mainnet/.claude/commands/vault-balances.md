Show all assets and their balances in the vault — wallet balance, supplied to Aave, staked in Lido, and deposited in Sky on Ethereum mainnet.

**Usage:** `/vault-balances`

No arguments needed. Reads `$VAULT_ADDRESS` from env.

---

## Steps

### 1. Check environment variables and resolve protocols

The lending (Aave) and staking (Lido) protocols are read from the vault on-chain, so this works for a vault created by any factory version. A mainnet vault has both Lido and Sky staking protocols registered — the Lido one is identified because only it responds to `stETH()`.

```bash
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — set it in .env to a vault where your key holds a seat}"

LENDING_PROTOCOL=$(cast call $VAULT_ADDRESS "getLendingProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[] ' | cut -d, -f1)

STAKING_PROTOCOL=""
for p in $(cast call $VAULT_ADDRESS "getStakingProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[]' | tr ',' ' '); do
  if cast call "$p" "stETH()(address)" --rpc-url "<rpc_url>" >/dev/null 2>&1; then STAKING_PROTOCOL="$p"; break; fi
done
```

If `$LENDING_PROTOCOL` is empty, show the Supplied column as 0. If `$STAKING_PROTOCOL` is empty, show the Staked column as 0 and skip the pending-unstake section.

### 2. Fetch the asset and stablecoin lists from the vault

```bash
cast call $VAULT_ADDRESS "getAssets()(address[])" \
  --rpc-url "<rpc_url>"

cast call $VAULT_ADDRESS "getStableCoins()(address[])" \
  --rpc-url "<rpc_url>"
```

Combine both lists into a single list of token addresses to inspect. Label each as `asset` or `stablecoin`.

### 3. For each token, fetch all three balance types

For every token address in the combined list, run the following in parallel:

**Vault wallet balance:**
```bash
cast call <token_address> \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

**Supplied balance (Aave):**
```bash
cast call $VAULT_ADDRESS \
  "getSuppliedBalance(address,address)(uint256)" \
  "$LENDING_PROTOCOL" \
  "<token_address>" \
  --rpc-url "<rpc_url>"
```

**Staked balance (Lido):**
```bash
cast call $VAULT_ADDRESS \
  "getStakedBalance(address,address)(uint256)" \
  "$STAKING_PROTOCOL" \
  "<token_address>" \
  --rpc-url "<rpc_url>"
```

**Token decimals and symbol** (to display human-readable amounts):
```bash
cast call <token_address> "decimals()(uint8)" \
  --rpc-url "<rpc_url>"

cast call <token_address> "symbol()(string)" \
  --rpc-url "<rpc_url>"
```

Convert each raw balance to human-readable by dividing by `10^decimals`. Show at least 4 significant decimal places.

### 4. Display the results

Print a summary header:
```
Vault: $VAULT_ADDRESS
Network: Ethereum mainnet
```

Then print a table with one row per token:

```
Symbol   Type        Wallet          Supplied (Aave)  Staked (Lido)   Total
-------- ----------- --------------- ---------------- --------------- ---------------
WETH     asset       1.2340          0.5000           0.0000          1.7340
WBTC     asset       0.0100          0.0000           0.0000          0.0100
USDC     stablecoin  500.0000        0.0000           0.0000          500.0000
USDT     stablecoin  0.0000          250.0000         0.0000          250.0000
USDS     stablecoin  100.0000        0.0000           0.0000          100.0000
...
```

- `Total` = Wallet + Supplied + Staked
- Skip a token row entirely if all three balances are 0
- If the asset list is empty, print: "No assets registered in this vault."

Finally print a pending unstake section if there are any:

```bash
cast call $VAULT_ADDRESS \
  "getUnstakeRequestIds(address)(uint256[])" \
  "$STAKING_PROTOCOL" \
  --rpc-url "<rpc_url>"
```

If the result is non-empty, print:
```
Pending unstake request IDs: <ids>
Run /claim-unstaked to collect once finalized.
```
