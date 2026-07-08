Create a CoW Swap TWAP buy (DCA) order on a BittyVault on Sepolia. Spends `sell_per_part` of the sell token every `interval` seconds across `n_parts` parts, accumulating at least `total_buy / n_parts` of the buy token per slot.

Under the hood this is a sell TWAP: totalSellAmount = sell_per_part × n_parts, minPartLimit = total_buy / n_parts. CoW watchdog submits each slot automatically.

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

CoW Swap intent protocol (Sepolia): `0x480154016Bbc335Af34D0f5c75f3d0cbc17a2FfD`

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set}"
```

### 2. Set intent protocol and verify registration

```bash
INTENT_PROTOCOL=0x480154016Bbc335Af34D0f5c75f3d0cbc17a2FfD
cast call $VAULT_ADDRESS "getIntentProtocols()(address[])" \
  --rpc-url "<rpc_url>"
```

If `$INTENT_PROTOCOL` not in result, stop: "Error: CoW Swap protocol not registered. ask the vault owner to add it via the web app (Manage → Protocols)"

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

### 8. Call twapBuy on the vault

```bash
cast send $VAULT_ADDRESS \
  "twapBuy(address,address,address,uint256,uint256,uint256,uint256,uint256)(bytes32)" \
  "$INTENT_PROTOCOL" \
  "<from_asset_address>" \
  "<to_asset_address>" \
  "<total_buy_raw>" \
  "<sell_per_part_raw>" \
  "<n_parts>" \
  "<interval>" \
  "<span>" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

### 9. Show result

```
TWAP buy order created!
  Tx hash          : <tx_hash>
  Etherscan        : https://sepolia.etherscan.io/tx/<tx_hash>
  TWAP ID          : <twapId>
  Buy (min total)  : <total_buy> <to_symbol> over <n_parts> parts
  Spend per part   : <sell_per_part> <from_symbol>

Save the TWAP ID to cancel: /cancel-twap <twapId>
```
