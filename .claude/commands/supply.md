Supply an asset from a BittyVault into the Aave lending protocol on Sepolia.

**Usage:** `/supply <asset> <amount>`

- `<asset>` — token symbol (WETH, WBTC, USDT, USDC) or a raw `0x…` address
- `<amount>` — human-readable amount (e.g. `1.5` for 1.5 WETH)

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as two parts: asset, amount.
If any are missing, stop and print: "Usage: /supply <asset> <amount>"

---

## Hardcoded Sepolia configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` | 6 |

Lending protocol: `0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436`

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Resolve asset address and decimals

If `<asset>` matches a known symbol (case-insensitive), use the table above.
If `<asset>` starts with `0x`, use it directly — then fetch its decimals:

```bash
cast call <asset_address> "decimals()(uint8)" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

### 3. Convert amount to token units (smallest unit / wei)

Use `cast to-unit` for 18-decimal tokens or multiply for others:

- 18 decimals: `cast to-unit <amount>ether wei` (this outputs integer wei)
- Other decimals: compute `<amount> * 10^<decimals>` as an integer (no decimals in result)

Save the result as `<amount_raw>`.

### 4. Check vault's token balance

```bash
cast call <asset_address> \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

If the balance is less than `<amount_raw>`, stop and print:
```
Error: Vault balance insufficient.
  Vault balance : <balance> (raw units)
  Requested     : <amount_raw> (raw units)
Deposit funds into the vault before supplying.
```

### 5. Check current supplied balance (before)

```bash
cast call $VAULT_ADDRESS \
  "getSuppliedBalance(address,address)(uint256)" \
  "0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436" \
  "<asset_address>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Save as `<supplied_before>`.

### 6. Show preview and ask for confirmation

Print:
```
Vault           : $VAULT_ADDRESS
Asset           : <asset_symbol> (<asset_address>)
Amount          : <amount> <asset_symbol> (<amount_raw> raw)
Lending protocol: 0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436
Currently supplied: <supplied_before> (raw)
```

Ask: "Proceed with supply? (yes/no)"
If no, stop.

### 7. Call supply on the vault

```bash
cast send $VAULT_ADDRESS \
  "supply(address,address,uint256)" \
  "0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436" \
  "<asset_address>" \
  "<amount_raw>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 8. Verify and show result

After the transaction confirms, fetch the new supplied balance:

```bash
cast call $VAULT_ADDRESS \
  "getSuppliedBalance(address,address)(uint256)" \
  "0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436" \
  "<asset_address>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print a final summary:
```
Supply successful!
  Tx hash          : <tx_hash>
  Etherscan        : https://sepolia.etherscan.io/tx/<tx_hash>
  Asset supplied   : <amount> <asset_symbol>
  Supplied before  : <supplied_before> (raw)
  Supplied after   : <supplied_after> (raw)
```
