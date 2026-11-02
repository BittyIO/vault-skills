Swap one asset for another inside a BittyVault at market, through the Uniswap Universal
Router adapter. The route (Uniswap v3/v4, best of the pools) is built by the Bitty API.

**Usage:** `/market-sell <from_asset> <to_asset> <sell_amount|max> [slippage_bps]`

- `<from_asset>` — token to sell: symbol (WETH, WBTC, USDC, USDT) or raw `0x…`
- `<to_asset>` — token to buy: symbol or raw `0x…`
- `<sell_amount>` — human-readable amount to sell, or `max` for the whole wallet balance
- `[slippage_bps]` — slippage tolerance in basis points, default `50` (0.5%), at most `500`

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: from_asset, to_asset, sell_amount, optional slippage_bps. If any of the
first three is missing, stop and print the usage line.

Run every command from the repo root.

---

## Steps

### 1. Preflight — needs the `MARKET_TRADE` permission (bit 4)

```bash
bin/bitty preflight 4
```

If it prints an `Error:`, show it and stop. Otherwise show its summary.

### 2. Resolve both assets and the amount

```bash
bin/bitty token <from_asset>
bin/bitty token <to_asset>
bin/bitty balance <from_address>
```

- `max` → the wallet balance; otherwise `bin/bitty raw <sell_amount> <from_decimals>`.
- Stop if the two tokens are the same, the amount is 0, or it exceeds the wallet balance.
- Stop if `slippage_bps` is not an integer from 0 to 500. (The vault itself refuses any trade that
  comes out more than 5% below oracle value.)

### 3. Pick the market-trade protocol

```bash
bin/bitty protocols trade
```

None → stop: `Error: no market-trade protocol is open to this vault on <network>.` Several → ask.

### 4. Quote a route

```bash
bin/bitty route <from_address> <to_address> <sell_amount_raw> <slippage_bps>
```

It prints JSON. Stop with the reason when it has `"error"`, or when `"route"` is `null`
(`Error: no Uniswap route for <from> → <to> at this size.`). Otherwise keep:
- `route` — the Universal Router route, passed to the vault as-is
- `receive` — expected amount to land in the vault, after the 0.2% swap fee
- `minReceive` — the floor: the swap reverts below it
- `hops` — for display

### 5. Preview and confirm

```
Market sell
  Vault        : <vault>
  Sell         : <sell_amount> <from_symbol>  (<sell_amount_raw> raw)
  Expect       : <receive, human> <to_symbol>
  At least     : <minReceive, human> <to_symbol>   (slippage <slippage_bps/100>%)
  Route        : <hops joined with " → ">
  Protocol     : <name> (<protocol>)
  Fee          : 0.2% (from the input when it is a stable coin, otherwise from the output)
```

Ask: "Swap? (yes/no)". Stop on anything but yes. The route expires (its `deadline`), so if the user
waits more than a few minutes, quote again.

### 6. Send

```bash
bin/bitty send "marketSell(address,address,uint256,address,uint256,bytes)" \
  <protocol> <from_address> <sell_amount_raw> <to_address> <minReceive> <route>
```

On a revert, show the reason and stop. Common ones:
- `InsufficientOutput` — the price moved past the slippage; quote again or allow more slippage.
- `MarketTradePriceTooLow` — the fill was more than 5% under oracle value; the vault refuses it.
- `MarketTradeExceedsDailyLossAllowance` — today's trading loss would pass the owner's daily
  loss allowance (at 0, market trading is off); try a smaller trade or wait for the day to clear.
- `MarketTradeNotSupported` — one of the tokens is not tradable at market on this guard.
- `NotRegistered` / `InvalidMarketTradeProtocol` — a token or the protocol is not on the vault's
  allow list.

### 7. Result

```bash
bin/bitty balance <from_address>
bin/bitty balance <to_address>
```

```
Swapped <sell_amount> <from_symbol> → <to_symbol>.
  Tx                : <hash and explorer link>
  <from_symbol> now : <human>
  <to_symbol> now   : <human>
```
