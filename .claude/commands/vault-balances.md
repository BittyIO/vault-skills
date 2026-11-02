Show a BittyVault: your role, the vault's wallet balances, what it has in
lending and staking protocols, pending withdrawals, and open CoW orders. Read-only.

**Usage:** `/vault-balances`

No arguments. Reads `VAULT_ADDRESS` from the network's `.env`.

Run every command from the repo root.

---

## Steps

### 1. Role

```bash
bin/bitty role                               # manager <perms> <expiresAt> | none
bin/bitty call "lockLevel()(uint8)"
```

- An `Error:` about the vault itself (not set, no contract) → show it and stop.
- `owner` → stop. Tell the user the vault owner's key must never be used here: remove it from the
  network's `.env`, put the asset manager's key instead, and do owner tasks in the Bitty app.
- `none` → say the key is not the vault's live asset manager, and carry on: balances are public.

### 2. Wallet balances

For each token of the network — `bin/bitty token WETH`, `WBTC`, `USDC`, `USDT` — read:

```bash
bin/bitty balance <address>
bin/bitty call "isAssetAllowed(address)(bool)" <address>
```

Native ETH too (18 decimals): `bin/bitty balance ETH`. Protocols take WETH, not native ETH, so show
it apart and, when it is non-zero, mention that anyone may wrap it into WETH with
`bin/bitty send "wrapNative()"` (after the user confirms).

### 3. Positions

```bash
bin/bitty protocols lending held
bin/bitty protocols staking held
```

For each held protocol, read the position in each token it can hold — Lido: WETH; Sky: USDC;
Aave: every token above:

```bash
bin/bitty position <protocol> <token address>
```

And pending withdrawals:

```bash
bin/bitty pending <protocol>
```

### 4. Open orders

```bash
bin/bitty orders
```

### 5. Print

Convert every raw amount with `bin/bitty human <raw> <decimals>` and skip zero rows.

```
Vault <vault> on <network>
  You         : <asset manager — permissions <…>, expires <date> | not the asset manager>
  Lock        : <unlocked | level N>

Wallet
  WETH   <amount>        (allowed)
  USDC   <amount>        (not on the allow list)
  ETH    <amount>        (native — wrap before use)

Lending
  Aave-v3  WETH  <amount>

Staking
  Lido     WETH  <amount>     pending withdrawals: <ids or none>
  Sky      USDC  <amount>

Open CoW orders
  <lines from bin/bitty orders, or "none">
```
