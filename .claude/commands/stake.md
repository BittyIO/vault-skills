Stake an asset from a BittyVault into the Lido staking protocol on Sepolia.

**Usage:** `/stake <asset> <amount>`

- `<asset>` — token symbol (WETH, WBTC, USDT, USDC) or a raw `0x…` address
- `<amount>` — human-readable amount (e.g. `1.5` for 1.5 WETH), or `max` to stake the full vault balance

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as two parts: asset, amount.
If any are missing, stop and print: "Usage: /stake <asset> <amount>"

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
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### Resolve the Lido staking protocol

A vault may have multiple staking protocols registered (e.g. Lido and Sky). Read them from the vault on-chain and pick the Lido one — identified because only the Lido protocol responds to `stETH()`:

```bash
STAKING_PROTOCOL=""
for p in $(cast call $VAULT_ADDRESS "getStakingProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[]' | tr ',' ' '); do
  if cast call "$p" "stETH()(address)" --rpc-url "<rpc_url>" >/dev/null 2>&1; then STAKING_PROTOCOL="$p"; break; fi
done
```

If `$STAKING_PROTOCOL` is empty, stop and print:
```
Error: no Lido staking protocol registered on this vault.
```

### 2. Resolve asset address and decimals

If `<asset>` matches a known symbol (case-insensitive), use the table above.
If `<asset>` starts with `0x`, use it directly — then fetch its decimals:

```bash
cast call <asset_address> "decimals()(uint8)" \
  --rpc-url "<rpc_url>"
```

### 3. Check vault's token balance

```bash
cast call <asset_address> \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

Save as `<vault_balance>`.

If `<vault_balance>` is 0, stop and print:
```
Error: Vault has no <asset_symbol> balance to stake.
Deposit funds into the vault first.
```

### 4. Resolve amount to raw units

- If `<amount>` is `max`, set `<amount_raw>` = `<vault_balance>`.
- If 18 decimals: `cast to-unit <amount>ether wei`
- Other decimals: compute `<amount> * 10^<decimals>` as an integer

If `<amount_raw>` > `<vault_balance>`, stop and print:
```
Error: Stake amount exceeds vault balance.
  Vault balance : <vault_balance> (raw)
  Requested     : <amount_raw> (raw)
```

### 5. Check current staked balance (before)

```bash
cast call $VAULT_ADDRESS \
  "getStakedBalance(address,address)(uint256)" \
  "$STAKING_PROTOCOL" \
  "<asset_address>" \
  --rpc-url "<rpc_url>"
```

Save as `<staked_before>`.

### 6. Show preview and ask for confirmation

Print:
```
Vault            : $VAULT_ADDRESS
Asset            : <asset_symbol> (<asset_address>)
Amount           : <amount> <asset_symbol> (<amount_raw> raw)
Staking protocol : $STAKING_PROTOCOL
Vault balance    : <vault_balance> (raw)
Currently staked : <staked_before> (raw)
```

Ask: "Proceed with staking? (yes/no)"
If no, stop.

### 7. Call stake on the vault

```bash
cast send $VAULT_ADDRESS \
  "stake(address,address,uint256)" \
  "$STAKING_PROTOCOL" \
  "<asset_address>" \
  "<amount_raw>" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 8. Verify and show result

Fetch the new staked balance after the tx:

```bash
cast call $VAULT_ADDRESS \
  "getStakedBalance(address,address)(uint256)" \
  "$STAKING_PROTOCOL" \
  "<asset_address>" \
  --rpc-url "<rpc_url>"
```

Also check remaining vault balance:

```bash
cast call <asset_address> \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

Print a final summary:
```
Stake successful!
  Tx hash          : <tx_hash>
  Etherscan        : https://sepolia.etherscan.io/tx/<tx_hash>
  Asset staked     : <amount> <asset_symbol>
  Staked before    : <staked_before> (raw)
  Staked after     : <staked_after> (raw)
  Vault balance    : <vault_balance_after> (raw)
```
