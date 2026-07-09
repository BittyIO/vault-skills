Swap one asset for another inside a BittyVault via UniswapV3 on Ethereum mainnet.

**Usage:** `/rebalance <from_asset> <to_asset> <sell_amount> <buy_amount_min> [fee_tier]`

- `<from_asset>` — token to sell: symbol (WETH, WBTC, USDC, USDT, USDS) or raw `0x…`
- `<to_asset>` — token to buy: symbol or raw `0x…`
- `<sell_amount>` — human-readable amount to sell (e.g. `1.5`)
- `<buy_amount_min>` — minimum human-readable amount to receive (slippage protection)
- `[fee_tier]` — optional UniswapV3 pool fee in bps: `100`, `500`, `3000` (default), or `10000`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: from_asset, to_asset, sell_amount, buy_amount_min, optional fee_tier.
If the first 4 are missing, stop and print usage.

---

## Hardcoded mainnet configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | 18 |
| WBTC | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` | 8 |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | 6 |
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` | 6 |
| USDS | `0xdC035D45d973E3EC169d2276DDab16f1e407384F` | 18 |

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

Then resolve the AMM protocol registered on the vault:

```bash
AMM_PROTOCOL=$(cast call $VAULT_ADDRESS "getAMMProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[] ' | cut -d, -f1)
```

If `$AMM_PROTOCOL` is empty, stop: `Error: no Uniswap AMM protocol registered on this vault.`

### 2. Resolve asset addresses and decimals

Resolve both `<from_asset>` and `<to_asset>` using the table above or by fetching decimals if raw addresses are given:

```bash
cast call <asset_address> "decimals()(uint8)" \
  --rpc-url "<rpc_url>"
```

### 3. Convert amounts to raw units

- 18 decimals: `cast to-unit <amount>ether wei`
- Other decimals: `<amount> * 10^<decimals>` as integer

Save as `<sell_amount_raw>` and `<buy_amount_min_raw>`.

### 4. Check vault's from-token balance

```bash
cast call <from_asset_address> \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
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
⚠ This is Ethereum mainnet — real funds will be used.

Vault         : $VAULT_ADDRESS
Sell          : <sell_amount> <from_asset_symbol> (<sell_amount_raw> raw)
Buy (min)     : <buy_amount_min> <to_asset_symbol> (<buy_amount_min_raw> raw)
Pool fee      : <fee_tier> (<fee_tier/10000>%)
AMM protocol  : $AMM_PROTOCOL
Swap path     : <from_asset_symbol> --[<fee_tier>]--> <to_asset_symbol>
```

Ask: "Proceed with swap? (yes/no)"
If no, stop.

### 7. Call rebalance on the vault

```bash
cast send $VAULT_ADDRESS \
  "rebalance(address,address,address,uint256,uint256,bytes)" \
  "$AMM_PROTOCOL" \
  "<from_asset_address>" \
  "<to_asset_address>" \
  "<sell_amount_raw>" \
  "<buy_amount_min_raw>" \
  "$DATA" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 8. Show result

Check vault balances for both tokens after the tx:

```bash
cast call <from_asset_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"

cast call <to_asset_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

Print:
```
Swap successful!
  Tx hash              : <tx_hash>
  Etherscan            : https://etherscan.io/tx/<tx_hash>
  Sold                 : <sell_amount> <from_asset_symbol>
  Vault <from> balance : <from_balance_after> (raw)
  Vault <to> balance   : <to_balance_after> (raw)
```
