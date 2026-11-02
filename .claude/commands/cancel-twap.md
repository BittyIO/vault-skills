Cancel a CoW TWAP of a BittyVault — every part, including the ones not posted yet.

Two things stop a TWAP, and both are needed:
1. **On-chain** — the vault invalidates the order UID of EVERY part on the CoW settlement contract
   (`cancelIntentOrders`). This is what makes it final: the schedule's signature is public once a
   part is posted, so anyone could post a future part; an invalidated UID can never fill.
2. **Bitty API** — the schedule is marked cancelled, so the Bitty API stops posting later parts.

**Usage:** `/cancel-twap [app_data]`

- `[app_data]` — the schedule id (`APP_DATA` printed by `/twap-sell` / `/twap-buy`). Omitted: list the
  vault's schedules and ask which.

Arguments: $ARGUMENTS

Run every command from the repo root.

---

## Steps

### 1. Preflight — needs the `INTENT` permission (bit 8)

```bash
bin/bitty preflight 8
```

If it prints an `Error:`, show it and stop.

### 2. Choose the schedule

```bash
bin/bitty twaps
```

It prints JSON: `data[]` with `appData`, `side`, `status`, `startTime`, `partDuration`, `parts`,
`lastPostedPart`, `windowEnd`. Without an argument, list the `active` ones and ask which. Stop if the
chosen one is not in the list (`Error: no TWAP <app_data> for this vault.`).

If its `windowEnd` is in the past, every part has already expired — only step 5 (marking it
cancelled) is useful; skip the transaction.

### 3. Compute every part's UID

```bash
bin/bitty twap-uids <app_data>
```

One UID per line, part 0 first. It rebuilds them from a part CoW already holds, so it fails if no
part was ever posted — then there is nothing to invalidate on chain: skip to step 5.

Drop the UIDs of parts whose slot has already ended (part `i` ends at `startTime + (i+1)·partDuration`)
— they can no longer fill, and leaving them out keeps the transaction small.

### 4. Preview, confirm and send

```
Cancel TWAP
  Vault     : <vault>
  Schedule  : <app_data> (<side>, <parts> parts every <partDuration>s)
  Parts     : <n> still open or to come — invalidated on chain
```

Ask: "Cancel this TWAP? (yes/no)". Stop on anything but yes.

```bash
bin/bitty cancel <uid> [<uid> …]
```

On a revert, show the reason and stop — do NOT mark it cancelled in step 5 if the on-chain step
failed, or the remaining parts stay fillable while the app shows the TWAP as gone.

### 5. Stop the Bitty API

```bash
bin/bitty twap-stop <app_data>
```

### 6. Result

```
TWAP cancelled.
  Tx       : <hash and explorer link, or "none needed">
  Schedule : marked cancelled — no further parts will be posted
```
