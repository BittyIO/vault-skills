Place a CoW Swap limit sell order from a BittyVault on Sepolia. The order is submitted to CoW Protocol's off-chain orderbook and filled by CoW solvers at the best available price.

**Usage:** `/limit-sell <from_asset> <to_asset> <sell_amount> <buy_amount_min> [valid_duration]`

- `<from_asset>` — token to sell: symbol (WETH, WBTC, USDT, USDC) or raw `0x…`
- `<to_asset>` — token to buy: symbol or raw `0x…`
- `<sell_amount>` — exact amount to sell (human-readable, e.g. `1.5`)
- `<buy_amount_min>` — minimum amount to receive (slippage protection)
- `[valid_duration]` — how long the order stays live: `1h`, `6h`, `24h` (default), `7d`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: from_asset, to_asset, sell_amount, buy_amount_min, optional valid_duration (default `24h`).
If the first 4 are missing, stop and print usage.

---

## Hardcoded Sepolia configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` | 6 |

CoW Swap intent protocol (Sepolia): `0x480154016Bbc335Af34D0f5c75f3d0cbc17a2FfD`
CoW Swap explorer (Sepolia): `https://explorer.cow.fi/sepolia/`

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Set intent protocol and verify registration

```bash
INTENT_PROTOCOL=0x480154016Bbc335Af34D0f5c75f3d0cbc17a2FfD
RPC="<rpc_url>"
cast call $VAULT_ADDRESS "getIntentProtocols()(address[])" --rpc-url "$RPC"
```

If `$INTENT_PROTOCOL` is not in the result, stop:
```
Error: CoW Swap protocol not registered. Run /add-protocols intent 0x480154016Bbc335Af34D0f5c75f3d0cbc17a2FfD
```

### 3. Get APP_DATA from intent protocol

```bash
APP_DATA=$(cast call $INTENT_PROTOCOL "APP_DATA()(bytes32)" --rpc-url "$RPC")
```

### 4. Resolve asset addresses and decimals

If `<from_asset>` / `<to_asset>` match a known symbol (case-insensitive), use the table above.
If they start with `0x`, fetch their decimals:

```bash
cast call <asset_address> "decimals()(uint8)" --rpc-url "$RPC"
```

### 5. Convert amounts to raw units

- 18 decimals: `cast to-unit <amount>ether wei`
- Other decimals: `<amount> * 10^<decimals>` as integer

Save as `<sell_amount_raw>` and `<buy_amount_min_raw>`.

### 6. Compute validTo timestamp

Parse `<valid_duration>` and convert to seconds:
- `1h` → 3600, `6h` → 21600, `24h` → 86400, `7d` → 604800

```bash
VALID_TO=$(python3 -c "import time; print(int(time.time()) + <duration_seconds>)")
```

`VALID_TO` must fit in `uint32` (max ~2106). If it doesn't, stop with an error.

### 7. Check vault balance

```bash
cast call <from_asset_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS --rpc-url "$RPC"
```

If balance < `<sell_amount_raw>`, stop:
```
Error: Vault balance insufficient.
  Vault balance : <balance> (raw)
  Requested     : <sell_amount_raw> (raw)
```

### 8. Show preview and ask for confirmation

Print:
```
CoW Swap limit sell order
Vault            : $VAULT_ADDRESS
Sell             : <sell_amount> <from_asset_symbol> (<sell_amount_raw> raw)
Buy (min)        : <buy_amount_min> <to_asset_symbol> (<buy_amount_min_raw> raw)
Valid until      : <VALID_TO> (Unix) — <human_readable_expiry>
Intent protocol  : $INTENT_PROTOCOL
```

Ask: "Place limit sell order? (yes/no)"
If no, stop.

### 9. Simulate to get orderId, then execute on-chain

```bash
ASSET_MANAGER=$(cast wallet address --private-key "$PRIVATE_KEY")

# Simulate to get the GPv2Order hash (orderId)
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

If the transaction reverts, print the revert reason and stop.

### 10. Post order to CoW API

The adapter applies a partner fee (`PARTNER_FEE_BPS = 20` → 0.2%) on-chain. For a **sell** order it discounts the buy side **down** 0.2% (`_discountForPartnerFee`), so the CoW post must use that same discounted `buyAmount` — posting the raw amount is rejected with `InvalidEip1271Signature`.

```bash
POST_BUY_AMOUNT=$(python3 -c "print(<buy_amount_min_raw> * 9980 // 10000)")

JSON_BODY=$(python3 -c "
import json
print(json.dumps({
    'sellToken': '<from_asset_address>',
    'buyToken': '<to_asset_address>',
    'receiver': '$VAULT_ADDRESS',
    'sellAmount': '<sell_amount_raw>',
    'buyAmount': '$POST_BUY_AMOUNT',
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

COW_RESPONSE=$(curl -s -X POST "https://api.cow.fi/sepolia/api/v1/orders" \
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

Print:
```
Limit sell order placed!
  Tx hash       : <tx_hash>
  Etherscan     : https://sepolia.etherscan.io/tx/<tx_hash>
  Order ID      : <ORDER_ID>
  CoW Order UID : <COW_UID>
  Sell          : <sell_amount> <from_asset_symbol>
  Buy (min)     : <buy_amount_min> <to_asset_symbol>
  Expires       : <human_readable_expiry>
  CoW Explorer  : https://explorer.cow.fi/sepolia/orders/<COW_UID>

Save the Order ID to cancel with /cancel-order <ORDER_ID>
```
