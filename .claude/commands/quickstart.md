End-to-end demo of the BittyVault lifecycle on Sepolia: asset manager key → vault activation → funding → market swap → Aave supply/withdraw → Lido stake → gasless CoW limit order and cancel.

**Usage:** `/quickstart <owner_address> [demo_amount]`

- `<owner_address>` — the vault owner's wallet (hardware wallet, multisig, or browser wallet). Its key is never used here.
- `[demo_amount]` — ETH to fund the vault with (default `0.02`)

Arguments: $ARGUMENTS

If `<owner_address>` is missing, stop and print usage.

---

## Execution rule — applied to EVERY step

Each step runs the named skill's steps in full, with its arguments filled in below. Before each step
print `Step N/9 — <title>` and one line saying what it shows. Ask the user "Run this step? (yes/skip/stop)"
— `skip` moves on, `stop` jumps to the summary. If a step fails, show the error, explain it in one line,
and ask whether to continue. Keep a list of every tx hash, UID and outcome for the summary.

Amounts below are for the default `0.02` ETH; scale them with `[demo_amount]`.

---

### Step 1 — AI asset manager key
Run `/new-assetmanager`. No vault exists yet, so it stops after saving `PRIVATE_KEY`.

### Step 2 — Gas for the asset manager
The asset manager pays gas and funds the vault. Show its balance:
```bash
cast balance $(cast wallet address --private-key "$PRIVATE_KEY") --ether --rpc-url "<rpc_url>"
```
If below `<demo_amount> + 0.01`, ask the user to send Sepolia ETH to it (faucet:
https://cloud.google.com/application/web3/faucet/ethereum/sepolia) and wait until it arrives.

### Step 3 — Activate the vault
Skip if `VAULT_ADDRESS` is set and the vault has code. Otherwise run `/deploy-vault <owner_address>`
with defaults (90 days, all permissions). The owner signs one transaction that activates the vault,
enables CoW, and queues the asset manager.

### Step 4 — Fund
Skip if the vault already holds WETH. Otherwise run `/fund-vault <demo_amount>` — ETH in, WETH held by
the vault.

**Gate:** a new vault's 1-day timelock keeps the asset manager pending for 24 hours. Read
`getAssetManagerSettings()`; if this key is still `pendingManager`, print "The asset manager takes
effect at <date of pendingAt>. Re-run /quickstart <owner_address> then — finished steps are skipped."
and go to the summary.

### Step 5 — Market swap WETH → USDT
Run `/rebalance WETH USDT 0.01`. Shows a Uniswap Universal Router trade with an on-chain minimum.

### Step 6 — Supply WBTC to Aave, then withdraw it
Aave's Sepolia market only takes WBTC (see `/supply`). Mint 1 WBTC into the vault from Aave's faucet:
```bash
cast send 0xC959483DBa39aa9E78757139af0e9a2EDEb3f42D "mint(address,address,uint256)" \
  0x29f2D40B0605204364af54EC677bD022dA425d03 $VAULT_ADDRESS 100000000 \
  --rpc-url "<rpc_url>" --private-key "$PRIVATE_KEY"
```
Then `/supply WBTC 0.5`, show the position, and `/withdraw WBTC max`.

### Step 7 — Stake WETH in Lido
Run `/stake WETH 0.005`. The vault receives stETH. Mention that `/unstake` opens a Lido withdrawal
request claimed later with `/claim-unstaked`, but the Sepolia withdrawal queue is paused, so it is not
part of the demo.

### Step 8 — Gasless CoW limit order, then cancel
Run `/limit-sell USDT WETH <half the vault's USDT> 1 1h` — a deliberately unfillable price, so it rests
on the book. Show the CoW explorer link, then run `/cancel-order <UID>` to invalidate it on-chain.

### Step 9 — Final balances
Run `/vault-balances`.

---

### Summary

```
BittyVault quickstart complete (Sepolia)
  Vault          : <VAULT_ADDRESS>  https://sepolia.etherscan.io/address/<VAULT_ADDRESS>
  Owner          : <owner_address>
  Asset manager  : <address>

  Step                       Result
  1 Asset manager key        ✓ saved to .env
  3 Activate vault           ✓ <tx>
  4 Fund                     ✓ <tx>
  5 Swap WETH → USDT         ✓ <tx>
  6 Aave WBTC supply/withdraw ✓ <tx> / <tx>
  7 Lido stake               ✓ <tx>
  8 CoW limit + cancel       ✓ <uid> / <tx>
  (skipped / failed steps marked — or ✗ with the reason)

Try next: /twap-sell, /limit-buy, /vault-balances
```
