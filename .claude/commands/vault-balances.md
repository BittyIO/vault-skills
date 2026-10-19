Show the vault's assets — wallet balance, supplied to Aave, staked in Lido — plus its asset manager and risk settings.

**Usage:** `/vault-balances`

No arguments needed. Reads `$VAULT_ADDRESS` from env.

---

## Sepolia tokens

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 |
| USDC | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` | 6 |
| stETH | `0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af` | 18 |

---

## Steps

### 1. Check environment and resolve protocols

```bash
: "${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
GUARD=$(cast call $VAULT_ADDRESS "guard()(address)" --rpc-url "<rpc_url>")
for p in $(cast call $GUARD "getProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[],'); do
  case "$(cast call $GUARD "protocolCategory(address)(uint8)" $p --rpc-url "<rpc_url>")" in
    1) STAKING_PROTOCOL=$p ;; 2) LENDING_PROTOCOL=$p ;;
  esac
done
```

### 2. Wallet balances

For each token in the table:
```bash
cast call <token> "balanceOf(address)(uint256)" $VAULT_ADDRESS --rpc-url "<rpc_url>"
```
Also the vault's raw ETH: `cast balance $VAULT_ADDRESS --rpc-url "<rpc_url>"` (normally 0 — incoming ETH
is wrapped; anyone can call `wrapNative()` to wrap a leftover).

### 3. Protocol positions

```bash
cast call $VAULT_ADDRESS "getBalances(address[],address[])(uint256[])" \
  "[$LENDING_PROTOCOL,$LENDING_PROTOCOL,$LENDING_PROTOCOL,$LENDING_PROTOCOL,$STAKING_PROTOCOL]" \
  "[0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,0x29f2D40B0605204364af54EC677bD022dA425d03,0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0,0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238,0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9]" \
  --rpc-url "<rpc_url>"
cast call $VAULT_ADDRESS "getPendingWithdrawalIds(address)(uint256[])" $STAKING_PROTOCOL --rpc-url "<rpc_url>"
```

If the batched call reverts (an asset the adapter does not know), query each pair on its own and show
the ones that answer.

### 4. Vault state

```bash
cast call $VAULT_ADDRESS "owner()(address)" --rpc-url "<rpc_url>"
cast call $VAULT_ADDRESS "getAssetManagerSettings()(address,uint64,address,uint64,uint32,uint32)" --rpc-url "<rpc_url>"
cast call $VAULT_ADDRESS "riskSettings()(uint64,uint64,uint64)" --rpc-url "<rpc_url>"
cast call $VAULT_ADDRESS "lockLevel()(uint8)" --rpc-url "<rpc_url>"
```

### 5. Print

Format amounts with each token's decimals and skip zero rows:
```
Vault <VAULT_ADDRESS> (Sepolia)  — https://sepolia.etherscan.io/address/<VAULT_ADDRESS>

Asset   Wallet        Aave         Lido (stETH)
WETH    0.0100        —            0.0050
USDT    12.50         5.00         —

Pending Lido requests : <ids or none>
Owner                 : <owner>
Asset manager         : <manager>, expires <date>, permissions <mask> (<names>)  [pending: <manager> at <date>]
Risk                  : timelock <s>s · send allowance <usd or none>/day · market-trade loss allowance <usd or off>/day
Lock                  : unlocked | emergency locked | locked forever
```
