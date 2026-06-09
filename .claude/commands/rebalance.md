Swap one asset for another inside a BittyVault via UniswapV3 on Sepolia.

**Usage:** `/rebalance <from_asset> <to_asset> <sell_amount> <buy_amount_min> [fee_tier]`

- `<from_asset>` — token to sell: symbol (WETH, WBTC, USDT, USDC) or raw `0x…`
- `<to_asset>` — token to buy: symbol or raw `0x…`
- `<sell_amount>` — human-readable amount to sell (e.g. `1.5`)
- `<buy_amount_min>` — minimum human-readable amount to receive (slippage protection)
- `[fee_tier]` — optional UniswapV3 pool fee in bps: `100`, `500`, `3000` (default), or `10000`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: from_asset, to_asset, sell_amount, buy_amount_min, optional fee_tier.
If the first 4 are missing, stop and print usage.

---

## Hardcoded Sepolia configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| WETH_UNI | `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14` | 18 |
| WETH_AAVE | `0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c` | 18 |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` | 6 |

AMM protocol: `0x642810409Aa6b2854777bf321adfb8B131cD91D0`

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Resolve asset addresses and decimals

Resolve both `<from_asset>` and `<to_asset>` using the table above or by fetching decimals if raw addresses are given:

```bash
cast call <asset_address> "decimals()(uint8)" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

### 3. Convert amounts to raw units

- 18 decimals: `cast to-unit <amount>ether wei`
- Other decimals: `<amount> * 10^<decimals>` as integer

Save as `<sell_amount_raw>` and `<buy_amount_min_raw>`.

### 4. Check vault's from-token balance

```bash
cast call <from_asset_address> \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

If balance < `<sell_amount_raw>`, stop with:
```
Error: Vault balance insufficient for <from_asset_symbol>.
  Vault balance : <balance> (raw)
  Requested     : <sell_amount_raw> (raw)
```

### 5. Build the UniswapV3 swap path and encode calldata

Default fee tier to `3000` if not provided.

**Build the path** (packed encoding: tokenIn ++ fee_3bytes ++ tokenOut):
```bash
FROM_NO_0X="${FROM_ASSET_ADDRESS#0x}"
TO_NO_0X="${TO_ASSET_ADDRESS#0x}"
FEE_HEX=$(printf "%06x" <fee_tier>)
PATH_HEX="0x${FROM_NO_0X}${FEE_HEX}${TO_NO_0X}"
```

**ABI-encode the data** for the UniswapV3 protocol (tokenIn, amountIn, tokenOut, amountOutMin, path):
```bash
DATA=$(cast abi-encode \
  "f(address,uint256,address,uint256,bytes)" \
  "<from_asset_address>" \
  "<sell_amount_raw>" \
  "<to_asset_address>" \
  "<buy_amount_min_raw>" \
  "$PATH_HEX")
```

### 6. Show preview and ask for confirmation

Print:
```
Vault         : $VAULT_ADDRESS
Sell          : <sell_amount> <from_asset_symbol> (<sell_amount_raw> raw)
Buy (min)     : <buy_amount_min> <to_asset_symbol> (<buy_amount_min_raw> raw)
Pool fee      : <fee_tier> (<fee_tier/10000>%)
AMM protocol  : 0x642810409Aa6b2854777bf321adfb8B131cD91D0
Swap path     : <from_asset_symbol> --[<fee_tier>]--> <to_asset_symbol>
```

Ask: "Proceed with swap? (yes/no)"
If no, stop.

### 7. Call rebalance on the vault

```bash
cast send $VAULT_ADDRESS \
  "rebalance(address,address,address,uint256,uint256,bytes)" \
  "0x642810409Aa6b2854777bf321adfb8B131cD91D0" \
  "<from_asset_address>" \
  "<to_asset_address>" \
  "<sell_amount_raw>" \
  "<buy_amount_min_raw>" \
  "$DATA" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 8. Show result

Check vault balances for both tokens after the tx:

```bash
cast call <from_asset_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call <to_asset_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
Swap successful!
  Tx hash              : <tx_hash>
  Etherscan            : https://sepolia.etherscan.io/tx/<tx_hash>
  Sold                 : <sell_amount> <from_asset_symbol>
  Vault <from> balance : <from_balance_after> (raw)
  Vault <to> balance   : <to_balance_after> (raw)
```
