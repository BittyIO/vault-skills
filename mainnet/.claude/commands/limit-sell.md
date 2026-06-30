Place a CoW Swap limit sell order from a BittyVault on Ethereum mainnet. The order is submitted to CoW Protocol's off-chain orderbook and filled by CoW solvers at the best available price.

**Usage:** `/limit-sell <from_asset> <to_asset> <sell_amount> <buy_amount_min> [valid_duration]`

- `<from_asset>` — token to sell: symbol (WETH, WBTC, USDT, USDC, USDS) or raw `0x…`
- `<to_asset>` — token to buy: symbol or raw `0x…`
- `<sell_amount>` — exact amount to sell (human-readable)
- `<buy_amount_min>` — minimum amount to receive (slippage protection)
- `[valid_duration]` — `1h`, `6h`, `24h` (default), `7d`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: from_asset, to_asset, sell_amount, buy_amount_min, optional valid_duration (default `24h`).
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

CoW Swap intent protocol (mainnet): `0xBB75486D48d93023DC377746e1d0be1D81C2a037`
CoW Swap explorer (mainnet): `https://explorer.cow.fi/`

⚠ **This operates on Ethereum mainnet with real funds.**

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set}"
```

### 2. Set intent protocol and verify registration

```bash
INTENT_PROTOCOL=0xBB75486D48d93023DC377746e1d0be1D81C2a037
RPC="<rpc_url>"
cast call $VAULT_ADDRESS "getIntentProtocols()(address[])" --rpc-url "$RPC"
```

If `$INTENT_PROTOCOL` not in result, stop: "Error: CoW Swap protocol not registered. Run /add-protocols intent 0xBB75486D48d93023DC377746e1d0be1D81C2a037"

### 3. Get APP_DATA from intent protocol

```bash
APP_DATA=$(cast call $INTENT_PROTOCOL "APP_DATA()(bytes32)" --rpc-url "$RPC")
```

### 4. Resolve asset addresses and decimals

Match symbols against the table. If raw `0x…`, fetch decimals:

```bash
cast call <address> "decimals()(uint8)" --rpc-url "$RPC"
```

### 5. Convert amounts to raw units

- 18 decimals: `cast to-unit <amount>ether wei`
- 6 or 8 decimals: `python3 -c "print(int(<amount> * 10**<decimals>))"`

### 6. Compute validTo timestamp

Parse duration: `1h`→3600, `6h`→21600, `24h`→86400, `7d`→604800.

```bash
VALID_TO=$(python3 -c "import time; print(int(time.time()) + <seconds>)")
```

### 7. Check vault balance

```bash
cast call <from_asset_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS --rpc-url "$RPC"
```

If balance < `<sell_amount_raw>`, stop with an insufficient balance error.

### 8. Show preview and ask for confirmation

```
⚠ CoW Swap limit sell order — MAINNET
Vault            : $VAULT_ADDRESS
Sell             : <sell_amount> <from_symbol> (<sell_amount_raw> raw)
Buy (min)        : <buy_amount_min> <to_symbol>
Valid until      : <human_readable_expiry>
Intent protocol  : $INTENT_PROTOCOL
```

Ask: "Place limit sell order on MAINNET? (yes/no)" — if no, stop.

### 9. Simulate to get orderId, then execute on-chain

```bash
ASSET_MANAGER=$(cast wallet address --private-key "$PRIVATE_KEY")

# Simulate to get the GPv2Order hash (orderId) before sending
ORDER_ID=$(cast call $VAULT_ADDRESS \
  "limitSell(address,address,address,uint256,uint256,uint32)(bytes32)" \
  "$INTENT_PROTOCOL" "<from_asset_address>" "<to_asset_address>" \
  "<sell_amount_raw>" "<buy_amount_min_raw>" "$VALID_TO" \
  --from "$ASSET_MANAGER" --rpc-url "$RPC")

# Execute on-chain
TX_HASH=$(cast send $VAULT_ADDRESS \
  "limitSell(address,address,address,uint256,uint256,uint32)" \
  "$INTENT_PROTOCOL" "<from_asset_address>" "<to_asset_address>" \
  "<sell_amount_raw>" "<buy_amount_min_raw>" "$VALID_TO" \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" \
  --json | python3 -c "import json,sys; print(json.load(sys.stdin)['transactionHash'])")
```

### 10. Post order to CoW API

```bash
JSON_BODY=$(python3 -c "
import json
print(json.dumps({
    'sellToken': '<from_asset_address>',
    'buyToken': '<to_asset_address>',
    'receiver': '$VAULT_ADDRESS',
    'sellAmount': '<sell_amount_raw>',
    'buyAmount': '<buy_amount_min_raw>',
    'validTo': $VALID_TO,
    'appData': '$APP_DATA',
    'feeAmount': '0',
    'kind': 'sell',
    'partiallyFillable': False,
    'signingScheme': 'eip1271',
    'signature': '0x',
    'from': '$VAULT_ADDRESS',
    'sellTokenBalance': 'erc20',
    'buyTokenBalance': 'erc20'
}))
")

COW_RESPONSE=$(curl -s -X POST "https://api.cow.fi/mainnet/api/v1/orders" \
  -H "Content-Type: application/json" \
  -d "$JSON_BODY")

COW_UID=$(python3 -c "
import json, sys
resp = '$COW_RESPONSE'
try:
    parsed = json.loads(resp)
    if isinstance(parsed, str):
        print(parsed)
    else:
        print('COW_API_ERROR: ' + json.dumps(parsed), flush=True)
except:
    print('COW_PARSE_ERROR: ' + resp, flush=True)
")
```

If `COW_UID` starts with `COW_API_ERROR` or `COW_PARSE_ERROR`, print the error and stop.

### 11. Show result

```
Limit sell order placed!
  Tx hash       : <tx_hash>
  Etherscan     : https://etherscan.io/tx/<tx_hash>
  Order ID      : <ORDER_ID>
  CoW Order UID : <COW_UID>
  Sell          : <sell_amount> <from_symbol>
  Buy (min)     : <buy_amount_min> <to_symbol>
  Expires       : <human_readable_expiry>
  CoW Explorer  : https://explorer.cow.fi/orders/<COW_UID>

Save the Order ID to cancel: /cancel-order <ORDER_ID>
```
