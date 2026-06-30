Create a CoW Swap TWAP sell order on a BittyVault on Ethereum mainnet. Splits total sell into n equal parts at regular intervals. After registration you must post each part to CoW API when its window opens using `/post-twap-part`.

**Usage:** `/twap-sell <from_asset> <to_asset> <total_sell> <min_per_part> <n_parts> <interval> [span]`

- `<from_asset>` — token to sell: symbol (WETH, WBTC, USDT, USDC, USDS) or `0x…`
- `<to_asset>` — token to receive: symbol or `0x…`
- `<total_sell>` — total sell amount across all parts (human-readable)
- `<min_per_part>` — minimum receive per part (slippage floor)
- `<n_parts>` — number of parts (e.g. `7` for daily over a week)
- `<interval>` — seconds between parts (e.g. `86400` for daily)
- `[span]` — execution window per slot in seconds (0 = full slot, default)

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as positional: from, to, total_sell, min_per_part, n, interval, optional span (default 0).
If first 6 are missing, stop and print usage.

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

### 3. Get APP_DATA and clone address

```bash
APP_DATA=$(cast call $INTENT_PROTOCOL "APP_DATA()(bytes32)" --rpc-url "$RPC")
CLONE=$(cast call $VAULT_ADDRESS "getClone(address)(address)" "$INTENT_PROTOCOL" --rpc-url "$RPC")
```

### 4. Resolve assets and convert amounts to raw units

Match symbols against the table. If raw address, fetch decimals:

```bash
cast call <address> "decimals()(uint8)" --rpc-url "$RPC"
```

### 5. Validate and check balance

Validate: n > 0, interval > 0, total_sell_raw / n > 0.

```bash
cast call <from_asset_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS --rpc-url "$RPC"
```

If balance < `<total_sell_raw>`, stop with an insufficient balance error.

### 6. Show preview and ask for confirmation

```
⚠ CoW Swap TWAP sell — MAINNET
Vault              : $VAULT_ADDRESS
Sell total         : <total_sell> <from_symbol> (<n_parts> × <sell_per_part>)
Receive (min/part) : <min_per_part> <to_symbol>
Interval           : <interval>s — total ~<human duration>
Span               : <span>s per slot (0 = full interval)
Intent protocol    : $INTENT_PROTOCOL
```

Ask: "Create TWAP sell on MAINNET? (yes/no)" — if no, stop.

### 7. Simulate to get twapId, then execute on-chain

```bash
ASSET_MANAGER=$(cast wallet address --private-key "$PRIVATE_KEY")

TWAP_ID=$(cast call $VAULT_ADDRESS \
  "twapSell(address,address,address,uint256,uint256,uint256,uint256,uint256)(bytes32)" \
  "$INTENT_PROTOCOL" "<from_asset_address>" "<to_asset_address>" \
  "<total_sell_raw>" "<min_per_part_raw>" "<n_parts>" "<interval>" "<span>" \
  --from "$ASSET_MANAGER" --rpc-url "$RPC")

TX_HASH=$(cast send $VAULT_ADDRESS \
  "twapSell(address,address,address,uint256,uint256,uint256,uint256,uint256)" \
  "$INTENT_PROTOCOL" "<from_asset_address>" "<to_asset_address>" \
  "<total_sell_raw>" "<min_per_part_raw>" "<n_parts>" "<interval>" "<span>" \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" \
  --json | python3 -c "import json,sys; print(json.load(sys.stdin)['transactionHash'])")
```

### 8. Post part 0 to CoW API immediately

Compute part 0 validTo and order details, then post:

```bash
START_TIME=$(python3 -c "import time; print(int(time.time()))")
SELL_PER_PART=$(python3 -c "print(<total_sell_raw> // <n_parts>)")
EFFECTIVE_SPAN=$(python3 -c "s=<span>; d=<interval>; print(s if s > 0 else d)")
PART0_VALID_TO=$(python3 -c "print($START_TIME + $EFFECTIVE_SPAN)")

JSON_BODY=$(python3 -c "
import json
print(json.dumps({
    'sellToken': '<from_asset_address>',
    'buyToken': '<to_asset_address>',
    'receiver': '$VAULT_ADDRESS',
    'sellAmount': str($SELL_PER_PART),
    'buyAmount': '<min_per_part_raw>',
    'validTo': $PART0_VALID_TO,
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

### 9. Show result

```
TWAP sell created!
  Tx hash        : <tx_hash>
  Etherscan      : https://etherscan.io/tx/<tx_hash>
  TWAP ID        : <TWAP_ID>
  Part 0 UID     : <COW_UID>
  Parts          : <n_parts> × <sell_per_part_human> <from_symbol>
  Interval       : <interval>s
  CoW Explorer   : https://explorer.cow.fi/orders/<COW_UID>

To post subsequent parts when each window opens: /post-twap-part <TWAP_ID>
To cancel the TWAP: /cancel-twap <TWAP_ID>
```
