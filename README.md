# BittyVault Claude Code Skills

Claude Code slash commands for the two **delegated roles** of a [BittyVault](https://github.com/bittyIO/vault) — the **asset manager** (swap, lend, stake, manage liquidity) and the **payout operator** (propose payments) — all from the Claude Code CLI.

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

### Vault owner management

Owner operations (activation, assets, protocols, approvals, roles, risk settings, giving up ownership) are intentionally **not** CLI skills. The vault owner is typically a hardware wallet or multisig, and its key must never be exposed to the CLI. Manage these from the web app instead, signing with the connected owner wallet.

## Sepolia contract addresses

| Contract | Address |
|----------|---------|
| BittyVaultFactory | `0x00008a00417a8Eeee5834e001DEFAE6aB600cB00` |
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` |
| WETH (Uniswap) | `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14` |
| WETH (Aave) | `0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c` |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` |
| Aave V3 Protocol | `0x472eDb79A83cC8470473Df20dD49a85E91769b98` |
| Lido V2 Protocol | `0x91F7682054cfE444A1E0e84F654010E2F7a69421` |
| Uniswap V3 Protocol | `0x68Edd39302545C2DFd3a8B25e36Da8059bacbD26` |

## Known Sepolia limitations

- **USDC on Aave**: USDC reserve is frozen (error 51) — use WETH_AAVE for lending demos instead
- **Lido withdrawals**: The Lido withdrawal queue is paused on Sepolia — staking works but unstake requests will revert
- **`buyAmountMin`**: Must be `≥ 1` (not `0`) on all rebalance calls

## License

MIT
