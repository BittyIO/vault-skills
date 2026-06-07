Claim finalized unstake requests from the Lido staking protocol into a BittyVault on Sepolia.

This is step 2 of the unstaking flow. Run this after `/unstake` once the Lido withdrawal period has passed.

**Usage:** `/claim-unstaked [request_id_1] [request_id_2] ...`

- `[request_ids]` — optional space-separated list of request IDs to claim. If omitted, all pending request IDs are fetched automatically from `$VAULT_ADDRESS` and claimed.

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as optional request IDs (all tokens).

---

## Hardcoded Sepolia configuration

Staking protocol: `0x2Db440cF6215d68d44736A287B253F4461399aa0`

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Resolve request IDs

If request IDs were provided in `$ARGUMENTS`, use them as `<request_ids>`.

Otherwise fetch all pending IDs from the vault:

```bash
cast call $VAULT_ADDRESS \
  "getUnstakeRequestIds(address)(uint256[])" \
  "0x2Db440cF6215d68d44736A287B253F4461399aa0" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
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
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Save as `<weth_before>`.

### 4. Show preview and ask for confirmation

Print:
```
Vault             : $VAULT_ADDRESS
Staking protocol  : 0x2Db440cF6215d68d44736A287B253F4461399aa0
Request IDs       : <request_ids>
Vault WETH balance: <weth_before> (raw)
```

Ask: "Proceed with claiming? (yes/no)"
If no, stop.

### 5. Call claimUnstaked on the vault

```bash
cast send $VAULT_ADDRESS \
  "claimUnstaked(address,uint256[])" \
  "0x2Db440cF6215d68d44736A287B253F4461399aa0" \
  "<request_ids_array>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 6. Verify and show result

Fetch vault WETH balance and remaining pending request IDs after the tx:

```bash
cast call 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

```bash
cast call $VAULT_ADDRESS \
  "getUnstakeRequestIds(address)(uint256[])" \
  "0x2Db440cF6215d68d44736A287B253F4461399aa0" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
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
