Place a CoW Swap limit buy order from a BittyVault on Sepolia. Receives exactly `buy_amount` of the buy token spending at most `sell_amount_max` of the sell token, filled by CoW solvers.

**Usage:** `/limit-buy <from_asset> <to_asset> <buy_amount> <sell_amount_max> [valid_duration]`

- `<from_asset>` — token to spend: symbol (WETH, WBTC, USDT, USDC) or raw `0x…`
- `<to_asset>` — token to receive: symbol or raw `0x…`
- `<buy_amount>` — exact amount to receive (human-readable)
- `<sell_amount_max>` — maximum amount to spend (slippage cap)
- `[valid_duration]` — `1h`, `6h`, `24h` (default), `7d`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: from_asset, to_asset, buy_amount, sell_amount_max, optional valid_duration.
If the first 4 are missing, stop and print usage.

---

## Hardcoded Sepolia configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` | 6 |

CoW Swap intent protocol (Sepolia): `0x034ef104B0c483EB71Ba2aD91a1de6224AdF4F70`
CoW Swap explorer (Sepolia): `https://explorer.cow.fi/sepolia/`

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Set intent protocol and verify registration

```bash
INTENT_PROTOCOL=0x034ef104B0c483EB71Ba2aD91a1de6224AdF4F70
RPC="https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
cast call $VAULT_ADDRESS "getIntentProtocols()(address[])" --rpc-url "$RPC"
```

If the result doesn't include `$INTENT_PROTOCOL`, stop: "Error: CoW Swap protocol not registered. Run /add-protocols intent 0x034ef104B0c483EB71Ba2aD91a1de6224AdF4F70"

### 3. Get APP_DATA from intent protocol

```bash
APP_DATA=$(cast call $INTENT_PROTOCOL "APP_DATA()(bytes32)" --rpc-url "$RPC")
```

### 4. Resolve asset addresses and decimals

Match `<from_asset>` / `<to_asset>` against the symbol table (case-insensitive). If raw `0x…`, fetch decimals:

```bash
cast call <address> "decimals()(uint8)" --rpc-url "$RPC"
```

### 5. Convert amounts to raw units

- 18 decimals: `cast to-unit <amount>ether wei`
- 6 or 8 decimals: `python3 -c "print(int(<amount> * 10**<decimals>))"`

Save as `<buy_amount_raw>` and `<sell_amount_max_raw>`.

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
CoW Swap limit buy order
Vault            : $VAULT_ADDRESS
Buy (exact)      : <buy_amount> <to_symbol>
Spend (max)      : <sell_amount_max> <from_symbol>
Valid until      : <human_readable_expiry>
Intent protocol  : $INTENT_PROTOCOL
```

Ask: "Place limit buy order? (yes/no)" — if no, stop.

### 9. Simulate to get orderId, then execute on-chain

```bash
ASSET_MANAGER=$(cast wallet address --private-key "$PRIVATE_KEY")

# Simulate to get the GPv2Order hash (orderId)
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

```bash
JSON_BODY=$(python3 -c "
import json
print(json.dumps({
    'sellToken': '<from_asset_address>',
    'buyToken': '<to_asset_address>',
    'receiver': '$VAULT_ADDRESS',
    'sellAmount': '<sell_amount_max_raw>',
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

```
Limit buy order placed!
  Tx hash       : <tx_hash>
  Etherscan     : https://sepolia.etherscan.io/tx/<tx_hash>
  Order ID      : <ORDER_ID>
  CoW Order UID : <COW_UID>
  Buy (exact)   : <buy_amount> <to_symbol>
  Spend (max)   : <sell_amount_max> <from_symbol>
  Expires       : <human_readable_expiry>
  CoW Explorer  : https://explorer.cow.fi/sepolia/orders/<COW_UID>

Save the Order ID to cancel: /cancel-order <ORDER_ID>
```
