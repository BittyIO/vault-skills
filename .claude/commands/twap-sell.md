Create a CoW Swap TWAP sell order on a BittyVault on Sepolia. Splits the total sell amount into n equal parts executed at regular intervals. After registration you must post each part to CoW API when its window opens using `/post-twap-part`.

**Usage:** `/twap-sell <from_asset> <to_asset> <total_sell> <min_per_part> <n_parts> <interval> [span]`

- `<from_asset>` — token to sell: symbol (WETH, WBTC, USDT, USDC) or `0x…`
- `<to_asset>` — token to receive: symbol or `0x…`
- `<total_sell>` — total amount to sell across all parts (human-readable)
- `<min_per_part>` — minimum receive amount per part (slippage floor per slot)
- `<n_parts>` — number of parts (e.g. `7` for daily over a week)
- `<interval>` — seconds between parts (e.g. `86400` for daily, `3600` for hourly)
- `[span]` — execution window per slot in seconds (0 = full interval, default)

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as positional: from, to, total_sell, min_per_part, n, interval, optional span (default 0).
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
CoW Swap explorer (Sepolia): `https://explorer.cow.fi/sepolia/`

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

### 3. Get clone address

```bash
CLONE=$(cast call $VAULT_ADDRESS "getClone(address)(address)" "$INTENT_PROTOCOL" --rpc-url "$RPC")
```

> **Note on appData (fee enforcement).** Unlike limit orders, a TWAP does **not** use the
> static `APP_DATA()`. The protocol clone derives a per-TWAP appData hash **on-chain** from
> the block timestamp of the registration tx (the salt), with the 0.2% partner fee baked in —
> a user cannot strip the fee. After the tx is mined we reconstruct the byte-identical
> `fullAppData` document from that block's timestamp, register it with CoW, and post each part
> with the derived hash (steps 8b–9).

### 4. Resolve asset addresses and decimals

Match symbols against the table. If raw address, fetch decimals:

```bash
cast call <address> "decimals()(uint8)" --rpc-url "$RPC"
```

### 5. Convert amounts to raw units and validate

- `<total_sell_raw>` and `<min_per_part_raw>` in token decimals
- Example (18d): `cast to-unit <amount>ether wei`
- Example (6d): `python3 -c "print(int(<amount> * 1e6))"`
- Validate: `<n_parts>` > 0, `<interval>` > 0, `total_sell_raw / n_parts` > 0

### 6. Check vault balance

```bash
cast call <from_asset_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS --rpc-url "$RPC"
```

If balance < `<total_sell_raw>`, stop with an insufficient balance error.

### 7. Show preview and ask for confirmation

```
CoW Swap TWAP sell order
Vault            : $VAULT_ADDRESS
Sell total       : <total_sell> <from_symbol> (split into <n_parts> parts)
Sell per part    : <total_sell/n_parts> <from_symbol>
Receive (min/part): <min_per_part> <to_symbol>
Interval         : <interval>s between parts
Span             : <span>s execution window per slot (0 = full slot)
Total duration   : ~<human duration>
Intent protocol  : $INTENT_PROTOCOL
```

Ask: "Create TWAP sell order? (yes/no)" — if no, stop.

### 8. Simulate to get twapId, then execute on-chain

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

### 8b. Derive the per-TWAP appData from the mined block and register it with CoW

The contract used the registration block's timestamp as the appData salt. Read that exact
timestamp, rebuild the byte-identical fee-bearing document, hash it, and PUT it to CoW so
solvers can resolve the hash and apply the partner fee.

```bash
# Block timestamp of the registration tx = the on-chain appData salt.
BLOCK_NUM=$(cast receipt "$TX_HASH" blockNumber --rpc-url "$RPC")
BLOCK_TS=$(cast block "$BLOCK_NUM" -f timestamp --rpc-url "$RPC")

# MUST be byte-identical to the contract's twapFullAppData(salt): same key order, compact
# spacing, checksummed recipient (0x12EE2de7…). The salt rides in the free-form `environment`.
FULL_APP_DATA='{"appCode":"BittyVault","environment":"'"$BLOCK_TS"'","metadata":{"partnerFee":{"bps":20,"recipient":"0x12EE2de7BF086388B1D560eb95e7191Edfab9823"}},"version":"1.3.0"}'

# keccak256 of the UTF-8 string — matches the contract's keccak256(bytes(...)).
APP_DATA=$(cast keccak "$FULL_APP_DATA")

# Register the document (idempotent). Body must JSON-escape the raw string.
APP_DATA_BODY=$(python3 -c "import json,sys; print(json.dumps({'fullAppData': sys.argv[1]}))" "$FULL_APP_DATA")
APP_DATA_REG=$(curl -s -X PUT "https://api.cow.fi/sepolia/api/v1/app_data/$APP_DATA" \
  -H "Content-Type: application/json" -d "$APP_DATA_BODY")
```

If the PUT returns an error body (anything other than the echoed hash / an empty 200), print
it and stop — the order would be rejected without a resolvable appData.

### 9. Post part 0 to CoW API immediately

```bash
# Part 0's validTo MUST be derived from the block timestamp (not wall-clock): the on-chain
# part hash uses validTo = blockTimestamp + effectiveSpan, so any drift → signature mismatch.
SELL_PER_PART=$(python3 -c "print(<total_sell_raw> // <n_parts>)")
EFFECTIVE_SPAN=$(python3 -c "s=<span>; d=<interval>; print(s if s > 0 else d)")
PART0_VALID_TO=$(python3 -c "print($BLOCK_TS + $EFFECTIVE_SPAN)")

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
TWAP sell created!
  Tx hash        : <tx_hash>
  Etherscan      : https://sepolia.etherscan.io/tx/<tx_hash>
  TWAP ID        : <TWAP_ID>
  Part 0 UID     : <COW_UID>
  Parts          : <n_parts> × <sell_per_part_human> <from_symbol>
  Interval       : <interval>s
  CoW Explorer   : https://explorer.cow.fi/sepolia/orders/<COW_UID>

To post subsequent parts when each window opens: /post-twap-part <TWAP_ID>
To cancel the TWAP: /cancel-twap <TWAP_ID>
```
