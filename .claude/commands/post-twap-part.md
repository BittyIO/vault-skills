Post the current part of a gasless CoW TWAP to the CoW API for a BittyVault on Sepolia. Run it at the start of each interval.

**Usage:** `/post-twap-part <schedule_file>`

- `<schedule_file>` — the `.twaps/<vault>-<start>.env` file printed by `/twap-sell` or `/twap-buy`

Arguments: $ARGUMENTS

If missing, list the files in `.twaps/` and stop with usage.

---

The part to post follows from the clock: `i = (now − start) / interval`. Its order and eip1271 payload
are rebuilt from the schedule file and the one schedule signature in it; no new signature and no
transaction are needed. Re-posting a part that is already on the book is harmless.

To run every interval unattended: `/loop <interval>s /post-twap-part <schedule_file>`.

---

## Steps

### 1. Check environment

```bash
: "${PRIVATE_KEY:?PRIVATE_KEY is not set — run /new-assetmanager first}"
cat <schedule_file>   # VAULT, SELL, BUY, SELL_PER, BUY_PER, START, DUR, N, SIG
```

### 2. Post

```bash
RPC_URL="<rpc_url>" ./scripts/cow.sh twap-post <schedule_file>
```

- `DONE=` — every part's window has passed; tell the user the TWAP is finished (the file can be deleted).
- `PART=`, `UID=`, `VALID_TO=`, `EXPLORER=` — the part is on the book.
- "the vault would reject this order" — the part cannot settle as things stand: the vault no longer
  holds one part's sell amount, or the manager's grant expired. Report it and stop.

### 3. Show result

```
TWAP part posted!
  Part      : <PART>
  Order UID : <UID>  (valid until <date of VALID_TO>)
  Explorer  : <EXPLORER>
  Next part : <date of VALID_TO>
```
