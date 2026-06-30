# BittyVault Skills

## RPC URL

Resolve `<rpc_url>` before running any skill:

1. Check `.env` for `ALCHEMY_KEY`.
2. If set, use Alchemy:
   - Sepolia: `https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY`
   - Mainnet: `https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY`
3. If **not** set, use the free public endpoint (no sign-up required):
   - Sepolia: `https://ethereum-sepolia-rpc.publicnode.com`
   - Mainnet: `https://ethereum-rpc.publicnode.com`

Use `<rpc_url>` in all `cast` commands throughout the skill.

If the user hits rate-limit errors on the free endpoint, suggest they get a free Alchemy key at https://www.alchemy.com/ and add it to `.env` as `ALCHEMY_KEY=<key>`.

## Network selection — always ask first

**Before running any skill** (`/deploy-vault`, `/fund-vault`, `/supply`, etc.), ask the user:

```
Which network?
  [1] Sepolia (testnet — no real funds)
  [2] Mainnet (⚠ real ETH — transactions are irreversible)
```

Then:

- **Sepolia**: proceed with the skill file as written (all Sepolia configs are in `.claude/commands/`). Load env from `sepolia/.env`.
- **Mainnet**: print `⚠ You've selected Ethereum mainnet — all transactions use real funds and are irreversible.` Then read and follow `mainnet/.claude/commands/<skill_name>.md` instead of the default skill file. Load env from `mainnet/.env`.

For example, if the user runs `/deploy-vault` and picks Mainnet, read `mainnet/.claude/commands/deploy-vault.md` and execute that instead.

Do not skip the network question even if the user seems to be in a hurry.
