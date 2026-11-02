# BittyVault Claude Code Skills

Claude Code slash commands for the **asset manager** of a [BittyVault](https://github.com/bittyIO/vault)
**1.0.7** vault — lend, stake, swap and place CoW limit / TWAP orders — from the Claude Code CLI.

Everything owner-side — activating the vault, appointing the asset manager, allow lists, risk
settings, locks, sends, upgrades — lives in the Bitty web and mobile apps, where the owner signs with
their own wallet. **The owner key never touches this CLI:** the skills refuse it.

> **1.0.7 vaults.** An older vault is refused; the owner upgrades it in the Bitty app. CoW orders also
> need the vault's CoW clone on adapter 1.0.4 or later.

## Prerequisites

- [Claude Code](https://claude.ai/code) installed
- [Foundry](https://getfoundry.sh) (`cast` in your PATH), `curl` and `python3`
- An Alchemy API key for RPC access (optional — falls back to a public endpoint)

## Setup

```bash
git clone https://github.com/BittyIO/vault-skills
cd vault-skills
```

Per network, a `.env` in `sepolia/` or `mainnet/`:

```bash
PRIVATE_KEY=            # the asset manager's hot-wallet key — never the owner's
VAULT_ADDRESS=          # the vault that appointed it
ALCHEMY_KEY=            # optional
RPC_URL=                # optional: your own node (or a local fork); wins over ALCHEMY_KEY
```

Then open Claude Code in the repo (`claude`). It asks which network to use and stores the choice in
`.env` as `NETWORK=sepolia|mainnet`. The skills in `.claude/commands/` load automatically.

No key or vault yet? `/new-assetmanager` creates the key and saves it, and `/deploy-vault <owner>`
prepares the owner's activation transaction. On Sepolia, `/quickstart <owner>` walks through all of it.

## The asset manager

The owner appoints one asset manager per vault, with an expiry (at most a year) and a permission
mask. The asset manager can invest and trade, within the owner's daily loss allowance, but never pay
anyone. Each skill checks the grant first and says which permission is missing, if any.

| Bit | Permission | Allows |
|-----|------------|--------|
| 1 | `YIELD` | staking in and out (Lido, Sky), claiming unstaked withdrawals |
| 2 | `SUPPLY` | lending in and out (Aave) |
| 4 | `MARKET_TRADE` | market swaps |
| 8 | `INTENT` | CoW limit and TWAP orders, and cancelling them |

When the owner locks the vault, the grant goes dormant and nothing works until they unlock it.

## Skills

### Setup

These never take the owner's key: whatever the owner must do, they print for the owner to send from
their own wallet (or do in the Bitty app).

| Skill | Usage | Description |
|-------|-------|-------------|
| `/quickstart` | `/quickstart <owner> [amount]` | Sepolia end-to-end demo, every step below in order |
| `/new-assetmanager` | `/new-assetmanager [vault]` | Create or import the asset manager key; the owner appoints it |
| `/deploy-vault` | `/deploy-vault <owner>` | Prepare the owner's `activateVault` (enables CoW, appoints the manager) |
| `/fund-vault` | `/fund-vault [eth_amount]` | Send ETH to the vault — it wraps to WETH on arrival |

### Asset manager

| Skill | Usage | Needs | Description |
|-------|-------|-------|-------------|
| `/vault-balances` | `/vault-balances` | — | Your grant, wallet balances, positions, pending withdrawals, open orders |
| `/supply` | `/supply <asset> <amount\|max>` | `SUPPLY` | Supply to a lending protocol (Aave) |
| `/withdraw` | `/withdraw <asset> <amount\|max>` | `SUPPLY` | Withdraw from a lending protocol |
| `/stake` | `/stake <asset> <amount\|max>` | `YIELD` | Stake WETH in Lido or USDC in Sky |
| `/unstake` | `/unstake <asset> <amount\|max>` | `YIELD` | Unstake (Sky at once; Lido requests a withdrawal) |
| `/claim-withdrawals` | `/claim-withdrawals [id …]` | `YIELD` | Claim finalised Lido withdrawals |
| `/market-sell` | `/market-sell <from> <to> <amount\|max> [slippage_bps]` | `MARKET_TRADE` | Market swap through the Uniswap Universal Router |
| `/limit-sell` | `/limit-sell <from> <to> <sell> <buy_min> [valid_for]` | `INTENT` | CoW limit sell |
| `/limit-buy` | `/limit-buy <from> <to> <buy> <sell_max> [valid_for]` | `INTENT` | CoW limit buy |
| `/twap-sell` | `/twap-sell <from> <to> <total> <min_per_part> <parts> <interval>` | `INTENT` | CoW TWAP sell |
| `/twap-buy` | `/twap-buy <from> <to> <total_buy> <sell_per_part> <parts> <interval>` | `INTENT` | CoW TWAP buy (DCA) |
| `/cancel-intent-order` | `/cancel-intent-order [uid …]` | `INTENT` | Cancel CoW orders on chain |
| `/cancel-twap` | `/cancel-twap [app_data]` | `INTENT` | Cancel every part of a TWAP |

How the pieces fit:
- **Protocols are read from the guard on chain** — nothing in this repo lists adapter addresses.
- **Swaps** take a route the Bitty API builds (`/api/ethereum/trade/route`); the vault holds the
  trade to oracle value and the owner's daily loss allowance.
- **CoW orders are gasless.** The asset manager signs a Bitty `VaultOrder` (the CoW order nested
  whole, with the vault named), and the vault is the ERC-1271 signer CoW checks at settlement. The
  only transaction is a one-off `approveIntentSpender` per sell token. The owner enables CoW once in
  the Bitty app, which creates the vault's CoW clone.
- **TWAPs** are signed once; part 0 is posted at once and the Bitty API posts each later part as its
  slot opens. Cancelling invalidates every part's UID on chain.
- **`bin/bitty`** is the shared helper the skills call: network constants, the preflight, protocol
  discovery, units, and the CoW order hashing and signing. `bin/bitty help` lists it.
- **`abi/`** holds the ABIs the skills are written against: `vault-1.0.7.json` (vault and DeFi facet)
  and `cow-1.0.4.json` (the CoW adapter).

## Contract addresses

Same on Sepolia and mainnet:

| Contract | Address |
|----------|---------|
| BittyGuard | `0x000000000F5fcD35885BfE4c700042cE7cb39554` |
| BittyVaultFactory | `0x3d7Ed3cD011B423dd11BE280BF926667CAf0F120` |
| TrustedForwarder | `0xD6013C5e339cd3546c0c7E86c306554a63FbAa6F` |
| CoW GPv2Settlement | `0x9008D19f58AAbD9eD0D60971565AA8510560ab41` |

Tokens:

| Token | Sepolia | Mainnet |
|-------|---------|---------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` |
| USDC | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | `0xdAC17F958D2ee523a2206206994597C13D831ec7` |

## Known Sepolia limitations

- **New vaults** start with a 1-day timelock, so an asset manager appointed at activation takes
  effect a day later. They also start with 10,000 USD/day send and market-loss allowances.
- **Market trades** — only v4 pools are executable through Sepolia's Universal Router, and test pools
  are mispriced, so the 5% oracle band rejects one direction of most pairs. WBTC is not
  market-tradeable (use CoW).

- **Aave** — Sepolia's Aave lists its own WETH and USDC, not the ones above, so only **WBTC** and
  **USDT** can be supplied; USDT is at its supply cap (error 51). Use WBTC for lending demos.
- **Lido withdrawals** — the queue is paused on Sepolia; staking works, unstaking reverts.
- **CoW** — few solvers run on Sepolia, so orders may sit unfilled.

## License

MIT
