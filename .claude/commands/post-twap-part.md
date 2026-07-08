Post the current active TWAP part to the CoW API for a BittyVault on Sepolia. Call this at the start of each TWAP interval window.

**Usage:** `/post-twap-part <twap_id>`

- `<twap_id>` — the TWAP ID returned by `/twap-sell` or `/twap-buy`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: twap_id.
If missing, stop and print usage.

---

CoW Swap intent protocol (Sepolia): `0x480154016Bbc335Af34D0f5c75f3d0cbc17a2FfD`
CoW Swap explorer (Sepolia): `https://explorer.cow.fi/sepolia/`

---

## Steps

### 1. Check environment variables

```bash
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set}"
```

### 2. Resolve clone address

```bash
INTENT_PROTOCOL=0x480154016Bbc335Af34D0f5c75f3d0cbc17a2FfD
RPC="<rpc_url>"

CLONE=$(cast call $VAULT_ADDRESS "getClone(address)(address)" "$INTENT_PROTOCOL" --rpc-url "$RPC")
```

If `CLONE` is `0x0000000000000000000000000000000000000000`, stop: "Error: CoW Swap clone not found. ask the vault owner to add the CoW Swap protocol via the web app."

### 3. Check TWAP is active and get current part hash

```bash
TWAP_ID=<twap_id>

IS_ACTIVE=$(cast call $CLONE "isTwapActive(bytes32)(bool)" "$TWAP_ID" --rpc-url "$RPC")
PART_HASH=$(cast call $CLONE "getCurrentTwapPartHash(bytes32)(bytes32)" "$TWAP_ID" --rpc-url "$RPC")
```

If `IS_ACTIVE` is `false`, stop: "Error: TWAP $TWAP_ID is not active (either not started, expired, or outside execution window)."
If `PART_HASH` is `0x0000000000000000000000000000000000000000000000000000000000000000`, stop: "Error: No executable part in the current window."

### 4. Get TWAP params and APP_DATA

```bash
APP_DATA=$(cast call $CLONE "APP_DATA()(bytes32)" --rpc-url "$RPC")

# TwapParams: (address sellToken, address buyToken, uint256 sellAmountPerPart, uint256 buyAmountMinPerPart, uint32 startTime, uint32 partDuration, uint32 span, uint32 n)
TWAP_PARAMS=$(cast call $CLONE "twapOrders(bytes32)(address,address,uint256,uint256,uint32,uint32,uint32,uint32)" \
  "$TWAP_ID" --rpc-url "$RPC")
```

Parse the output to extract: sell_token, buy_token, sell_amount_per_part, buy_amount_min, start_time, part_duration, span, n.

Compute current part validTo:

```bash
VALID_TO=$(python3 -c "
import time
now = int(time.time())
start_time = <start_time>
part_duration = <part_duration>
span = <span>
effective_span = span if span > 0 else part_duration
part_index = (now - start_time) // part_duration
part_start = start_time + part_index * part_duration
print(part_start + effective_span)
")
```

### 5. Post current part to CoW API

```bash
JSON_BODY=$(python3 -c "
import json
print(json.dumps({
    'sellToken': '<sell_token>',
    'buyToken': '<buy_token>',
    'receiver': '$VAULT_ADDRESS',
    'sellAmount': '<sell_amount_per_part>',
    'buyAmount': '<buy_amount_min>',
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

### 6. Show result

```
TWAP part posted!
  TWAP ID       : <TWAP_ID>
  CoW Order UID : <COW_UID>
  Valid until   : <human_readable_expiry>
  CoW Explorer  : https://explorer.cow.fi/sepolia/orders/<COW_UID>

Run /post-twap-part <TWAP_ID> again at the next interval window.
```
