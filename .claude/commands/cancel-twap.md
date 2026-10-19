Cancel a gasless CoW TWAP of a BittyVault on Sepolia — the current part and every part still to come.

**Usage:** `/cancel-twap <schedule_file>`

- `<schedule_file>` — the `.twaps/<vault>-<start>.env` file printed by `/twap-sell` or `/twap-buy`

Arguments: $ARGUMENTS

If missing, list the files in `.twaps/` and stop with usage.

---

The schedule signature authorises every part, and each posted part carries it publicly, so deleting
the file is **not** a cancel — anyone could still post a future part. Part UIDs are deterministic, so
the skill computes the UID of every part whose window has not closed and invalidates them all on the
CoW settlement contract with the vault's `cancelIntentOrders`, in one transaction. Funds never left the
vault, so there is nothing to return.

---

## Steps

### 1. Check environment and resolve the intent protocol

```bash
: "${PRIVATE_KEY:?PRIVATE_KEY is not set — run /new-assetmanager first}"
source <schedule_file>
GUARD=$(cast call $VAULT "guard()(address)" --rpc-url "<rpc_url>")
for p in $(cast call $GUARD "getProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[],'); do
  [ "$(cast call $GUARD "protocolCategory(address)(uint8)" $p --rpc-url "<rpc_url>")" = 4 ] && INTENT_PROTOCOL=$p
done
```

### 2. Compute the live part UIDs

```bash
UIDS=$(RPC_URL="<rpc_url>" ./scripts/cow.sh twap-uids <schedule_file>)
```

If `UIDS` is `[]`, every part has expired: tell the user there is nothing to cancel and stop.

### 3. Confirm

Print the schedule (sell/buy tokens, per-part amounts, interval, parts) and how many UIDs will be
invalidated. Ask: "Cancel this TWAP? (yes/no)"

### 4. Cancel on-chain

```bash
cast send $VAULT "cancelIntentOrders(address,bytes[])" \
  $INTENT_PROTOCOL "$UIDS" \
  --rpc-url "<rpc_url>" --private-key "$PRIVATE_KEY"
```

### 5. Show result

Rename the file to `<schedule_file>.cancelled` so `/post-twap-part` is not run on it again, and print:
```
TWAP cancelled!
  Tx           : https://sepolia.etherscan.io/tx/<tx_hash>
  Invalidated  : <count> part order(s)
```
