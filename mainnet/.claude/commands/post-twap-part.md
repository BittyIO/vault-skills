Post the current active TWAP part to the CoW API for a BittyVault on Ethereum mainnet. Call this at the start of each TWAP interval window.

**Usage:** `/post-twap-part <twap_id>`

- `<twap_id>` — the TWAP ID returned by `/twap-sell` or `/twap-buy`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: twap_id.
If missing, stop and print usage.

---

CoW Swap intent protocol: resolved from the vault on-chain (see step 2).
CoW Swap explorer (mainnet): `https://explorer.cow.fi/`

⚠ **This operates on Ethereum mainnet with real funds.**

---

## Steps

### 1. Check environment variables

```bash
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set}"
```

### 2. Resolve clone address

```bash
RPC="<rpc_url>"
INTENT_PROTOCOL=$(cast call $VAULT_ADDRESS "getIntentProtocols()(address[])" --rpc-url "$RPC" | tr -d '[] ' | cut -d, -f1)

CLONE=$(cast call $VAULT_ADDRESS "getClone(address)(address)" "$INTENT_PROTOCOL" --rpc-url "$RPC")
```

If `$INTENT_PROTOCOL` is empty, stop: "Error: no CoW Swap protocol registered on this vault. Ask the vault owner to add it via the web app (Manage → Protocols)."
If `CLONE` is `0x0000000000000000000000000000000000000000`, stop: "Error: CoW Swap clone not found. ask the vault owner to add the CoW Swap protocol via the web app."

### 3. Check TWAP is active and get current part hash

```bash
TWAP_ID=<twap_id>

IS_ACTIVE=$(cast call $CLONE "isTwapActive(bytes32)(bool)" "$TWAP_ID" --rpc-url "$RPC")
PART_HASH=$(cast call $CLONE "getCurrentTwapPartHash(bytes32)(bytes32)" "$TWAP_ID" --rpc-url "$RPC")
```

If `IS_ACTIVE` is `false`, stop: "Error: TWAP $TWAP_ID is not active (either not started, expired, or outside execution window)."
If `PART_HASH` is `0x0000000000000000000000000000000000000000000000000000000000000000`, stop: "Error: No executable part in the current window."

### 4. Get TWAP params (incl. the per-TWAP appData) and re-register the document

Each TWAP has its **own** appData hash derived on-chain from the registration block timestamp
(the salt), with the 0.2% partner fee baked in — do **not** use the static `APP_DATA()`. The
hash is stored as the final field of the struct, so read it straight from `twapOrders`:

```bash
# TwapParams: (address sellToken, address buyToken, uint256 sellAmountPerPart,
#   uint256 buyAmountMinPerPart, uint32 startTime, uint32 partDuration, uint32 span,
#   uint32 n, bytes32 appData)
TWAP_PARAMS=$(cast call $CLONE "twapOrders(bytes32)(address,address,uint256,uint256,uint32,uint32,uint32,uint32,bytes32)" \
  "$TWAP_ID" --rpc-url "$RPC")
```

Parse the output to extract: sell_token, buy_token, sell_amount_per_part, buy_amount_min,
start_time, part_duration, span, n, **app_data** (the last field).

```bash
APP_DATA=<app_data>
```

Re-register the fee document with CoW (idempotent — safe to repeat every part). The salt equals
`start_time` (both are the registration block.timestamp; `uint32(block.timestamp)` doesn't
truncate before year 2106), so the document rebuilds byte-identically:

```bash
FULL_APP_DATA='{"appCode":"BittyVault","environment":"'"<start_time>"'","metadata":{"partnerFee":{"bps":20,"recipient":"0x12EE2de7BF086388B1D560eb95e7191Edfab9823"}},"version":"1.3.0"}'

# Sanity check: the rebuilt hash MUST equal the stored appData, else params were misparsed.
REBUILT=$(cast keccak "$FULL_APP_DATA")
[ "$REBUILT" = "$APP_DATA" ] || { echo "Error: rebuilt appData $REBUILT != stored $APP_DATA — aborting."; exit 1; }

APP_DATA_BODY=$(python3 -c "import json,sys; print(json.dumps({'fullAppData': sys.argv[1]}))" "$FULL_APP_DATA")
curl -s -X PUT "https://api.cow.fi/mainnet/api/v1/app_data/$APP_DATA" \
  -H "Content-Type: application/json" -d "$APP_DATA_BODY" >/dev/null
```

Compute current part details:

```bash
VALID_TO=$(python3 -c "
import time
now = int(time.time())
# Parse these from TWAP_PARAMS
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

### 6. Show result

```
TWAP part posted!
  TWAP ID       : <TWAP_ID>
  CoW Order UID : <COW_UID>
  Valid until   : <human_readable_expiry>
  CoW Explorer  : https://explorer.cow.fi/orders/<COW_UID>

Run /post-twap-part <TWAP_ID> again at the next interval window.
```
