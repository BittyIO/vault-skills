Supply an asset from a BittyVault into the Aave lending protocol on Sepolia.

**Usage:** `/supply <asset> <amount>`

- `<asset>` — token symbol (WETH, WBTC, USDT, USDC) or a raw `0x…` address
- `<amount>` — human-readable amount (e.g. `1.5`), or `max` for the vault's full balance

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as two parts: asset, amount.
If any are missing, stop and print: "Usage: /supply <asset> <amount>"

---

## Sepolia tokens

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 |
| USDC | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` | 6 |

On Aave's Sepolia market only **WBTC** can be supplied: WETH and USDC have no reserve, and USDT is
over its supply cap (Aave error `51`). WBTC is Aave's test token — anyone can mint it straight into the
vault from Aave's Sepolia faucet:

```bash
cast send 0xC959483DBa39aa9E78757139af0e9a2EDEb3f42D "mint(address,address,uint256)" \
  0x29f2D40B0605204364af54EC677bD022dA425d03 $VAULT_ADDRESS 100000000 \
  --rpc-url "<rpc_url>" --private-key "$PRIVATE_KEY"   # 1 WBTC
```

---

## Steps

### 1. Check environment and resolve the lending protocol

```bash
: "${PRIVATE_KEY:?PRIVATE_KEY is not set — run /new-assetmanager first}"
: "${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
GUARD=$(cast call $VAULT_ADDRESS "guard()(address)" --rpc-url "<rpc_url>")
for p in $(cast call $GUARD "getProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[],'); do
  [ "$(cast call $GUARD "protocolCategory(address)(uint8)" $p --rpc-url "<rpc_url>")" = 2 ] && LENDING_PROTOCOL=$p
done
cast call $VAULT_ADDRESS "isProtocolAllowed(address)(bool)" $LENDING_PROTOCOL --rpc-url "<rpc_url>"
```

Guard categories: `1` staking, `2` lending, `3` market trade, `4` intent. If no lending protocol is
found or it is not allowed on this vault, stop and say so.

### 2. Resolve the asset and amount

Use the table above for symbols; for a raw address read `decimals()(uint8)`. Read the vault balance:

```bash
cast call <asset_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS --rpc-url "<rpc_url>"
```

`max` → the full balance. Otherwise `<amount_raw>` = `cast to-unit <amount>ether wei` for 18 decimals,
or `<amount> × 10^decimals` as an integer. If the balance is short, stop and show both numbers.

### 3. Read the current position

```bash
cast call $VAULT_ADDRESS "getBalances(address[],address[])(uint256[])" \
  "[$LENDING_PROTOCOL]" "[<asset_address>]" --rpc-url "<rpc_url>"
```

Save as `<supplied_before>`.

### 4. Preview and confirm

Print vault, asset, amount (human and raw), lending protocol and `<supplied_before>`.
Ask: "Proceed with supply? (yes/no)"

### 5. Deposit

```bash
cast send $VAULT_ADDRESS "deposit(address,address,uint256)" \
  $LENDING_PROTOCOL <asset_address> <amount_raw> \
  --rpc-url "<rpc_url>" --private-key "$PRIVATE_KEY"
```

On revert: `OwnableUnauthorizedAccount` means this key is not the owner or an unexpired manager with
`PERM_SUPPLY`; `VaultLocked` means the owner has locked the vault.

### 6. Show result

Re-run step 3 and print:
```
Supply successful!
  Tx        : https://sepolia.etherscan.io/tx/<tx_hash>
  Supplied  : <amount> <symbol>
  Position  : <supplied_before> → <supplied_after> (raw)
```
