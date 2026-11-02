Stake an asset from a BittyVault into a staking protocol — Lido (WETH → stETH) or Sky
(USDC → sUSDS).

**Usage:** `/stake <asset> <amount|max>`

- `<asset>` — `WETH` for Lido, `USDC` for Sky, or a raw `0x…` address
- `<amount>` — human-readable amount, or `max` for the vault's whole wallet balance

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as: asset, amount. If either is missing, stop and print the usage line.

Run every command from the repo root.

---

## Steps

### 1. Preflight — needs the `YIELD` permission (bit 1)

```bash
bin/bitty preflight 1
```

If it prints an `Error:`, show it and stop. Otherwise show its summary.

### 2. Resolve the asset and amount

```bash
bin/bitty token <asset>
bin/bitty balance <address>
bin/bitty call "isAssetAllowed(address)(bool)" <address>
```

- `max` → the wallet balance; otherwise `bin/bitty raw <amount> <decimals>`.
- Stop if the amount is 0, exceeds the wallet balance, or the asset is not allowed.

### 3. Pick the staking protocol

```bash
bin/bitty protocols staking
```

Keep only the protocols that take this asset:
- `Lido` takes **WETH** only.
- `Sky` takes **USDC** only.
- `unknown` — ask the user before using it.

None left → stop: `Error: no staking protocol on this vault takes <symbol>.` Several → ask which.

### 4. Preview and confirm

```
Stake
  Vault    : <vault>
  Asset    : <amount> <symbol>  (<amount_raw> raw)
  Protocol : <name> (<protocol>)
```

For Lido add: `Unstaking later is two-step: /unstake, then /claim-unstaked once Lido finalises (days).`

Ask: "Stake? (yes/no)". Stop on anything but yes.

### 5. Send

```bash
bin/bitty send "deposit(address,address,uint256)" <protocol> <address> <amount_raw>
```

On a revert, show the reason and stop (`InvalidAsset` — this protocol does not take the asset).

### 6. Result

```bash
bin/bitty position <protocol> <address>
bin/bitty balance <address>
```

```
Staked <amount> <symbol> in <name>.
  Tx            : <hash and explorer link>
  Now staked    : <position, human, in <symbol>>
  Wallet balance: <balance, human>
```
