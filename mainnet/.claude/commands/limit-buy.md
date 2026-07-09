Place a CoW Swap limit buy order from a BittyVault on Ethereum mainnet. Receives exactly `buy_amount` spending at most `sell_amount_max`, filled by CoW solvers.

**Usage:** `/limit-buy <from_asset> <to_asset> <buy_amount> <sell_amount_max> [valid_duration]`

- `<from_asset>` — token to spend: symbol (WETH, WBTC, USDT, USDC, USDS) or `0x…`
- `<to_asset>` — token to receive: symbol or `0x…`
- `<buy_amount>` — exact amount to receive (human-readable)
- `<sell_amount_max>` — maximum to spend (slippage cap)
- `[valid_duration]` — `1h`, `6h`, `24h` (default), `7d`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: from_asset, to_asset, buy_amount, sell_amount_max, optional valid_duration (default `24h`).
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

CoW Swap intent protocol: resolved from the vault on-chain (see step 2).
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
RPC="<rpc_url>"
INTENT_PROTOCOL=$(cast call $VAULT_ADDRESS "getIntentProtocols()(address[])" --rpc-url "$RPC" | tr -d '[] ' | cut -d, -f1)
```

If `$INTENT_PROTOCOL` is empty, stop: "Error: no CoW Swap protocol registered on this vault. Ask the vault owner to add it via the web app (Manage → Protocols)."

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

If balance < `<sell_amount_max_raw>`, stop with an insufficient balance error.

### 8. Show preview and ask for confirmation

```
⚠ CoW Swap limit buy order — MAINNET
Vault            : $VAULT_ADDRESS
Buy (exact)      : <buy_amount> <to_symbol>
Spend (max)      : <sell_amount_max> <from_symbol>
Valid until      : <human_readable_expiry>
Intent protocol  : $INTENT_PROTOCOL
```

Ask: "Place limit buy order on MAINNET? (yes/no)" — if no, stop.

### 9. Simulate to get orderId, then execute on-chain

```bash
ASSET_MANAGER=$(cast wallet address --private-key "$PRIVATE_KEY")

# Simulate to get the GPv2Order hash (orderId) before sending
ORDER_ID=$(cast call $VAULT_ADDRESS \
  "limitBuy(address,address,address,uint256,uint256,uint32)(bytes32)" \
  "$INTENT_PROTOCOL" "<from_asset_address>" "<to_asset_address>" \
  "<buy_amount_raw>" "<sell_amount_max_raw>" "$VALID_TO" \
  --from "$ASSET_MANAGER" --rpc-url "$RPC")

# Execute on-chain
TX_HASH=$(cast send $VAULT_ADDRESS \
  "limitBuy(address,address,address,uint256,uint256,uint32)" \
  "$INTENT_PROTOCOL" "<from_asset_address>" "<to_asset_address>" \
  "<buy_amount_raw>" "<sell_amount_max_raw>" "$VALID_TO" \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" \
  --json | python3 -c "import json,sys; print(json.load(sys.stdin)['transactionHash'])")
```

### 10. Post order to CoW API

The adapter applies a partner fee (`PARTNER_FEE_BPS = 20` → 0.2%) on-chain. For a **buy** order it grosses the sell side **up** 0.2% (`_grossUpForPartnerFee`), so the CoW post must use that same grossed-up `sellAmount` — posting the raw amount is rejected with `InvalidEip1271Signature`.

```bash
POST_SELL_AMOUNT=$(python3 -c "print(<sell_amount_max_raw> * 10020 // 10000)")

JSON_BODY=$(python3 -c "
import json
print(json.dumps({
    'sellToken': '<from_asset_address>',
    'buyToken': '<to_asset_address>',
    'receiver': '$VAULT_ADDRESS',
    'sellAmount': '$POST_SELL_AMOUNT',
    'buyAmount': '<buy_amount_raw>',
    'validTo': $VALID_TO,
    'appData': '$APP_DATA',
    'feeAmount': '0',
    'kind': 'buy',
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
Limit buy order placed!
  Tx hash       : <tx_hash>
  Etherscan     : https://etherscan.io/tx/<tx_hash>
  Order ID      : <ORDER_ID>
  CoW Order UID : <COW_UID>
  Buy (exact)   : <buy_amount> <to_symbol>
  Spend (max)   : <sell_amount_max> <from_symbol>
  Expires       : <human_readable_expiry>
  CoW Explorer  : https://explorer.cow.fi/orders/<COW_UID>

Save the Order ID to cancel: /cancel-order <ORDER_ID>
```
