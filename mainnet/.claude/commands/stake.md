Stake an asset from a BittyVault into the Lido staking protocol on Ethereum mainnet.

**Usage:** `/stake <asset> <amount>`

- `<asset>` — token symbol (WETH, WBTC, USDC, USDT, USDS) or a raw `0x…` address
- `<amount>` — human-readable amount (e.g. `1.5` for 1.5 WETH), or `max` to stake the full vault balance

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as two parts: asset, amount.
If any are missing, stop and print: "Usage: /stake <asset> <amount>"

---

## Hardcoded mainnet configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | 18 |
| WBTC | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` | 8 |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | 6 |
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` | 6 |
| USDS | `0xdC035D45d973E3EC169d2276DDab16f1e407384F` | 18 |

Staking protocol (Lido V2): `0x68ED00Bd31E64ae77c19F9712dd1B27d4AA083b9`

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
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
  "0x68ED00Bd31E64ae77c19F9712dd1B27d4AA083b9" \
  "<asset_address>" \
  --rpc-url "<rpc_url>"
```

Save as `<staked_before>`.

### 6. Show preview and ask for confirmation

Print:
```
⚠ This is Ethereum mainnet — real funds will be used.

Vault            : $VAULT_ADDRESS
Asset            : <asset_symbol> (<asset_address>)
Amount           : <amount> <asset_symbol> (<amount_raw> raw)
Staking protocol : 0x68ED00Bd31E64ae77c19F9712dd1B27d4AA083b9
Vault balance    : <vault_balance> (raw)
Currently staked : <staked_before> (raw)
```

Ask: "Proceed with staking? (yes/no)"
If no, stop.

### 7. Call stake on the vault

```bash
cast send $VAULT_ADDRESS \
  "stake(address,address,uint256)" \
  "0x68ED00Bd31E64ae77c19F9712dd1B27d4AA083b9" \
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
  "0x68ED00Bd31E64ae77c19F9712dd1B27d4AA083b9" \
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
  Etherscan        : https://etherscan.io/tx/<tx_hash>
  Asset staked     : <amount> <asset_symbol>
  Staked before    : <staked_before> (raw)
  Staked after     : <staked_after> (raw)
  Vault balance    : <vault_balance_after> (raw)
```
