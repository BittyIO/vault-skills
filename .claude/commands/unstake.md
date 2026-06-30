Request an unstake from the Lido staking protocol back into a BittyVault on Sepolia.

Note: Lido unstaking is a two-step process. This skill submits the unstake request and returns the request IDs.
Once the withdrawal period has passed, run `/claim-unstaked` to receive the funds.

**Usage:** `/unstake <asset> <amount>`

- `<asset>` — token symbol (WETH, WBTC, USDT, USDC) or a raw `0x…` address
- `<amount>` — human-readable amount (e.g. `1.5` for 1.5 WETH), or `max` to unstake the full staked balance

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as two parts: asset, amount.
If any are missing, stop and print: "Usage: /unstake <asset> <amount>"

---

## Hardcoded Sepolia configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` | 6 |

Staking protocol: `0xAa83429F9ab50DA9F4bABEA6b66238f558A1550C`

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

### 3. Fetch current staked balance

```bash
cast call $VAULT_ADDRESS \
  "getStakedBalance(address,address)(uint256)" \
  "0xAa83429F9ab50DA9F4bABEA6b66238f558A1550C" \
  "<asset_address>" \
  --rpc-url "<rpc_url>"
```

Save as `<staked_balance>`.

If `<staked_balance>` is 0, stop and print:
```
Error: No staked balance for <asset_symbol> in this vault.
```

### 4. Resolve amount to raw units

- If `<amount>` is `max`, set `<amount_raw>` = `<staked_balance>`.
- If 18 decimals: `cast to-unit <amount>ether wei`
- Other decimals: compute `<amount> * 10^<decimals>` as an integer

If `<amount_raw>` > `<staked_balance>`, stop and print:
```
Error: Unstake amount exceeds staked balance.
  Staked balance : <staked_balance> (raw)
  Requested      : <amount_raw> (raw)
```

### 5. Check existing pending request IDs (before)

```bash
cast call $VAULT_ADDRESS \
  "getUnstakeRequestIds(address)(uint256[])" \
  "0xAa83429F9ab50DA9F4bABEA6b66238f558A1550C" \
  --rpc-url "<rpc_url>"
```

Save as `<request_ids_before>`.

### 6. Show preview and ask for confirmation

Print:
```
Vault              : $VAULT_ADDRESS
Asset              : <asset_symbol> (<asset_address>)
Amount             : <amount> <asset_symbol> (<amount_raw> raw)
Staking protocol   : 0xAa83429F9ab50DA9F4bABEA6b66238f558A1550C
Staked balance     : <staked_balance> (raw)
Remaining staked   : <staked_balance - amount_raw> (raw)
Pending request IDs: <request_ids_before>

⚠ Lido withdrawal requires a waiting period before you can claim.
  Run /claim-unstaked once the request is finalized.
```

Ask: "Proceed with unstake request? (yes/no)"
If no, stop.

### 7. Call unstake on the vault

```bash
cast send $VAULT_ADDRESS \
  "unstake(address,address,uint256)" \
  "0xAa83429F9ab50DA9F4bABEA6b66238f558A1550C" \
  "<asset_address>" \
  "<amount_raw>" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 8. Fetch new pending request IDs (after)

```bash
cast call $VAULT_ADDRESS \
  "getUnstakeRequestIds(address)(uint256[])" \
  "0xAa83429F9ab50DA9F4bABEA6b66238f558A1550C" \
  --rpc-url "<rpc_url>"
```

Save as `<request_ids_after>`. The new IDs are those in `<request_ids_after>` that were not in `<request_ids_before>`.

### 9. Print final summary

```
Unstake request submitted!
  Tx hash          : <tx_hash>
  Etherscan        : https://sepolia.etherscan.io/tx/<tx_hash>
  Amount requested : <amount> <asset_symbol>
  Staked before    : <staked_balance> (raw)
  New request IDs  : <new_request_ids>

When the withdrawal period is complete, run:
  /claim-unstaked $VAULT_ADDRESS <request_id_1> <request_id_2> ...
```
