Claim finalized unstake requests from the Lido staking protocol into a BittyVault on Ethereum mainnet.

This is step 2 of the unstaking flow. Run this after `/unstake` once the Lido withdrawal period has passed.

**Usage:** `/claim-unstaked [request_id_1] [request_id_2] ...`

- `[request_ids]` — optional space-separated list of request IDs to claim. If omitted, all pending request IDs are fetched automatically from `$VAULT_ADDRESS` and claimed.

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as optional request IDs (all tokens).

---

## Hardcoded mainnet configuration

Staking protocol (Lido V2): `0x68ED00Bd31E64ae77c19F9712dd1B27d4AA083b9`

WETH: `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2`

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Resolve request IDs

If request IDs were provided in `$ARGUMENTS`, use them as `<request_ids>`.

Otherwise fetch all pending IDs from the vault:

```bash
cast call $VAULT_ADDRESS \
  "getUnstakeRequestIds(address)(uint256[])" \
  "0x68ED00Bd31E64ae77c19F9712dd1B27d4AA083b9" \
  --rpc-url "<rpc_url>"
```

If the result is an empty array, stop and print:
```
No pending unstake requests found for this vault.
Run /unstake first to queue a withdrawal.
```

Save the IDs as `<request_ids>` and format them as a Solidity-style array for cast: `[id1,id2,...]`.

### 3. Check vault WETH balance before (to measure what arrives)

Fetch the vault's WETH balance (Lido returns WETH on mainnet):

```bash
cast call 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

Save as `<weth_before>`.

### 4. Show preview and ask for confirmation

Print:
```
⚠ This is Ethereum mainnet — real funds will be used.

Vault             : $VAULT_ADDRESS
Staking protocol  : 0x68ED00Bd31E64ae77c19F9712dd1B27d4AA083b9
Request IDs       : <request_ids>
Vault WETH balance: <weth_before> (raw)
```

Ask: "Proceed with claiming? (yes/no)"
If no, stop.

### 5. Call claimUnstaked on the vault

```bash
cast send $VAULT_ADDRESS \
  "claimUnstaked(address,uint256[])" \
  "0x68ED00Bd31E64ae77c19F9712dd1B27d4AA083b9" \
  "<request_ids_array>" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 6. Verify and show result

Fetch vault WETH balance and remaining pending request IDs after the tx:

```bash
cast call 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 \
  "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

```bash
cast call $VAULT_ADDRESS \
  "getUnstakeRequestIds(address)(uint256[])" \
  "0x68ED00Bd31E64ae77c19F9712dd1B27d4AA083b9" \
  --rpc-url "<rpc_url>"
```

Print a final summary:
```
Claim successful!
  Tx hash              : <tx_hash>
  Etherscan            : https://etherscan.io/tx/<tx_hash>
  Claimed request IDs  : <request_ids>
  Vault WETH before    : <weth_before> (raw)
  Vault WETH after     : <weth_after> (raw)
  WETH received        : <weth_after - weth_before> (raw)
  Remaining request IDs: <remaining_ids or "none">
```
