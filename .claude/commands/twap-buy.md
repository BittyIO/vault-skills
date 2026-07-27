Create a CoW Swap TWAP buy (DCA) order on a BittyVault on Sepolia. Spends `sell_per_part` of the sell token every `interval` seconds across `n_parts` parts, accumulating at least `total_buy / n_parts` of the buy token per slot.

Under the hood this is a sell TWAP: totalSellAmount = sell_per_part × n_parts, minPartLimit = total_buy / n_parts. Part 0 is posted immediately; post each subsequent slot at its window with `/post-twap-part`.

**Usage:** `/twap-buy <from_asset> <to_asset> <total_buy> <sell_per_part> <n_parts> <interval> [span]`

- `<from_asset>` — token to spend: symbol (WETH, WBTC, USDT, USDC) or `0x…`
- `<to_asset>` — token to accumulate: symbol or `0x…`
- `<total_buy>` — minimum total receive across all parts (human-readable)
- `<sell_per_part>` — sell amount per part (budget per slot)
- `<n_parts>` — number of DCA intervals (e.g. `30` for daily over a month)
- `<interval>` — seconds between parts (e.g. `86400` for daily)
- `[span]` — valid execution window per slot in seconds (0 = full slot, default)

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as positional: from, to, total_buy, sell_per_part, n, interval, optional span (default 0).
If first 6 are missing, stop and print usage.

---

## Hardcoded Sepolia configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` | 6 |

CoW Swap intent protocol: resolved from the vault on-chain (see step 2).

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set}"
```

### 2. Set intent protocol and verify registration

```bash
INTENT_PROTOCOL=$(cast call $VAULT_ADDRESS "getIntentProtocols()(address[])" \
  --rpc-url "<rpc_url>" | tr -d '[] ' | cut -d, -f1)
```

If `$INTENT_PROTOCOL` is empty, stop: "Error: no CoW Swap protocol registered on this vault. Ask the vault owner to add it via the web app (Manage → Protocols)."

### 3. Resolve asset addresses and decimals

Match symbols against the table. If raw address, fetch decimals:

```bash
cast call <address> "decimals()(uint8)" --rpc-url "<rpc_url>"
```

### 4. Convert amounts to raw units

- `<total_buy_raw>` in to-asset decimals
- `<sell_per_part_raw>` in from-asset decimals

### 5. Compute derived values and validate

```
total_sell_raw   = sell_per_part_raw * n_parts
min_part_limit   = total_buy_raw / n_parts  (floor division)
```

Stop if:
- `n_parts == 0` or `interval == 0`
- `min_part_limit == 0` (total_buy too small relative to n_parts)

### 6. Check vault balance

```bash
cast call <from_asset_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

If balance < `total_sell_raw`, stop with an insufficient balance error.

### 7. Show preview and ask for confirmation

```
CoW Swap TWAP buy (DCA) order
Vault              : $VAULT_ADDRESS
Buy (min total)    : <total_buy> <to_symbol> (~<total_buy/n_parts> per part)
Spend per part     : <sell_per_part> <from_symbol>
Total spend (max)  : <sell_per_part * n_parts> <from_symbol>
Parts              : <n_parts>
Interval           : <interval>s (<human interval>)
Span               : <span>s execution window (0 = full slot)
Total duration     : ~<human duration>
Intent protocol    : $INTENT_PROTOCOL
```

Ask: "Create TWAP buy order? (yes/no)" — if no, stop.

### 8. Simulate to get twapId, then call twapBuy on the vault

```bash
RPC="<rpc_url>"
ASSET_MANAGER=$(cast wallet address --private-key "$PRIVATE_KEY")

TWAP_ID=$(cast call $VAULT_ADDRESS \
  "twapBuy(address,address,address,uint256,uint256,uint256,uint256,uint256)(bytes32)" \
  "$INTENT_PROTOCOL" "<from_asset_address>" "<to_asset_address>" \
  "<total_buy_raw>" "<sell_per_part_raw>" "<n_parts>" "<interval>" "<span>" \
  --from "$ASSET_MANAGER" --rpc-url "$RPC")

TX_HASH=$(cast send $VAULT_ADDRESS \
  "twapBuy(address,address,address,uint256,uint256,uint256,uint256,uint256)" \
  "$INTENT_PROTOCOL" "<from_asset_address>" "<to_asset_address>" \
  "<total_buy_raw>" "<sell_per_part_raw>" "<n_parts>" "<interval>" "<span>" \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" \
  --json | python3 -c "import json,sys; print(json.load(sys.stdin)['transactionHash'])")
```

### 8b. Derive the per-TWAP appData from the mined block and register it with CoW

The protocol clone derived a per-TWAP appData hash **on-chain** from the registration block's
timestamp (the salt), with the 0.2% partner fee baked in — a user cannot strip the fee. Read
that exact timestamp, rebuild the byte-identical document, hash it, and PUT it to CoW.

```bash
BLOCK_NUM=$(cast receipt "$TX_HASH" blockNumber --rpc-url "$RPC")
BLOCK_TS=$(cast block "$BLOCK_NUM" -f timestamp --rpc-url "$RPC")

# MUST be byte-identical to the contract's twapFullAppData(salt): same key order, compact
# spacing, checksummed recipient (0x12EE2de7…). The salt rides in the free-form `environment`.
FULL_APP_DATA='{"appCode":"BittyVault","environment":"'"$BLOCK_TS"'","metadata":{"partnerFee":{"bps":20,"recipient":"0x12EE2de7BF086388B1D560eb95e7191Edfab9823"}},"version":"1.3.0"}'
APP_DATA=$(cast keccak "$FULL_APP_DATA")

APP_DATA_BODY=$(python3 -c "import json,sys; print(json.dumps({'fullAppData': sys.argv[1]}))" "$FULL_APP_DATA")
curl -s -X PUT "https://api.cow.fi/sepolia/api/v1/app_data/$APP_DATA" \
  -H "Content-Type: application/json" -d "$APP_DATA_BODY" >/dev/null
```

### 9. Post part 0 to CoW API immediately

twapBuy is a sell TWAP under the hood: sell `sell_per_part_raw` of the from-asset per slot,
receive at least `min_part_limit = total_buy_raw / n_parts` of the to-asset. Part 0's validTo
MUST come from the block timestamp (the on-chain part hash uses `blockTimestamp + effectiveSpan`).

```bash
MIN_PART_LIMIT=$(python3 -c "print(<total_buy_raw> // <n_parts>)")
EFFECTIVE_SPAN=$(python3 -c "s=<span>; d=<interval>; print(s if s > 0 else d)")
PART0_VALID_TO=$(python3 -c "print($BLOCK_TS + $EFFECTIVE_SPAN)")

JSON_BODY=$(python3 -c "
import json
print(json.dumps({
    'sellToken': '<from_asset_address>',
    'buyToken': '<to_asset_address>',
    'receiver': '$VAULT_ADDRESS',
    'sellAmount': '<sell_per_part_raw>',
    'buyAmount': str($MIN_PART_LIMIT),
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

### 10. Show result

```
TWAP buy order created!
  Tx hash          : <tx_hash>
  Etherscan        : https://sepolia.etherscan.io/tx/<tx_hash>
  TWAP ID          : <TWAP_ID>
  Part 0 UID       : <COW_UID>
  Buy (min total)  : <total_buy> <to_symbol> over <n_parts> parts
  Spend per part   : <sell_per_part> <from_symbol>
  CoW Explorer     : https://explorer.cow.fi/sepolia/orders/<COW_UID>

To post subsequent parts when each window opens: /post-twap-part <TWAP_ID>
To cancel the TWAP: /cancel-twap <TWAP_ID>
```
