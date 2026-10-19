Swap one asset for another inside a BittyVault at market, via the Uniswap Universal Router on Sepolia.

**Usage:** `/rebalance <from_asset> <to_asset> <sell_amount> [slippage_bps]`

- `<from_asset>` — token to sell: symbol (WETH, USDT, USDC) or raw `0x…`
- `<to_asset>` — token to buy: symbol or raw `0x…`
- `<sell_amount>` — human-readable amount to sell (e.g. `0.01`)
- `[slippage_bps]` — tolerated slippage below the quote, in basis points (default `100` = 1%)

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: from_asset, to_asset, sell_amount, optional slippage_bps.
If the first 3 are missing, stop and print usage.

---

## Sepolia tokens

| Symbol | Address | Decimals | Market-tradeable |
|--------|---------|----------|------------------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 | yes |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 | yes |
| USDC | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` | 6 | yes |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 | no — use `/limit-sell` |

A market trade needs both tokens to carry the guard's AMM-liquid flag (`assetCategory & 4`); otherwise
the vault reverts with `MarketTradeNotSupported`.

The route is quoted by Bitty's public routing API, which searches Uniswap v2/v3/v4 pools and returns a
route encoded for the vault's trade adapter (on Sepolia only v4 pools are executable). The adapter
takes a 0.2% fee — from the input when selling a stablecoin, otherwise from the output — and the
quote's `minReceive` already accounts for it.

---

## Steps

### 1. Check environment and resolve the market-trade protocol

```bash
: "${PRIVATE_KEY:?PRIVATE_KEY is not set — run /new-assetmanager first}"
: "${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
GUARD=$(cast call $VAULT_ADDRESS "guard()(address)" --rpc-url "<rpc_url>")
for p in $(cast call $GUARD "getProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[],'); do
  [ "$(cast call $GUARD "protocolCategory(address)(uint8)" $p --rpc-url "<rpc_url>")" = 3 ] && MARKET_PROTOCOL=$p
done
```

### 2. Resolve tokens and amount, check balance

Resolve both tokens (table above, or `decimals()(uint8)` for raw addresses). Convert `<sell_amount>` to
`<sell_raw>`. Check `balanceOf(vault)` of the from-token; stop if short.

### 3. Get a route

```bash
QUOTE=$(curl -s "https://bitty.io/api/ethereum/trade/route?network=sepolia&version=v2&tokenIn=<from_address>&tokenOut=<to_address>&amountIn=<sell_raw>&slippageBps=<slippage_bps>")
echo "$QUOTE" | python3 -c 'import json,sys; q=json.load(sys.stdin); print({k:v for k,v in q.items() if k!="route"})'
ROUTE=$(echo "$QUOTE" | python3 -c 'import json,sys; print(json.load(sys.stdin)["route"] or "")')
MIN_RECEIVE=$(echo "$QUOTE" | python3 -c 'import json,sys; print(json.load(sys.stdin)["minReceive"])')
```

If `route` is null, stop: "No Uniswap route for <from> → <to> on Sepolia." The route expires at
`deadline` (30 minutes) — re-quote if the user takes longer to confirm.

### 4. Preview and confirm

```
Vault        : $VAULT_ADDRESS
Sell         : <sell_amount> <from> (<sell_raw> raw)
Expected     : <receive> <to> (raw, after the 0.2% fee)
Minimum      : <minReceive> <to> (raw)
Route        : <hops joined with " → ">
```

Ask: "Proceed with swap? (yes/no)"

### 5. marketSell

```bash
cast send $VAULT_ADDRESS \
  "marketSell(address,address,uint256,address,uint256,bytes)" \
  $MARKET_PROTOCOL <from_address> <sell_raw> <to_address> $MIN_RECEIVE "$ROUTE" \
  --rpc-url "<rpc_url>" --private-key "$PRIVATE_KEY"
```

On revert:
- `InsufficientOutput` — price moved past the slippage; re-quote.
- `MarketTradePriceTooLow` / `MarketTradeExceedsDailyLossAllowance` — market-trade protection is on
  (new vaults start with a $10,000/day `marketTradeDailyLossAllowance`): every trade must come out
  within 5% of Chainlink value, and what it comes out short is charged to the day's budget. Sepolia
  test pools are badly mispriced, so the direction the pool underprices reverts; the other direction
  passes. `PriceStale` means the token's Chainlink feed has not updated recently.
- `OwnableUnauthorizedAccount` — this key lacks `PERM_MARKET_TRADE` or its grant has expired.

### 6. Show result

Re-read both token balances of the vault and print:
```
Swap successful!
  Tx         : https://sepolia.etherscan.io/tx/<tx_hash>
  Sold       : <sell_amount> <from>
  <from> bal : <after> (raw)
  <to> bal   : <before> → <after> (raw)
```
