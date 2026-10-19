# BittyVault Claude Code Skills

Claude Code slash commands for managing a [BittyVault](https://github.com/bittyIO/vault) DeFi vault on Ethereum — activate, fund, swap, lend, stake, and place gasless CoW orders, all from the Claude Code CLI.

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

It walks through 9 steps interactively: create an AI asset manager key, have the owner activate the
vault (with the manager installed in the same transaction), fund it, swap at market, supply to Aave,
stake in Lido, and place and cancel a gasless CoW limit order. Because a new vault's asset manager
takes effect a day after activation, the demo pauses after funding; re-run it the next day to finish.

## Skills reference

### Setup

| Skill | Usage | Description |
|-------|-------|-------------|
| `/quickstart` | `/quickstart <owner> [amount]` | End-to-end demo — runs all steps in sequence |
| `/new-assetmanager` | `/new-assetmanager [vault]` | Create/import the AI asset manager key; owner installs it |
| `/deploy-vault` | `/deploy-vault <owner>` | Prepare the owner's `activateVault` tx (enables CoW, installs the manager) |
| `/fund-vault` | `/fund-vault [eth_amount]` | Send ETH to the vault — it wraps to WETH on arrival |
| `/vault-balances` | `/vault-balances` | Wallet, Aave and Lido balances plus manager, risk and lock state |

### Asset manager skills

Requires `PRIVATE_KEY` in `.env` (the asset manager's hot wallet key). What the key may do is set by
the owner's grant: an expiry (at most 1 year) and a permission mask — `1` stake, `2` supply,
`4` market trade, `8` CoW orders. Withdrawing, claiming and cancelling need no permission. A manager
can never send funds out of the vault.

| Skill | Usage | Description |
|-------|-------|-------------|
| `/rebalance` | `/rebalance <from> <to> <sell> [slippage_bps]` | Market swap via the Uniswap Universal Router |
| `/supply` | `/supply <asset> <amount\|max>` | Deposit into Aave lending |
| `/withdraw` | `/withdraw <asset> <amount\|max>` | Withdraw from Aave |
| `/stake` | `/stake WETH <amount\|max>` | Deposit WETH into Lido (receives stETH) |
| `/unstake` | `/unstake WETH <amount\|max>` | Open a Lido withdrawal request |
| `/claim-unstaked` | `/claim-unstaked [id ...]` | Claim finalized Lido withdrawals |
| `/limit-sell` | `/limit-sell <from> <to> <sell> <buy_min> [ttl]` | Gasless CoW limit sell (signed off-chain) |
| `/limit-buy` | `/limit-buy <from> <to> <buy> <sell_max> [ttl]` | Gasless CoW limit buy |
| `/cancel-order` | `/cancel-order <uid>` | Invalidate a CoW order on-chain |
| `/twap-sell` | `/twap-sell <from> <to> <total> <min_per_part> <n> <interval>` | Gasless TWAP, one signature for every part |
| `/twap-buy` | `/twap-buy <from> <to> <total_buy> <sell_per_part> <n> <interval>` | Gasless DCA |
| `/post-twap-part` | `/post-twap-part <schedule_file>` | Post the current TWAP part (run each interval) |
| `/cancel-twap` | `/cancel-twap <schedule_file>` | Invalidate every remaining TWAP part on-chain |

CoW orders are signed and posted by `scripts/cow.sh` (needs `cast`, `curl`, `python3`), which checks
each order against the vault's own CoW clone before posting. `RPC_URL=<rpc> PRIVATE_KEY=0x01 scripts/cow.sh selftest`
verifies its EIP-712 encoding against `cast`'s signer.

### Vault owner management

Owner operations (assets, protocols, whitelisted recipients, sends, risk settings, locks, the asset
manager grant) are intentionally **not** CLI skills. The vault owner is typically a hardware wallet or
multisig, and its key must never be exposed to the CLI. Skills that need an owner action print the
exact call for the owner to send from their own wallet; everything else is in the web app under
**Manage**.

## Sepolia contract addresses

Protocols are read from the guard on-chain at run time; the addresses below are for reference.

| Contract | Address |
|----------|---------|
| BittyV1VaultFactory | `0x3d7Ed3cD011B423dd11BE280BF926667CAf0F120` |
| Bitty Guard | `0x000000000F5fcD35885BfE4c700042cE7cb39554` |
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` |
| USDC | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` |
| Aave V3 Protocol | `0x9C01F9b6Ed7BbD86f7a309A3414595608AB9d80d` |
| Lido V2 Protocol | `0x9f6D7B2DeFCF45Cb837560209099083DDF59840a` |
| Uniswap Universal Trade Protocol | `0x67Bd4c240d513E7eb35Bf8d871cbeD314856b125` |
| CoW Swap V1 Protocol | `0x236b4b260BD29DCA1Df29360FA09C084e37fB100` |

## Known Sepolia limitations

- **New vaults** start with a 1-day change timelock, so an asset manager installed at activation takes effect 24 hours later. They also start with $10,000/day send and market-trade loss allowances.
- **Aave**: only WBTC can be supplied (WETH/USDC have no reserve, USDT is over its supply cap). Mint test WBTC from Aave's faucet `0xC959483DBa39aa9E78757139af0e9a2EDEb3f42D` — see `/supply`.
- **Lido withdrawals**: the Lido withdrawal queue is paused on Sepolia — staking works, unstake requests revert.
- **Market trades**: only v4 pools are executable through Sepolia's Universal Router, and test pools are mispriced, so the 5% oracle band rejects one direction of most pairs. WBTC is not market-tradeable (use CoW).
- **Mainnet**: the v1.0 vault is not deployed on mainnet yet; `mainnet/.claude/commands/` still targets the previous mainnet deployment.

## License

MIT
