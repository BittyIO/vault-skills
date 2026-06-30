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

**For all subsequent skills in this session**, read `NETWORK` from `.env` and:
- If `NETWORK=sepolia`: use the skill as written (Sepolia configs in `.claude/commands/`), load env from `sepolia/.env`.
- If `NETWORK=mainnet`: read and follow `mainnet/.claude/commands/<skill_name>.md` instead, load env from `mainnet/.env`.

Do not ask about network again during the session unless the user explicitly asks to switch networks.
