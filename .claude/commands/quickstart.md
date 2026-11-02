End-to-end demo of a BittyVault on **Sepolia**: asset manager key → vault activation → funding →
market swap → Aave supply and withdraw → Lido stake → gasless CoW limit order and cancel.

**Usage:** `/quickstart <owner_address> [demo_amount]`

- `<owner_address>` — the vault owner's wallet (hardware wallet, multisig or browser wallet). Its key
  is never used here.
- `[demo_amount]` — ETH to fund the vault with (default `0.02`)

Arguments: $ARGUMENTS

If `<owner_address>` is missing, stop and print the usage line.

Run every command from the repo root.

---

## Sepolia only

```bash
bin/bitty env                     # NETWORK=
```

Anything but `NETWORK=sepolia` → stop: `The quickstart is a Sepolia demo. Switch the network to Sepolia first.`
It spends test ETH and uses Aave's Sepolia faucet; on mainnet run the skills one by one instead.

## Execution rule — applied to EVERY step

Each step runs the named skill's steps in full, with its arguments filled in below. Before each step
print `Step N/9 — <title>` and one line saying what it shows. Ask "Run this step? (yes/skip/stop)" —
`skip` moves on, `stop` jumps to the summary. If a step fails, show the error, explain it in one line,
and ask whether to continue. Keep every tx hash, UID and outcome for the summary.

Amounts below are for the default `0.02` ETH; scale them with `[demo_amount]`.

---

### Step 1 — Asset manager key
Run `/new-assetmanager`. With no vault yet, it stops after saving `PRIVATE_KEY`.

### Step 2 — Gas for the asset manager
The asset manager pays gas and funds the vault:
```bash
bin/bitty cast balance $(bin/bitty me) --ether
```
Below `<demo_amount> + 0.01` → ask the user to send Sepolia ETH to it (faucet:
https://cloud.google.com/application/web3/faucet/ethereum/sepolia) and wait until it arrives.

### Step 3 — Activate the vault
Skip if `VAULT_ADDRESS` is set and has code. Otherwise run `/deploy-vault <owner_address>` with the
defaults (90 days, all permissions). The owner signs one transaction that activates the vault, enables
CoW and appoints the asset manager.

### Step 4 — Fund
Skip if the vault already holds WETH. Otherwise run `/fund-vault <demo_amount>`.

**Gate:** a new vault's 1-day timelock keeps the asset manager pending for a day. Run
`bin/bitty role`; unless it prints `manager …`, read
`bin/bitty call "getAssetManagerSettings()(address,uint64,address,uint64,uint32,uint32)"`, print
"The asset manager takes effect at <date of pendingAt>. Re-run /quickstart <owner_address> then —
finished steps are skipped." and go to the summary.

### Step 5 — Market swap WETH → USDT
Run `/market-sell WETH USDT 0.01`: a Uniswap Universal Router trade held to the oracle price.

### Step 6 — Supply WBTC to Aave, then withdraw it
Aave's Sepolia market only takes WBTC (see `/supply`). Mint 1 WBTC into the vault from Aave's faucet,
after the user confirms:
```bash
bin/bitty tx 0xC959483DBa39aa9E78757139af0e9a2EDEb3f42D "mint(address,address,uint256)" \
  0x29f2D40B0605204364af54EC677bD022dA425d03 <vault> 100000000
```
Then `/supply WBTC 0.5`, show the position, and `/withdraw WBTC max`.

### Step 7 — Stake WETH in Lido
Run `/stake WETH 0.005`; the vault receives stETH. Mention that `/unstake` opens a Lido withdrawal
claimed later with `/claim-withdrawals`, but Sepolia's withdrawal queue is paused, so it is not part of
the demo.

### Step 8 — Gasless CoW limit order, then cancel
Run `/limit-sell USDT WETH <half the vault's USDT> 1 1h` — a deliberately unfillable price, so it rests
on the book. Show the CoW explorer link, then `/cancel-intent-order <uid>` to invalidate it on chain.

### Step 9 — Final balances
Run `/vault-balances`.

---

### Summary

```
BittyVault quickstart (Sepolia)
  Vault          : <vault>  <ADDRESS_EXPLORER><vault>
  Owner          : <owner_address>
  Asset manager  : <address>

  Step                        Result
  1 Asset manager key         ✓ saved to sepolia/.env
  3 Activate vault            ✓ <tx>
  4 Fund                      ✓ <tx>
  5 Swap WETH → USDT          ✓ <tx>
  6 Aave WBTC supply/withdraw ✓ <tx> / <tx>
  7 Lido stake                ✓ <tx>
  8 CoW limit + cancel        ✓ <uid> / <tx>
  (skipped or failed steps marked — or ✗ with the reason)

Try next: /twap-sell, /limit-buy, /vault-balances
```
