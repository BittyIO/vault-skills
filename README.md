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
git clone https://github.com/BittyIO/vault-skills
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

### Setup

| Skill | Usage | Description |
|-------|-------|-------------|
| `/quickstart` | `/quickstart <owner> [amount]` | End-to-end demo — runs all steps in sequence |
| `/new-assetmanager` | `/new-assetmanager` | Generate a fresh AI asset manager keypair |
| `/deploy-vault` | `/deploy-vault <owner> [name]` | Deploy a new BittyVault via the factory |
| `/fund-vault` | `/fund-vault [amount_each]` | Wrap ETH → WETH/WETH_UNI/WETH_AAVE and send to vault |
| `/vault-balances` | `/vault-balances` | Show all asset balances held in the vault |

### Asset manager skills (ASSET_MANAGER_ROLE)

Requires `PRIVATE_KEY` in `.env` (the asset manager's hot wallet key).

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

### Owner skills (DEFAULT_ADMIN_ROLE)

Requires `OWNER_PRIVATE_KEY` in `.env` (the vault owner's key — typically a hardware wallet or multi-sig signer).

| Skill | Usage | Description |
|-------|-------|-------------|
| `/set-name` | `/set-name <new_name>` | Set the vault's display name |
| `/add-assets` | `/add-assets <asset1> [asset2] ...` | Add tradeable assets to the vault |
| `/remove-assets` | `/remove-assets <asset1> [asset2] ...` | Remove assets from the vault |
| `/lock-assets` | `/lock-assets` | **Irreversible** — permanently disable adding new assets |
| `/add-protocols` | `/add-protocols <type> <addr1> ...` | Add lending/staking/AMM protocols |
| `/remove-protocols` | `/remove-protocols <type> <addr1> ...` | Remove lending/staking/AMM protocols |
| `/lock-protocols` | `/lock-protocols` | **Irreversible** — permanently disable adding new protocols |
| `/set-rebalance-config` | `/set-rebalance-config <asset> <min_bal> <min_dur> <max_amt>` | Set per-asset rebalance limits |
| `/add-receiver` | `/add-receiver <name> <addr> <asset> <amt> <count> <start> <dur>` | Add a payment receiver |
| `/update-receiver` | `/update-receiver <name> <addr> <asset> <amt> <count> <start> <dur>` | Update an existing receiver |
| `/remove-receiver` | `/remove-receiver <name>` | Remove a payment receiver |
| `/set-receiver-protection` | `/set-receiver-protection <seconds>` | Set time-lock for new receivers |
| `/pay-receiver` | `/pay-receiver <name> [amount]` | Trigger a payment to a receiver |
| `/grant-role` | `/grant-role <address>` | Grant ASSET_MANAGER_ROLE to an address |
| `/revoke-role` | `/revoke-role <address>` | Revoke ASSET_MANAGER_ROLE from an address |

## Sepolia contract addresses

| Contract | Address |
|----------|---------|
| BittyVaultFactory | `0x00000000C600356864798327A5b11bdd636656e3` |
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` |
| WETH (Uniswap) | `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14` |
| WETH (Aave) | `0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c` |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` |
| Aave V3 Protocol | `0x1e115f5527b860eC1c67967bc96c4FAbf39cFD80` |
| Lido V2 Protocol | `0xAa83429F9ab50DA9F4bABEA6b66238f558A1550C` |
| Uniswap V3 Protocol | `0x8897C6DcbA33C842DffC1be4B58c73b2eC6869E3` |

## Known Sepolia limitations

- **USDC on Aave**: USDC reserve is frozen (error 51) — use WETH_AAVE for lending demos instead
- **Lido withdrawals**: The Lido withdrawal queue is paused on Sepolia — staking works but unstake requests will revert
- **`buyAmountMin`**: Must be `≥ 1` (not `0`) on all rebalance calls

## License

MIT
