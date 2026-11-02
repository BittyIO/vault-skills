Cancel CoW limit orders of a BittyVault. Cancellation is ON-CHAIN: CoW's off-chain cancel
only accepts an EOA's own signature, so the vault invalidates the order UID on the CoW settlement
contract itself (`cancelIntentOrders`). Once invalidated, an order can never fill.

**Usage:** `/cancel-order [order_uid …]`

- `[order_uid …]` — one or more 56-byte order UIDs (`0x` + 112 hex). Omitted: list the vault's open
  orders and ask which to cancel.

Arguments: $ARGUMENTS

Run every command from the repo root.

---

## Steps

### 1. Preflight — needs the `INTENT` permission (bit 8)

A locked vault refuses cancellations.

```bash
bin/bitty preflight 8
```

If it prints an `Error:`, show it and stop.

### 2. Choose the orders

```bash
bin/bitty orders
```

- No UIDs given → show the list and ask which to cancel (or "all"). `No open orders.` → stop.
- UIDs given → each must match `^0x[0-9a-fA-F]{112}$`; stop on one that does not. A UID that is not
  in the open list may already be filled, expired or cancelled — say so and ask whether to
  invalidate it anyway.
- A `twap-part` order belongs to a TWAP: cancelling the part does not stop the schedule. Point the
  user at `/cancel-twap <appData>` for that.

### 3. Preview and confirm

```
Cancel CoW orders
  Vault  : <vault>
  Orders : <uid> (<kind>, sell <amount> <token> → buy <amount> <token>)
           …
```

Ask: "Cancel? (yes/no)". Stop on anything but yes.

### 4. Send

```bash
bin/bitty cancel <uid> [<uid> …]
```

On a revert, show the reason and stop (`InvalidIntentProtocol` — no CoW protocol is open to the
vault any more).

### 5. Result

```bash
bin/bitty orders
```

```
Cancelled <n> order(s).
  Tx : <hash and explorer link>
```

The CoW explorer may show an order as open for a minute before it notices the invalidation.
