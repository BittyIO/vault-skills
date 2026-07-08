Create a CoW Swap TWAP buy (DCA) order on a BittyVault on Ethereum mainnet. Spends `sell_per_part` of the sell token every `interval` seconds across `n_parts` parts, accumulating at least `total_buy / n_parts` of the buy token per slot.

Under the hood this is a sell TWAP: totalSellAmount = sell_per_part × n_parts, minPartLimit = total_buy / n_parts.

**Usage:** `/twap-buy <from_asset> <to_asset> <total_buy> <sell_per_part> <n_parts> <interval> [span]`

- `<from_asset>` — token to spend: symbol (WETH, WBTC, USDT, USDC, USDS) or `0x…`
- `<to_asset>` — token to accumulate: symbol or `0x…`
- `<total_buy>` — minimum total receive across all parts (human-readable)
- `<sell_per_part>` — spend per slot (budget per interval)
- `<n_parts>` — number of DCA intervals (e.g. `30` for daily over a month)
- `<interval>` — seconds between parts (e.g. `86400` for daily)
- `[span]` — execution window per slot in seconds (0 = full slot, default)

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as positional: from, to, total_buy, sell_per_part, n, interval, optional span (default 0).
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

CoW Swap intent protocol (mainnet): `0xDf923AEFEe2Ac3a995C66f6998C52680154C56Ca`

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
INTENT_PROTOCOL=0xDf923AEFEe2Ac3a995C66f6998C52680154C56Ca
cast call $VAULT_ADDRESS "getIntentProtocols()(address[])" \
  --rpc-url "<rpc_url>"
```

If `$INTENT_PROTOCOL` not in result, stop: "Error: CoW Swap protocol not registered. ask the vault owner to add it via the web app (Manage → Protocols)"

### 3. Resolve assets and convert amounts

Match symbols against the table. If raw address, fetch decimals:

```bash
cast call <address> "decimals()(uint8)" --rpc-url "<rpc_url>"
```

Compute derived values:
```
total_sell_raw = sell_per_part_raw × n_parts
min_part_limit = total_buy_raw / n_parts  (floor division)
```

Stop if `min_part_limit == 0`.

### 4. Check vault balance

```bash
cast call <from_asset_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

If balance < `total_sell_raw`, stop with an insufficient balance error.

### 5. Show preview and ask for confirmation

```
⚠ CoW Swap TWAP buy (DCA) — MAINNET
Vault              : $VAULT_ADDRESS
Buy (min total)    : <total_buy> <to_symbol> (~<total_buy/n_parts> per part)
Spend per part     : <sell_per_part> <from_symbol>
Total spend (max)  : <sell_per_part × n_parts> <from_symbol>
Parts / interval   : <n_parts> × <interval>s (~<human duration> total)
Span               : <span>s per slot
Intent protocol    : $INTENT_PROTOCOL
```

Ask: "Create TWAP buy on MAINNET? (yes/no)" — if no, stop.

### 6. Call twapBuy on the vault

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

### 7. Show result

```
TWAP buy created!
  Tx hash          : <tx_hash>
  Etherscan        : https://etherscan.io/tx/<tx_hash>
  TWAP ID          : <twapId>
  Buy (min total)  : <total_buy> <to_symbol> over <n_parts> parts

Save the TWAP ID to cancel: /cancel-twap <twapId>
```
