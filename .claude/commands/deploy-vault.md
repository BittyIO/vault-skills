Activate a new BittyVault on Sepolia for an owner, with the AI asset manager installed in the same transaction.

**Usage:** `/deploy-vault <owner_address>`

Arguments: $ARGUMENTS

If `<owner_address>` is missing, stop and print: "Usage: /deploy-vault <owner_address>"

---

## How activation works

Every owner has exactly **one** vault, at an address fixed before it exists:
`factory.vaultAddress(owner)`. The vault comes alive when the **owner** calls
`activateVault(bool restrictToOwnAllowList, bytes[] calls)` on the factory — `msg.sender` is the owner,
so this skill never sends it. `calls` are the owner's first operations, run as the owner in the same
transaction. This skill prepares two of them:

1. `updateProtocols([<cow_protocol>], [])` — instantiates the vault's CoW Swap clone, which off-chain
   limit and TWAP orders need to validate against.
2. `setAssetManager(<asset_manager>, <expires_at>, <permissions>)` — queues the AI key. A new vault
   starts with a **1-day change timelock**, so the grant is pending for 24 hours and then takes effect
   by itself. Funding the vault works meanwhile; the manager's DeFi actions wait for it.

**Never ask for, accept, or use the owner's private key.**

## Sepolia configuration

| Role | Address |
|------|---------|
| Factory | `0x3d7Ed3cD011B423dd11BE280BF926667CAf0F120` |
| Guard | `0x000000000F5fcD35885BfE4c700042cE7cb39554` |

---

## Steps

### 1. Check the asset manager key

```bash
: "${PRIVATE_KEY:?PRIVATE_KEY is not set — run /new-assetmanager first}"
ASSET_MANAGER=$(cast wallet address --private-key "$PRIVATE_KEY")
```

### 2. Compute the vault address and check it is not already live

```bash
FACTORY=0x3d7Ed3cD011B423dd11BE280BF926667CAf0F120
VAULT=$(cast call $FACTORY "vaultAddress(address)(address)" <owner_address> --rpc-url "<rpc_url>")
cast code $VAULT --rpc-url "<rpc_url>"
```

If the code is not `0x`, the vault is already activated: save `VAULT_ADDRESS=$VAULT` to `.env` (step 6),
tell the user to run `/new-assetmanager` to install the manager, and stop.

### 3. Choose the grant

Ask:
```
How long should the asset manager's authority last? (days, 1–365, default 90)
```
Every grant expires; the vault refuses one beyond 365 days (`GrantTooLong`).

```bash
EXPIRES_AT=$(( $(date +%s) + <days> * 86400 ))
```

Permissions, as a bit set (default `15` = all):

| Bit | Value | Allows |
|-----|-------|--------|
| `PERM_YIELD` | 1 | deposit into staking (Lido) |
| `PERM_SUPPLY` | 2 | deposit into lending (Aave) |
| `PERM_MARKET_TRADE` | 4 | `marketSell` / `marketBuy` (Uniswap) |
| `PERM_INTENT` | 8 | sign CoW limit / TWAP orders |

Withdrawing, claiming and cancelling orders need no bit — any live manager may unwind. A manager can
never send funds out of the vault.

### 4. Build the activation calls

```bash
GUARD=0x000000000F5fcD35885BfE4c700042cE7cb39554
for p in $(cast call $GUARD "getProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[],'); do
  [ "$(cast call $GUARD "protocolCategory(address)(uint8)" $p --rpc-url "<rpc_url>")" = 4 ] && COW_PROTOCOL=$p
done
CALL_COW=$(cast calldata "updateProtocols(address[],address[])" "[$COW_PROTOCOL]" "[]")
CALL_AM=$(cast calldata "setAssetManager(address,uint64,uint32)" $ASSET_MANAGER $EXPIRES_AT <permissions>)
```

### 5. Hand the activation to the owner

Print:
```
Send from the owner wallet <owner_address>:

  Contract : 0x3d7Ed3cD011B423dd11BE280BF926667CAf0F120
             https://sepolia.etherscan.io/address/0x3d7Ed3cD011B423dd11BE280BF926667CAf0F120#writeProxyContract
  Function : activateVault(bool restrictToOwnAllowList, bytes[] calls)
  restrictToOwnAllowList : false
  calls                  : [<CALL_COW>,<CALL_AM>]

  Vault address (fixed)  : <VAULT>
  Asset manager          : <ASSET_MANAGER>, expires <date of EXPIRES_AT>, permissions <permissions>
```

`false` keeps Bitty's curated asset/protocol catalogue as the vault's gate, which is what almost every
vault wants. ETH sent to the vault address before activation is wrapped into WETH when it activates.

Ask the user to reply once the transaction has landed (or paste its hash).

### 6. Verify and save

```bash
cast call $VAULT "owner()(address)" --rpc-url "<rpc_url>"
cast call $VAULT "getAssetManagerSettings()(address,uint64,address,uint64,uint32,uint32)" --rpc-url "<rpc_url>"
cast call $VAULT "getClone(address)(address)" $COW_PROTOCOL --rpc-url "<rpc_url>"
```

If `owner()` reverts, the owner has not activated yet — say so and stop. Otherwise save
`VAULT_ADDRESS=$VAULT` to `.env` (replace the line if present, else append).

`getAssetManagerSettings` returns `manager, expiresAt, pendingManager, pendingAt, permissions,
pendingPermissions`. Right after activation the key is `pendingManager` and `pendingAt` is when it
takes effect.

Print:
```
Vault activated!
  Vault         : <VAULT>  (https://sepolia.etherscan.io/address/<VAULT>)
  Owner         : <owner>
  Asset manager : <address> — pending, in force from <date of pendingAt> (expires <date>, permissions <permissions>)
  CoW clone     : <clone>
  VAULT_ADDRESS saved to .env ✓
Next: /fund-vault (works now); DeFi skills once the manager is in force
```
