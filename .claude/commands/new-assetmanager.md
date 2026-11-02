Set up the asset manager key: generate or import one, save it, and have the owner appoint it on the
vault.

**Usage:** `/new-assetmanager [vault_address]`

- `[vault_address]` — optional. If omitted, `VAULT_ADDRESS` from the network's `.env` is used. If
  neither is set, the skill stops after saving the key and points at `/deploy-vault`.

Arguments: $ARGUMENTS

Run every command from the repo root.

---

## What an asset manager is

A vault has **exactly one** asset manager — a single address, not a role. The owner names it with
`setAssetManager(address,uint64,uint32)`: the address, when the grant expires, and a permission mask.
A manager can invest and trade for the vault, within the owner's daily loss allowance, but can never
send funds out of it. Keeping it a separate key from the owner's is the whole point: a hot key here
can trade without being able to move money out.

**Never ask for, accept, or use the owner's private key**, in this or any skill. The owner key can
move every asset and rename the manager; the owner acts from their own wallet or the Bitty app.

---

## Steps

### 1. Ask how to set up the key

```
How would you like to set up the asset manager?
  [1] Generate a new keypair
  [2] Enter an existing private key
```

### 2a. Generate

```bash
cast wallet new
```

Take `<address>` from the `Address:` line and `<private_key>` from the `Private key:` line.

### 2b. Import

Ask the user to paste the key; `<private_key>`. Then:

```bash
cast wallet address --private-key "<private_key>"           # → <address>
```

### 3. Refuse the owner's key

Resolve the vault: `[vault_address]`, otherwise `bin/bitty env` (`VAULT_ADDRESS=`). If there is one
and it has code (`bin/bitty cast code <vault>` is not `0x`):

```bash
bin/bitty cast call <vault> "owner()(address)"              # → <owner>
```

If `<address>` is `<owner>`, stop — do not save it:
```
Error: that is the vault OWNER's key. It must never be used here. Use a separate key for the asset manager.
```

### 4. Save the key

Read the network from `bin/bitty env` (`NETWORK=`). In `<network>/.env`, replace the `PRIVATE_KEY=`
line if there is one, otherwise append `PRIVATE_KEY=<private_key>` (create the file if needed). If
step 3 resolved a vault and `VAULT_ADDRESS` is blank there, set it too.

Never print the key in full — at most the first 6 and last 4 characters (`0x1234…abcd`).

### 5. No vault yet → stop

If no vault was resolved, or it has no code:
```
The key is saved. Run /deploy-vault <owner_address>: the owner's activation transaction appoints this
address as the asset manager in the same step.
```

### 6. Choose the grant

Ask:
```
How long should this manager's authority last? (days, 1–365, default 90)
```

```bash
EXPIRES_AT=$(( $(bin/bitty cast block latest -f timestamp) + <days> * 86400 ))
```

Every grant expires: in the past reverts `AssetManagerExpiryInPast`, beyond 365 days `GrantTooLong`.
Then the permission mask (default `15` = all):

| Bit | Value | Allows |
|-----|-------|--------|
| `PERM_YIELD` | 1 | staking in and out (Lido, Sky), claiming unstaked withdrawals |
| `PERM_SUPPLY` | 2 | lending in and out (Aave) |
| `PERM_MARKET_TRADE` | 4 | market swaps |
| `PERM_INTENT` | 8 | signing and cancelling CoW limit / TWAP orders |

Each skill checks the bit it needs. A mask of 0 is a key that can do nothing.

### 7. Hand the appointment to the owner — never sign it here

```
Send from the owner wallet <owner> (or in the Bitty app: Security → Asset manager):

  Contract     : <vault>   (<ADDRESS_EXPLORER from bin/bitty env><vault>#writeProxyContract)
  Function     : setAssetManager(address assetManager, uint64 expiresAt, uint32 permissions)
  assetManager : <address>
  expiresAt    : <EXPIRES_AT>   (<local date>)
  permissions  : <mask>
```

Ask the user to paste the transaction hash once it has landed, or `skip` to check the vault directly.

### 8. Verify

```bash
bin/bitty call "getAssetManagerSettings()(address,uint64,address,uint64,uint32,uint32)"
```

The six values are `manager`, `expiresAt`, `pendingManager`, `pendingAt`, `permissions`,
`pendingPermissions`.

**Appointing a new manager waits out the vault's timelock** — at least a day, and the vault's own
setting if the owner raised it. Until then the address is `pendingManager`, holds no authority, and
any previous manager keeps theirs. A revoke, a shorter expiry or fewer permissions apply at once.

```
Asset manager : <address>
Key saved to  : <network>/.env (PRIVATE_KEY)
Vault         : <vault> (<network>)
Status        : in force | pending — takes effect <date of pendingAt>
Expires       : <date>
Permissions   : <names of the set bits>
Transaction   : <TX_EXPLORER><hash>      (omit if skipped)
```

If neither `manager` nor `pendingManager` is `<address>`, the owner has not sent it yet — say so
plainly rather than reporting success.
