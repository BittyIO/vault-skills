Withdraw a supplied asset from the Aave lending protocol back into a BittyVault on Sepolia.

**Usage:** `/withdraw <asset> <amount>`

- `<asset>` — token symbol (WETH, WBTC, USDT, USDC) or a raw `0x…` address
- `<amount>` — human-readable amount (e.g. `1.5` for 1.5 WETH), or `max` to withdraw everything

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as two parts: asset, amount.
If any are missing, stop and print: "Usage: /withdraw <asset> <amount>"

---

## Hardcoded Sepolia configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` | 6 |

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — set it in .env to a vault where your key holds a seat}"
```

Then resolve the lending protocol registered on the vault:

```bash
LENDING_PROTOCOL=$(cast call $VAULT_ADDRESS "getLendingProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[] ' | cut -d, -f1)
```

If `$LENDING_PROTOCOL` is empty, stop: `Error: no Aave lending protocol registered on this vault.`

### 2. Resolve asset address and decimals

If `<asset>` matches a known symbol (case-insensitive), use the table above.
If `<asset>` starts with `0x`, use it directly — then fetch its decimals:

```bash
cast call <asset_address> "decimals()(uint8)" \
  --rpc-url "<rpc_url>"
```

### 3. Fetch current supplied balance

```bash
cast call $VAULT_ADDRESS \
  "getSuppliedBalance(address,address)(uint256)" \
  "$LENDING_PROTOCOL" \
  "<asset_address>" \
  --rpc-url "<rpc_url>"
```

Save as `<supplied_balance>`.

If `<supplied_balance>` is 0, stop and print:
```
Error: No supplied balance for <asset_symbol> in this vault.
```

### 4. Resolve amount to raw units

- If `<amount>` is `max`, set `<amount_raw>` = `<supplied_balance>`.
- If 18 decimals: `cast to-unit <amount>ether wei`
- Other decimals: compute `<amount> * 10^<decimals>` as an integer

If `<amount_raw>` > `<supplied_balance>`, stop and print:
```
Error: Withdrawal amount exceeds supplied balance.
  Supplied balance : <supplied_balance> (raw)
  Requested        : <amount_raw> (raw)
```

### 5. Show preview and ask for confirmation

Print:
```
Vault             : $VAULT_ADDRESS
Asset             : <asset_symbol> (<asset_address>)
Amount            : <amount> <asset_symbol> (<amount_raw> raw)
Lending protocol  : $LENDING_PROTOCOL
Supplied balance  : <supplied_balance> (raw)
Remaining after   : <supplied_balance - amount_raw> (raw)
```

Ask: "Proceed with withdrawal? (yes/no)"
If no, stop.

### 6. Call withdraw on the vault

```bash
cast send $VAULT_ADDRESS \
  "withdraw(address,address,uint256)" \
  "$LENDING_PROTOCOL" \
  "<asset_address>" \
  "<amount_raw>" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 7. Verify and show result

Fetch the new supplied balance and vault token balance after the tx:

```bash
cast call $VAULT_ADDRESS \
  "getSuppliedBalance(address,address)(uint256)" \
  "$LENDING_PROTOCOL" \
  "<asset_address>" \
  --rpc-url "<rpc_url>"
```

```bash
cast call <asset_address> \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

Print a final summary:
```
Withdrawal successful!
  Tx hash          : <tx_hash>
  Etherscan        : https://sepolia.etherscan.io/tx/<tx_hash>
  Asset withdrawn  : <amount> <asset_symbol>
  Supplied before  : <supplied_balance> (raw)
  Supplied after   : <supplied_after> (raw)
  Vault balance    : <vault_balance> (raw)
```
