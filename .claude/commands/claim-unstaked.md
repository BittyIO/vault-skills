Claim finalized unstake requests from the Lido staking protocol into a BittyVault on Sepolia.

**Usage:** `/claim-unstaked [request_id_1] [request_id_2] ...`

- `[request_ids]` — optional. If omitted, every pending request id of the vault is claimed.

Arguments: $ARGUMENTS

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

### 2. Resolve the ids

```bash
cast call $VAULT_ADDRESS "getPendingWithdrawalIds(address)(uint256[])" $STAKING_PROTOCOL --rpc-url "<rpc_url>"
```

Use the ids from `$ARGUMENTS` if given (each must be in this list), otherwise all of them. If the list
is empty, stop: "No pending unstake requests."

### 3. Preview and confirm

```bash
WETH_BEFORE=$(cast call $WETH "balanceOf(address)(uint256)" $VAULT_ADDRESS --rpc-url "<rpc_url>")
```

Print the ids and the vault's WETH balance. Ask: "Claim these requests? (yes/no)"

### 4. Claim

```bash
cast send $VAULT_ADDRESS "claimWithdrawals(address,uint256[])" \
  $STAKING_PROTOCOL "[<id1>,<id2>,...]" \
  --rpc-url "<rpc_url>" --private-key "$PRIVATE_KEY"
```

The Lido adapter claims only the requests that are finalized and leaves the rest pending.

### 5. Show result

Re-read the WETH balance and the pending ids, then print:
```
Claim complete!
  Tx           : https://sepolia.etherscan.io/tx/<tx_hash>
  Vault WETH   : <before> → <after> (wei)
  Still pending: <ids or none>
```

If nothing changed, the requests are not finalized yet — try again later.
