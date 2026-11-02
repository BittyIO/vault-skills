# BittyVault Skills

Slash commands for the **asset manager** of a BittyVault **1.0.7** vault. The preflight refuses an
older vault, a key that is not the vault's live asset manager, and — always — the owner's key.

## Network selection — ask once at the start of every session

**At the very beginning of the conversation** (before the user runs any skill), greet the user and ask:

```
Welcome to BittyVault Skills! Which network would you like to work on?
  [1] Sepolia (testnet — no real funds)
  [2] Mainnet (⚠ real ETH — transactions are irreversible)
```

Once the user answers:

1. Save their choice to `.env` as `NETWORK=sepolia` or `NETWORK=mainnet`.
2. Print a confirmation, e.g. `✓ Network set to Sepolia. Ready to run skills.`
3. If **Mainnet** was chosen, also print: `⚠ All transactions will use real ETH and are irreversible. Double-check every address.`

Do not ask about network again during the session unless the user explicitly asks to switch networks.

## How the skills run

- Every skill in `.claude/commands/` is network-neutral. **`bin/bitty`** does the shared work: it
  loads `.env`, then `<NETWORK>/.env` (`PRIVATE_KEY`, `VAULT_ADDRESS`, optional `ALCHEMY_KEY`),
  picks the RPC, and holds the network's addresses (guard, factory, forwarder, CoW, tokens).
  `bin/bitty help` lists its commands.
- Run every command **from the repo root**. Each command runs in a fresh shell, so never rely on a
  variable set in an earlier one — `bin/bitty` recomputes what it needs.
- **The RPC:** Alchemy when `ALCHEMY_KEY` is set, otherwise a free public endpoint. If the user hits
  rate limits on the free one, suggest a free key from https://www.alchemy.com/ in
  `<NETWORK>/.env` as `ALCHEMY_KEY=<key>`.
- **Nothing that moves funds or signs without a "yes".** Before any `bin/bitty send`, `limit`,
  `twap`, `cancel` or `twap-stop`, show the preview the skill describes and wait for the user to
  confirm. Read-only commands need no confirmation.
- **Never the owner key.** If the preflight says `PRIVATE_KEY` is the owner's, stop and tell the user
  to replace it with the asset manager's key. Never call an owner-only vault function, even when
  asked: the owner acts in the Bitty app.
- Never print `PRIVATE_KEY` or `ALCHEMY_KEY`, and never pass them anywhere but to `cast` via
  `bin/bitty`.
- On an `Error:` line from `bin/bitty`, show it to the user and stop the skill.

## Roles

The vault has one delegate: the **asset manager**, appointed by the owner in the Bitty app with an
expiry (at most a year) and a permission mask:

| Bit | Permission | Skills |
|-----|------------|--------|
| 1 | `YIELD` | `/stake`, `/unstake`, `/claim-withdrawals` |
| 2 | `SUPPLY` | `/supply`, `/withdraw` |
| 4 | `MARKET_TRADE` | `/market-sell` |
| 8 | `INTENT` | `/limit-sell`, `/limit-buy`, `/twap-sell`, `/twap-buy`, `/cancel-intent-order`, `/cancel-twap` |
| — | none | `/vault-balances`; setup: `/new-assetmanager`, `/deploy-vault`, `/fund-vault`, `/quickstart` |

While the vault is locked the grant is dormant and every skill but `/vault-balances` is refused.

Everything owner-side (activation, appointing the manager, allow lists, risk settings, locks,
sends, upgrades) is the owner's, in the Bitty app. The owner key never touches this CLI.

The contracts behind every call are in `abi/vault-1.0.7.json` and `abi/cow-1.0.4.json`.
