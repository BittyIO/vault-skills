Prepare the activation of a new BittyVault for an owner, with the asset manager appointed and CoW
enabled in the same transaction. The owner signs it; this skill never does.

**Usage:** `/deploy-vault <owner_address>`

Arguments: $ARGUMENTS

If `<owner_address>` is missing, stop and print: `Usage: /deploy-vault <owner_address>`

Run every command from the repo root.

---

## How activation works

Every owner has exactly **one** vault, at an address fixed before it exists:
`factory.vaultAddress(owner)`. It comes alive when the **owner** calls
`activateVault(bool restrictToOwnAllowList, bytes[] calls)` on the factory; `calls` are the owner's
first operations, run as the owner in the same transaction. This skill prepares two:

1. `updateProtocols([<cow>], [])` — creates the vault's CoW clone, which every limit and TWAP order
   is checked against. It must be adapter 1.0.4 or later.
2. `setAssetManager(<asset_manager>, <expires_at>, <permissions>)` — appoints the asset manager. A new
   vault starts with a 1-day timelock, so the grant is pending for a day and then takes effect by
   itself. Funding works meanwhile; the manager's skills wait for it.

**Never ask for, accept, or use the owner's private key.**

---

## Steps

### 1. The asset manager key

```bash
bin/bitty env                                   # NETWORK, FACTORY, explorers
bin/bitty me                                    # → <asset_manager>
```

`bin/bitty me` errors → stop: `Error: no asset manager key yet — run /new-assetmanager first.` If it equals `<owner_address>`, stop: the owner's key must never be
used here.

### 2. The vault address, and whether it is live

```bash
bin/bitty cast call <FACTORY> "vaultAddress(address)(address)" <owner_address>      # → <vault>
bin/bitty cast code <vault>
```

If the code is not `0x`, the vault is already active: save `VAULT_ADDRESS=<vault>` (step 6), tell the
user to run `/new-assetmanager` to have the owner appoint the manager, and stop.

### 3. The grant

Ask: `How long should the asset manager's authority last? (days, 1–365, default 90)`

```bash
EXPIRES_AT=$(( $(bin/bitty cast block latest -f timestamp) + <days> * 86400 ))
```

Permissions, as a bit set (default `15` = all): `1` staking (Lido, Sky), `2` lending (Aave), `4`
market swaps, `8` CoW orders. Each bit covers going in and out of its protocols. A manager can never
send funds out of the vault.

### 4. The activation calls

```bash
COW=$(bin/bitty cow-latest)
CALL_COW=$(cast calldata "updateProtocols(address[],address[])" "[$COW]" "[]")
CALL_AM=$(cast calldata "setAssetManager(address,uint64,uint32)" <asset_manager> $EXPIRES_AT <permissions>)
```

### 5. Hand the activation to the owner

```
Send from the owner wallet <owner_address>:

  Contract : <FACTORY>   (<ADDRESS_EXPLORER><FACTORY>#writeProxyContract)
  Function : activateVault(bool restrictToOwnAllowList, bytes[] calls)
  restrictToOwnAllowList : false
  calls                  : [<CALL_COW>,<CALL_AM>]

  Vault address (fixed)  : <vault>
  Asset manager          : <asset_manager>, expires <date of EXPIRES_AT>, permissions <names>
```

`false` keeps Bitty's curated asset and protocol list as the vault's gate, which is what almost every
vault wants. ETH sent to the vault address before activation is wrapped into WETH when it activates.

Ask the user to reply once the transaction has landed (or paste its hash).

### 6. Verify and save

```bash
bin/bitty cast call <vault> "owner()(address)"
bin/bitty cast call <vault> "versionName()(string)"
bin/bitty cast call <vault> "getAssetManagerSettings()(address,uint64,address,uint64,uint32,uint32)"
bin/bitty cast call <vault> "getClone(address)(address)" $COW
```

If `owner()` reverts, the owner has not activated yet — say so and stop. Otherwise set
`VAULT_ADDRESS=<vault>` in `<network>/.env` (replace the line if present, else append).

```
Vault activated!
  Vault         : <vault> (<version>)  <ADDRESS_EXPLORER><vault>
  Owner         : <owner_address>
  Asset manager : <asset_manager> — pending, in force from <date of pendingAt> (expires <date>, permissions <names>)
  CoW clone     : <clone>
  VAULT_ADDRESS saved to <network>/.env ✓
Next: /fund-vault (works now); the DeFi skills once the manager is in force.
```
