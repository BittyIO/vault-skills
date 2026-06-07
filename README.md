# BittyVault Claude Code Skills

Claude Code slash commands for managing a [BittyVault](https://github.com/your-org/bittyvault) DeFi vault on Ethereum — deploy, fund, swap, lend, stake, and manage liquidity, all from the Claude Code CLI.

## Prerequisites

- [Claude Code](https://claude.ai/code) installed
- [Foundry](https://getfoundry.sh) (`cast` in your PATH)
- An Alchemy API key for Sepolia RPC access
- A `.env` file in your working directory:

```bash
ALCHEMY_KEY=your_alchemy_key_here
PRIVATE_KEY=            # filled in by /new-assetmanager
VAULT_ADDRESS=          # filled in by /deploy-vault
```

## Install

```bash
git clone https://github.com/your-org/vault-skills
cd vault-skills
# Open Claude Code here — skills load automatically
claude
```

> Skills live in `.claude/commands/` and are picked up by Claude Code automatically when you open it in this directory.

## Quick start

Run the full end-to-end demo in one command:

```
/quickstart <owner_address>
```

This walks through all 11 steps interactively: generate an AI asset manager, deploy a vault, fund it with WETH, swap, supply to Aave, stake in Lido, and more.

## Skills reference

| Skill | Usage | Description |
|-------|-------|-------------|
| `/quickstart` | `/quickstart <owner> [amount]` | End-to-end demo — runs all steps in sequence |
| `/new-assetmanager` | `/new-assetmanager` | Generate a fresh AI asset manager keypair |
| `/deploy-vault` | `/deploy-vault <owner> [name]` | Deploy a new BittyVault via the factory |
| `/fund-vault` | `/fund-vault [amount_each]` | Wrap ETH → WETH/WETH_UNI/WETH_AAVE and send to vault |
| `/vault-balances` | `/vault-balances` | Show all asset balances held in the vault |
| `/rebalance` | `/rebalance <from> <to> <sell> <buy_min> [fee]` | Swap between assets via Uniswap V3 |
| `/supply` | `/supply <asset> <amount>` | Supply an asset to Aave lending |
| `/withdraw` | `/withdraw <asset> <amount\|max>` | Withdraw a supplied asset from Aave |
| `/stake` | `/stake <asset> <amount\|max>` | Stake WETH in Lido |
| `/unstake` | `/unstake <asset> <amount\|max>` | Request unstake from Lido |
| `/claim-unstaked` | `/claim-unstaked [id ...]` | Claim finalized Lido withdrawal requests |
| `/add-liquidity` | `/add-liquidity mint\|increase ...` | Add liquidity to a Uniswap V3 position |
| `/remove-liquidity` | `/remove-liquidity <tokenId> <pct> <deadline>` | Remove liquidity from a Uniswap V3 position |
| `/claim-fees` | `/claim-fees <tokenId>` | Collect accumulated Uniswap V3 fees |

## Sepolia contract addresses

| Contract | Address |
|----------|---------|
| BittyVaultFactory | `0x000000007aBb59ca6E74308f1860557eDe1A285d` |
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` |
| WETH (Uniswap) | `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14` |
| WETH (Aave) | `0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c` |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` |
| Aave V3 Protocol | `0x3b9384Ea4db89Af8Af54489779333b5A9c2b0436` |
| Lido V2 Protocol | `0x2Db440cF6215d68d44736A287B253F4461399aa0` |
| Uniswap V3 Protocol | `0x0feC90C103d43Bfb43f65494766F53782f8e05bA` |

## Known Sepolia limitations

- **USDC on Aave**: USDC reserve is frozen (error 51) — use WETH_AAVE for lending demos instead
- **Lido withdrawals**: The Lido withdrawal queue is paused on Sepolia — staking works but unstake requests will revert
- **`buyAmountMin`**: Must be `≥ 1` (not `0`) on all rebalance calls

## License

MIT
