Stake WETH from a BittyVault into the Lido staking protocol on Sepolia (the vault receives stETH).

**Usage:** `/stake <asset> <amount>`

- `<asset>` — `WETH` (`0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9`); Lido takes nothing else
- `<amount>` — human-readable amount (e.g. `0.5`), or `max` for the vault's full WETH balance

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as two parts: asset, amount.
If any are missing, stop and print: "Usage: /stake <asset> <amount>"

---

## Steps

### 1. Check environment and resolve the staking protocol

```bash
: "${PRIVATE_KEY:?PRIVATE_KEY is not set — run /new-assetmanager first}"
: "${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
WETH=0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9
GUARD=$(cast call $VAULT_ADDRESS "guard()(address)" --rpc-url "<rpc_url>")
for p in $(cast call $GUARD "getProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[],'); do
  [ "$(cast call $GUARD "protocolCategory(address)(uint8)" $p --rpc-url "<rpc_url>")" = 1 ] && STAKING_PROTOCOL=$p
done
cast call $VAULT_ADDRESS "isProtocolAllowed(address)(bool)" $STAKING_PROTOCOL --rpc-url "<rpc_url>"
```

If `<asset>` is not WETH, stop: "Lido only stakes WETH."

### 2. Resolve the amount

```bash
cast call $WETH "balanceOf(address)(uint256)" $VAULT_ADDRESS --rpc-url "<rpc_url>"
```

`max` → the full balance; otherwise `cast to-unit <amount>ether wei`. Stop if the balance is short.

### 3. Read the current stake

```bash
cast call $VAULT_ADDRESS "getBalances(address[],address[])(uint256[])" \
  "[$STAKING_PROTOCOL]" "[$WETH]" --rpc-url "<rpc_url>"
```

Save as `<staked_before>` (stETH, 18 decimals).

### 4. Preview and confirm

Print vault, amount and `<staked_before>`. Ask: "Proceed with stake? (yes/no)"

### 5. Deposit

```bash
cast send $VAULT_ADDRESS "deposit(address,address,uint256)" \
  $STAKING_PROTOCOL $WETH <amount_raw> \
  --rpc-url "<rpc_url>" --private-key "$PRIVATE_KEY"
```

`OwnableUnauthorizedAccount` means this key lacks `PERM_YIELD` or its grant has expired.

### 6. Show result

Re-run step 3 and print:
```
Stake successful!
  Tx       : https://sepolia.etherscan.io/tx/<tx_hash>
  Staked   : <amount> WETH
  stETH    : <staked_before> → <staked_after> (wei)
```
