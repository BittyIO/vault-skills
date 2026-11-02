Supply an asset from a BittyVault into a lending protocol (Aave v3).

**Usage:** `/supply <asset> <amount|max>`

- `<asset>` — token symbol (WETH, WBTC, USDC, USDT) or a raw `0x…` address
- `<amount>` — human-readable amount (e.g. `1.5`), or `max` for the vault's whole wallet balance

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: asset, amount. If either is missing, stop and print the usage line.

Run every command from the repo root. `bin/bitty` loads the network and `.env` itself.

---

## Steps

### 1. Preflight — needs the `SUPPLY` permission (bit 2)

```bash
bin/bitty preflight 2
```

If it prints an `Error:`, show it to the user and stop. Otherwise show its summary.

### 2. Resolve the asset and amount

```bash
bin/bitty token <asset>                     # → <address> <decimals> <symbol>
bin/bitty balance <address>                 # the vault's wallet balance, raw
```

- `max` → use the wallet balance as `<amount_raw>`.
- Otherwise `bin/bitty raw <amount> <decimals>` → `<amount_raw>`.

Stop if `<amount_raw>` is 0, or larger than the wallet balance:
```
Error: the vault holds only <bin/bitty human balance decimals> <symbol>.
```

Check the vault may hold the asset:
```bash
bin/bitty call "isAssetAllowed(address)(bool)" <address>
```
If `false`, stop: `Error: <symbol> is not on this vault's allow list.`

### 3. Pick the lending protocol

```bash
bin/bitty protocols lending                 # → "<address> <name>" per line
```

- None → stop: `Error: no lending protocol is open to this vault on <network>.`
- One → use it.
- Several → list them and ask the user which one.

### 4. Preview and confirm

```
Supply
  Vault    : <vault>
  Asset    : <amount> <symbol>  (<amount_raw> raw)
  Protocol : <name> (<protocol>)
```

Ask: "Supply? (yes/no)". Stop on anything but yes.

### 5. Send

```bash
bin/bitty send "deposit(address,address,uint256)" <protocol> <address> <amount_raw>
```

On a revert, show the reason and stop. Common ones:
- `InvalidDepositableProtocol` — the protocol was retired or removed from the vault's allow list.
- `OwnableUnauthorizedAccount` — the grant changed since the preflight; rerun it.
- `VaultLocked` — the owner locked the vault since the preflight; nothing can be deposited now.
- Aave error `51` — the reserve's supply cap is reached or the reserve is frozen.

### 6. Result

```bash
bin/bitty position <protocol> <address>
bin/bitty balance <address>
```

```
Supplied <amount> <symbol> to <name>.
  Tx            : <hash and explorer link from step 5>
  Now supplied  : <position, human>
  Wallet balance: <balance, human>
```
