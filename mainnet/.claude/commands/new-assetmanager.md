Set up the AI asset manager: generate or import a keypair, then have the owner install it on the vault.

**Usage:** `/new-assetmanager [vault_address]`

- `[vault_address]` — optional. If omitted, `VAULT_ADDRESS` from `.env` is used. If neither is
  available, the skill stops after saving the key and tells the user to run `/deploy-vault` first.

Arguments: $ARGUMENTS

Network is already chosen for this session (see CLAUDE.md); this skill runs on Ethereum mainnet.

---

## What an asset manager is

A vault has **exactly one** asset manager — a single address, not a role. There is no
`ASSET_MANAGER_ROLE` and no `grantRole`; a vault asked for one reverts. The owner names the manager
with `setAssetManager(address,uint64)`, and the vault reads that one slot when it authorises trading,
lending, staking and liquidity operations.

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
No vault yet — the key is saved. Run /deploy-vault <owner_address>, then re-run
/new-assetmanager to install this address as the manager.
```

### 5. Read the vault owner and choose an expiry

```bash
cast call <vault_address> "owner()(address)" --rpc-url "<rpc_url>"
```

Save as `<owner>`. Then ask:
```
When should this manager's authority end?
  [1] Never expires (0)
  [2] A date — the grant stops working on its own after it
```

`<expires_at>` is a unix timestamp, or `0` for no expiry. A non-zero value must be in the future or
the call reverts with `AssetManagerExpiryInPast`.

Prefer an expiry for a machine key: a leaked key nobody notices stops mattering on its own.

### 6. Hand the install to the owner — never sign it here

**Never ask for, accept, or use the owner's private key, in this or any skill.** These skills drive
the asset manager's hot wallet. The owner key can move every asset, change every allowlist and rename
the manager, and the only reason the two are separate wallets is to keep it out of automated flows —
a skill that takes it collapses exactly the separation the vault is built around.

Print the call for the owner to execute themselves, from a hardware wallet, a multisig, or Etherscan:

```
Send from the owner wallet <owner>:

  Contract : <vault_address>   (https://etherscan.io/address/<vault_address>#writeContract)
  Function : setAssetManager(address assetManager, uint64 expiresAt)
  assetManager : <address>
  expiresAt    : <expires_at>
```

Then ask the user to paste the transaction hash once it has landed, or to say `skip` and verify by
reading the vault directly.

### 7. Verify, and report whether it is live yet

```bash
cast call <vault_address> \
  "getAssetManagerSettings()(address,uint64,address,uint64)" \
  --rpc-url "<rpc_url>"
```

The four values are `manager`, `expiresAt`, `pendingManager`, `pendingAt`.

**Installing a manager waits out the vault's change timelock.** If the vault has one set, the new
address appears as `pendingManager` with `pendingAt` as the unix second it takes effect — it holds no
authority until then, and the previous manager keeps theirs for the whole delay. Only a vault with no
timelock installs immediately.

Revoking is not delayed: `setAssetManager(0x0, 0)` clears the manager the moment it lands, and so does
shortening an existing grant's expiry. The delay exists so a stolen owner key cannot install a manager
and trade in the same breath — it never stands between an owner and taking authority away.

Report the outcome:

```
Asset Manager Address : <address>
Private key saved to  : .env (PRIVATE_KEY)
Vault                 : <vault_address> (Ethereum mainnet)
Status                : in force  |  scheduled, takes effect <pendingAt> (<date>)
Expires               : never  |  <expiresAt> (<date>)
Transaction           : https://etherscan.io/tx/<tx_hash>   (omit if the user skipped)
```

If neither `manager` nor `pendingManager` is `<address>`, the owner has not sent the transaction yet.
Say so plainly rather than reporting success.

Do NOT print the asset manager's private key in full — show only the first 6 and last 4 characters
(e.g. `0x1234...abcd`) so the user can verify without exposing it in the conversation history.
