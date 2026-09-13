# BittyVault Claude Code Skills

Claude Code slash commands for the **delegated roles** of a [BittyVault](https://github.com/bittyIO/vault) — the **asset manager** (swap, lend, stake, manage liquidity), the **payout operator** (propose payments), and the **sub owner** (operate a sub-vault funded by the owner) — all from the Claude Code CLI.

Everything owner-side — activating the vault, granting these roles, approving proposals, risk settings, giving up ownership — lives in the Bitty web app, where the owner signs with their own wallet. Vault ownership is **non-transferable** (one address, one vault, renounce-to-zero only), so there are no ownership skills here by design: the owner key never touches this CLI.

## Prerequisites

- [Claude Code](https://claude.ai/code) installed
- [Foundry](https://getfoundry.sh) (`cast` in your PATH)
- An Alchemy API key for RPC access (optional — falls back to a public endpoint)
- A `.env` file in your working directory:

```bash
ALCHEMY_KEY=your_alchemy_key_here
PRIVATE_KEY=            # the asset manager's or payout operator's hot-wallet key
VAULT_ADDRESS=          # the vault you hold a seat in (the owner grants seats in the web app)
```

## Install

```bash
git clone https://github.com/BittyIO/vault-skills
cd vault-skills
# Open Claude Code here — skills load automatically
claude
```

> Skills live in `.claude/commands/` and are picked up by Claude Code automatically when you open it in this directory.

## Skills reference

### Shared

| Skill | Usage | Description |
|-------|-------|-------------|
| `/vault-balances` | `/vault-balances` | Show all asset balances held in the vault |

### Asset manager skills

Requires `PRIVATE_KEY` in `.env` (the asset manager's hot wallet key, set by the owner via `setAssetManager` / `setFullAssetManager` in the web app).

| Skill | Usage | Description |
|-------|-------|-------------|
| `/rebalance` | `/rebalance <from> <to> <sell> <buy_min> [fee]` | Swap between assets via Uniswap V3 |
| `/supply` | `/supply <asset> <amount>` | Supply an asset to Aave lending |
| `/withdraw` | `/withdraw <asset> <amount\|max>` | Withdraw a supplied asset from Aave |
| `/stake` | `/stake <asset> <amount\|max>` | Stake WETH in Lido |
| `/unstake` | `/unstake <asset> <amount\|max>` | Request unstake from Lido |
| `/claim-unstaked` | `/claim-unstaked [id ...]` | Claim finalized Lido withdrawal requests |
| `/add-liquidity` | `/add-liquidity mint\|increase ...` | Add liquidity to a Uniswap V3 position |
| `/remove-liquidity` | `/remove-liquidity <tokenId> <pct> <deadline>` | Remove liquidity from a Uniswap V3 position |
| `/claim-fees` | `/claim-fees <tokenId>` | Collect accumulated Uniswap V3 fees |

### Payout operator skills

Requires `PRIVATE_KEY` in `.env` (a payout operator's key, granted a seat by the owner via `setPayoutOperator` in the web app). Proposals never move funds by themselves — the owner approves them in the web app.

| Skill | Usage | Description |
|-------|-------|-------------|
| `/propose-payment` | `/propose-payment <recipient> <asset> <amount> <every_days> [count]` | Propose a scheduled payment (pending owner approval) |
| `/propose-send` | `/propose-send <recipient> <asset> <amount>` | Propose a one-off send within the operator's rolling quota (pending owner approval) |
| `/pay-scheduled` | `/pay-scheduled <id> [amount]` | Trigger a due scheduled payment by id (permissionless) |

### Sub-vault (sub owner) skills

A vault owner can grant a **sub-account** (a sub-vault) and name a **sub owner** for it in the Bitty web app. The sub owner sets `VAULT_ADDRESS` in `.env` to the **sub-vault address** (not the parent vault) and runs the same trade/earn skills against it — the shared vault facet treats the sub owner as `owner()` inside the sub-vault, so `/rebalance`, `/supply`, `/withdraw`, `/stake`, `/unstake`, `/claim-unstaked`, `/limit-buy`, `/limit-sell`, `/add-liquidity`, `/remove-liquidity`, `/claim-fees`, `/vault-balances`, etc. all work unchanged.

Two operations are unique to the sub owner. Requires `PRIVATE_KEY` in `.env` (the sub owner's key) and `VAULT_ADDRESS` set to the sub-vault.

| Skill | Usage | Description |
|-------|-------|-------------|
| `/return-to-vault` | `/return-to-vault <asset> <amount\|max> [<asset> <amount\|max> ...]` | Return assets from the sub-vault to the parent (the only way value leaves a sub-account) |
| `/sub-gasless` | `/sub-gasless <daily_limit> <max_fee_per_op>` | Set the sub-vault's gasless daily budget and per-operation fee cap |

### Vault owner management

Owner operations (activation, assets, protocols, approvals, roles, risk settings, giving up ownership) are intentionally **not** CLI skills. The vault owner is typically a hardware wallet or multisig, and its key must never be exposed to the CLI. Manage these from the web app instead, signing with the connected owner wallet.

## Sepolia contract addresses

| Contract | Address |
|----------|---------|
| BittyVaultFactory | `0xCe9c32Bf9720027EE0137153A3C5BC803570DCbf` |
| BittyGuard | `0x00006Dc0000DBB00d9bd462ad2005E20007e0Dc7` |
| TrustedForwarder | `0xfB49bE0861AC05bC690327076130342966429c03` |
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` |
| USDC | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` |
| Aave adapter | `0x9C01F9b6Ed7BbD86f7a309A3414595608AB9d80d` |
| Lido adapter | `0x9f6D7B2DeFCF45Cb837560209099083DDF59840a` |
| Uniswap adapter | `0xc701E8d66d2762044B34303509A2606e6b05bB73` |
| CoW adapter | `0x5A365990111B5A460526a25a8D4493dF103759DF` |

## Mainnet contract addresses

| Contract | Address |
|----------|---------|
| BittyVaultFactory | `0xCe9c32Bf9720027EE0137153A3C5BC803570DCbf` |
| BittyGuard | `0x00006Dc0000DBB00d9bd462ad2005E20007e0Dc7` |
| TrustedForwarder | `0xfB49bE0861AC05bC690327076130342966429c03` |
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` |
| WBTC | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` |
| Aave adapter | `0x9296f7fFE86dA8B652988f07920b42F8779ce64b` |
| Lido adapter | `0x35252547c41661103865d700d8fcACe07aFCe1Bd` |
| Sky adapter | `0x0968632AD0A79220fFb2d2320De82b7C17357774` |
| Uniswap adapter | `0xcE02C925850f8df20b5a6dE820e6773453240DbD` |
| CoW adapter | `0x3d7589CD35400e0a1b8D6F5f8Ed3AE4171A5E195` |

## Known Sepolia limitations

- **USDC on Aave**: USDC reserve is frozen (error 51) — use WETH for lending demos instead
- **Lido withdrawals**: The Lido withdrawal queue is paused on Sepolia — staking works but unstake requests will revert
- **`buyAmountMin`**: Must be `≥ 1` (not `0`) on all rebalance calls

## License

MIT
