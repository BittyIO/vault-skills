Set up the AI asset manager: generate or import a keypair, then have the owner install it on the vault.

**Usage:** `/new-assetmanager [vault_address]`

- `[vault_address]` — optional. If omitted, `VAULT_ADDRESS` from `.env` is used. If neither is
  available, the skill stops after saving the key and tells the user to run `/deploy-vault` first.

Arguments: $ARGUMENTS

Network is already chosen for this session (see CLAUDE.md); this skill runs on Sepolia.

---

## What an asset manager is

A vault has **exactly one** asset manager — a single address, not a role. There is no
`ASSET_MANAGER_ROLE` and no `grantRole`; a vault asked for one reverts. The owner names the manager
with `setAssetManager(address,uint64,uint32)` — the address, when the grant expires, and a permission
mask — and the vault reads that one slot when it authorises staking, lending, market trades and CoW
orders. A manager can never send funds out of the vault.

The owner may name themselves, in which case one key does everything. Naming a *separate* address is
what lets a hot key trade without also being able to move money out.

---

## Steps

### 1. Ask the user how they want to set up the asset manager

```
How would you like to set up the asset manager?
  [1] Generate a new keypair
  [2] Enter an existing private key
```

### 2a. If the user chose "Generate" (option 1)

```bash
cast wallet new
```

Parse the output and extract:
- `<address>` — the `Address:` line
- `<private_key>` — the `Private key:` line

### 2b. If the user chose "Enter existing" (option 2)

Ask the user to paste their private key. Accept it as `<private_key>`.

```bash
cast wallet address --private-key "<private_key>"
```

Save the output as `<address>`.

### 3. Save the private key to `.env`

Check if a `.env` file exists in the current directory.

- If `PRIVATE_KEY` is already set in `.env`, **replace** that line.
- Otherwise **append** `PRIVATE_KEY=<private_key>` to the file (create it if it doesn't exist).

### 4. Resolve the vault, or stop here

Use `[vault_address]` if given, otherwise `VAULT_ADDRESS` from `.env`.

If neither is set, print the summary from step 7 and stop with:
```
No vault yet — the key is saved. Run /deploy-vault <owner_address>: the owner's activation
transaction installs this address as the manager in the same step.
```

### 5. Read the vault owner and choose the grant

```bash
cast call <vault_address> "owner()(address)" --rpc-url "<rpc_url>"
```

Save as `<owner>`. Then ask:
```
How long should this manager's authority last? (days, 1–365, default 90)
```

Every grant expires: `<expires_at>` is a unix timestamp in the future (`AssetManagerExpiryInPast`
otherwise) and at most 365 days out (`GrantTooLong` otherwise). A leaked key nobody notices stops
mattering on its own.

```bash
EXPIRES_AT=$(( $(date +%s) + <days> * 86400 ))
```

Then the permission mask (default `15` = all):

| Bit | Value | Allows |
|-----|-------|--------|
| `PERM_YIELD` | 1 | deposit into staking (Lido) |
| `PERM_SUPPLY` | 2 | deposit into lending (Aave) |
| `PERM_MARKET_TRADE` | 4 | `marketSell` / `marketBuy` (Uniswap) |
| `PERM_INTENT` | 8 | sign CoW limit / TWAP orders |

Withdrawing, claiming and cancelling orders need no bit — any live manager may unwind, since all of it
lands back in the vault. `0` appoints a key that can only unwind.

### 6. Hand the install to the owner — never sign it here

**Never ask for, accept, or use the owner's private key, in this or any skill.** These skills drive
the asset manager's hot wallet. The owner key can move every asset, change every allowlist and rename
the manager, and the only reason the two are separate wallets is to keep it out of automated flows —
a skill that takes it collapses exactly the separation the vault is built around.

Print the call for the owner to execute themselves, from a hardware wallet, a multisig, or Etherscan:

```
Send from the owner wallet <owner>:

  Contract : <vault_address>   (https://sepolia.etherscan.io/address/<vault_address>#writeContract)
  Function : setAssetManager(address assetManager, uint64 expiresAt, uint32 permissions)
  assetManager : <address>
  expiresAt    : <expires_at>
  permissions  : <permissions>
```

Then ask the user to paste the transaction hash once it has landed, or to say `skip` and verify by
reading the vault directly.

### 7. Verify, and report whether it is live yet

```bash
cast call <vault_address> \
  "getAssetManagerSettings()(address,uint64,address,uint64,uint32,uint32)" \
  --rpc-url "<rpc_url>"
```

The six values are `manager`, `expiresAt`, `pendingManager`, `pendingAt`, `permissions`,
`pendingPermissions`.

**Installing a manager waits out the vault's change timelock.** If the vault has one set, the new
address appears as `pendingManager` with `pendingAt` as the unix second it takes effect — it holds no
authority until then, and the previous manager keeps theirs for the whole delay. New vaults start
with a 1-day timelock; only a vault whose owner has lowered it to 0 installs immediately.

Revoking is not delayed: `setAssetManager(0x0, 0, 0)` clears the manager the moment it lands, and so does
shortening an existing grant's expiry or dropping permissions. The delay exists so a stolen owner key cannot install a manager
and trade in the same breath — it never stands between an owner and taking authority away.

Report the outcome:

```
Asset Manager Address : <address>
Private key saved to  : .env (PRIVATE_KEY)
Vault                 : <vault_address> (Sepolia)
Status                : in force  |  scheduled, takes effect <pendingAt> (<date>)
Expires               : <expiresAt> (<date>)
Permissions           : <permissions> (<names of the set bits>)
Transaction           : https://sepolia.etherscan.io/tx/<tx_hash>   (omit if the user skipped)
```

If neither `manager` nor `pendingManager` is `<address>`, the owner has not sent the transaction yet.
Say so plainly rather than reporting success.

Do NOT print the asset manager's private key in full — show only the first 6 and last 4 characters
(e.g. `0x1234...abcd`) so the user can verify without exposing it in the conversation history.
