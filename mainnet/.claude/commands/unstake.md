Request an unstake from the Lido staking protocol back into a BittyVault on Ethereum mainnet.

Note: Lido unstaking is a two-step process. This skill submits the unstake request and returns the request IDs.
Once the withdrawal period has passed, run `/claim-unstaked` to receive the funds.

**Usage:** `/unstake <asset> <amount>`

- `<asset>` — token symbol (WETH, WBTC, USDC, USDT, USDS) or a raw `0x…` address
- `<amount>` — human-readable amount (e.g. `1.5` for 1.5 WETH), or `max` to unstake the full staked balance

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as two parts: asset, amount.
If any are missing, stop and print: "Usage: /unstake <asset> <amount>"

---

## Hardcoded mainnet configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | 18 |
| WBTC | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` | 8 |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | 6 |
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` | 6 |
| USDS | `0xdC035D45d973E3EC169d2276DDab16f1e407384F` | 18 |

Staking protocol (Lido V2): `0x4115bB297f21247FC55FD6255f0F8800d4172AF7`

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
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

### 3. Fetch current staked balance

```bash
cast call $VAULT_ADDRESS \
  "getStakedBalance(address,address)(uint256)" \
  "0x4115bB297f21247FC55FD6255f0F8800d4172AF7" \
  "<asset_address>" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
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
  "0x4115bB297f21247FC55FD6255f0F8800d4172AF7" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Save as `<request_ids_before>`.

### 6. Show preview and ask for confirmation

Print:
```
⚠ This is Ethereum mainnet — real funds will be used.

Vault              : $VAULT_ADDRESS
Asset              : <asset_symbol> (<asset_address>)
Amount             : <amount> <asset_symbol> (<amount_raw> raw)
Staking protocol   : 0x4115bB297f21247FC55FD6255f0F8800d4172AF7
Staked balance     : <staked_balance> (raw)
Remaining staked   : <staked_balance - amount_raw> (raw)
Pending request IDs: <request_ids_before>

⚠ Lido withdrawal requires a waiting period (typically 1-5 days) before you can claim.
  Run /claim-unstaked once the request is finalized.
```

Ask: "Proceed with unstake request? (yes/no)"
If no, stop.

### 7. Call unstake on the vault

```bash
cast send $VAULT_ADDRESS \
  "unstake(address,address,uint256)" \
  "0x4115bB297f21247FC55FD6255f0F8800d4172AF7" \
  "<asset_address>" \
  "<amount_raw>" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 8. Fetch new pending request IDs (after)

```bash
cast call $VAULT_ADDRESS \
  "getUnstakeRequestIds(address)(uint256[])" \
  "0x4115bB297f21247FC55FD6255f0F8800d4172AF7" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Save as `<request_ids_after>`. The new IDs are those in `<request_ids_after>` that were not in `<request_ids_before>`.

### 9. Print final summary

```
Unstake request submitted!
  Tx hash          : <tx_hash>
  Etherscan        : https://etherscan.io/tx/<tx_hash>
  Amount requested : <amount> <asset_symbol>
  Staked before    : <staked_balance> (raw)
  New request IDs  : <new_request_ids>

When the withdrawal period is complete, run:
  /claim-unstaked <request_id_1> <request_id_2> ...
```
