Request an unstake from the Lido staking protocol back into a BittyVault on Sepolia.

**Usage:** `/unstake <asset> <amount>`

- `<asset>` — `WETH` (the asset that was staked)
- `<amount>` — human-readable stETH amount (e.g. `0.5`), or `max` for the full stake

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as two parts: asset, amount.
If any are missing, stop and print: "Usage: /unstake <asset> <amount>"

---

Lido exits are asynchronous: this opens a withdrawal request, and the ETH arrives later with
`/claim-unstaked` once Lido finalizes it. **On Sepolia the Lido withdrawal queue is paused**, so the
request reverts there.

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
```

### 2. Read the stake and resolve the amount

```bash
cast call $VAULT_ADDRESS "getBalances(address[],address[])(uint256[])" \
  "[$STAKING_PROTOCOL]" "[$WETH]" --rpc-url "<rpc_url>"
cast call $VAULT_ADDRESS "getPendingWithdrawalIds(address)(uint256[])" $STAKING_PROTOCOL --rpc-url "<rpc_url>"
```

Save the first as `<staked>`; if 0, stop. `max` → `<staked>`; otherwise `cast to-unit <amount>ether wei`,
capped by `<staked>`. Lido requires at least 100 wei per request.

### 3. Preview and confirm

Print vault, amount, `<staked>` and the already-pending request ids.
Ask: "Request unstake? (yes/no)"

### 4. Withdraw (opens the Lido request)

```bash
cast send $VAULT_ADDRESS "withdraw(address,address,uint256)" \
  $STAKING_PROTOCOL $WETH <amount_raw> \
  --rpc-url "<rpc_url>" --private-key "$PRIVATE_KEY"
```

### 5. Show result

Re-read both values from step 2 and print:
```
Unstake requested!
  Tx           : https://sepolia.etherscan.io/tx/<tx_hash>
  Requested    : <amount> stETH
  Pending ids  : <ids>
Claim once finalized with /claim-unstaked
```
