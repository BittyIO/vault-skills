Claim finalized unstake requests from the Lido staking protocol into a BittyVault on Sepolia.

This is step 2 of the unstaking flow. Run this after `/unstake` once the Lido withdrawal period has passed.

**Usage:** `/claim-unstaked [request_id_1] [request_id_2] ...`

- `[request_ids]` — optional space-separated list of request IDs to claim. If omitted, all pending request IDs are fetched automatically from `$VAULT_ADDRESS` and claimed.

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as optional request IDs (all tokens).

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — set it in .env to a vault where your key holds a seat}"
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

### 2. Resolve request IDs

If request IDs were provided in `$ARGUMENTS`, use them as `<request_ids>`.

Otherwise fetch all pending IDs from the vault:

```bash
cast call $VAULT_ADDRESS \
  "getUnstakeRequestIds(address)(uint256[])" \
  "$STAKING_PROTOCOL" \
  --rpc-url "<rpc_url>"
```

If the result is an empty array, stop and print:
```
No pending unstake requests found for this vault.
Run /unstake first to queue a withdrawal.
```

Save the IDs as `<request_ids>` and format them as a Solidity-style array for cast: `[id1,id2,...]`.

### 3. Check vault WETH balance before (to measure what arrives)

Fetch the vault's WETH balance (Lido returns WETH on Sepolia):

```bash
cast call 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

Save as `<weth_before>`.

### 4. Show preview and ask for confirmation

Print:
```
Vault             : $VAULT_ADDRESS
Staking protocol  : $STAKING_PROTOCOL
Request IDs       : <request_ids>
Vault WETH balance: <weth_before> (raw)
```

Ask: "Proceed with claiming? (yes/no)"
If no, stop.

### 5. Call claimUnstaked on the vault

```bash
cast send $VAULT_ADDRESS \
  "claimUnstaked(address,uint256[])" \
  "$STAKING_PROTOCOL" \
  "<request_ids_array>" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 6. Verify and show result

Fetch vault WETH balance and remaining pending request IDs after the tx:

```bash
cast call 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

```bash
cast call $VAULT_ADDRESS \
  "getUnstakeRequestIds(address)(uint256[])" \
  "$STAKING_PROTOCOL" \
  --rpc-url "<rpc_url>"
```

Print a final summary:
```
Claim successful!
  Tx hash              : <tx_hash>
  Etherscan            : https://sepolia.etherscan.io/tx/<tx_hash>
  Claimed request IDs  : <request_ids>
  Vault WETH before    : <weth_before> (raw)
  Vault WETH after     : <weth_after> (raw)
  WETH received        : <weth_after - weth_before> (raw)
  Remaining request IDs: <remaining_ids or "none">
```
