Return assets from a BittyVault **sub-vault** back to its parent vault, as the **sub owner**, on Sepolia. Returning to the parent is the only way value ever leaves a sub-account.

**Usage:** `/return-to-vault <asset> <amount|max> [<asset> <amount|max> ...]`

- `<asset>` — token symbol (WETH, WBTC, USDT, USDC) or a raw `0x…` address
- `<amount>` — human-readable amount (e.g. `1.5` for 1.5 WETH), or `max` to return the sub-vault's full balance of that asset
- Repeat the `<asset> <amount>` pair to return several assets in one call.

Here `$VAULT_ADDRESS` is the **sub-vault** address, and `$PRIVATE_KEY` is the **sub owner's** key (the sub owner is `owner()` of the sub-vault).

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as one or more `<asset> <amount>` pairs.
If no complete pair is given, stop and print: "Usage: /return-to-vault <asset> <amount|max> [<asset> <amount|max> ...]"

---

## Hardcoded Sepolia configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 |
| USDC | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` | 6 |

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set — the sub owner's key}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — set it to the SUB-VAULT address}"
```

### 2. Resolve each asset address and decimals

For each pair, if `<asset>` matches a known symbol (case-insensitive), use the table above.
If `<asset>` starts with `0x`, use it directly — then fetch its decimals:

```bash
cast call <asset_address> "decimals()(uint8)" \
  --rpc-url "<rpc_url>"
```

### 3. Check the sub-vault's balance for each asset

```bash
cast call <asset_address> \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

Save each as `<sub_balance>`.

If a `<sub_balance>` is 0, stop and print:
```
Error: Sub-vault has no <asset_symbol> balance to return.
```

### 4. Resolve each amount to raw units

- If `<amount>` is `max`, set `<amount_raw>` = that asset's `<sub_balance>`.
- If 18 decimals: `cast to-unit <amount>ether wei`
- Other decimals: compute `<amount> * 10^<decimals>` as an integer

If any `<amount_raw>` > that asset's `<sub_balance>`, stop and print:
```
Error: Return amount exceeds sub-vault balance for <asset_symbol>.
  Sub-vault balance : <sub_balance> (raw)
  Requested         : <amount_raw> (raw)
```

### 5. Read the parent vault address

```bash
cast call $VAULT_ADDRESS "vault()(address)" --rpc-url "<rpc_url>"
```

Save as `<parent_vault>`.

### 6. Show preview and ask for confirmation

Print:
```
Sub-vault    : $VAULT_ADDRESS
Parent vault : <parent_vault>
Returning:
  <asset_symbol> : <amount> (<amount_raw> raw)
  ...
```

Ask: "Return these assets to the parent vault? (yes/no)"
If no, stop.

### 7. Call returnToVault on the sub-vault

Build the address and amount arrays in the same order as the parsed pairs:

```bash
cast send $VAULT_ADDRESS \
  "returnToVault(address[],uint256[])" \
  "[<addr>,...]" \
  "[<raw>,...]" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop. Common reasons:
- `NotSubOwner()` — this key is not the sub owner and the grant has not lapsed
- `ArrayLengthMismatch()` — the asset and amount arrays differ in length

### 8. Verify and show result

For each returned asset, check the sub-vault's remaining balance:

```bash
cast call <asset_address> \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

Print a final summary:
```
Return successful!
  Tx hash      : <tx_hash>
  Etherscan    : https://sepolia.etherscan.io/tx/<tx_hash>
  Parent vault : <parent_vault>
  Returned:
    <asset_symbol> : <amount> — sub-vault balance now <sub_balance_after> (raw)
    ...
```
