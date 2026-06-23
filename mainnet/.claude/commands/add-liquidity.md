Add liquidity to a UniswapV3 position from a BittyVault on Ethereum mainnet.

Supports two modes:
- **Mint** — create a new liquidity position (NFT)
- **Increase** — add liquidity to an existing position by token ID

**Usage:**
```
/amm-add-liquidity mint <token0> <amount0> <token1> <amount1> <fee_tier> <tick_lower> <tick_upper> <deadline_minutes>
/amm-add-liquidity increase <token_id> <amount0> <amount1> <deadline_minutes>
```

Arguments: $ARGUMENTS

Parse the first token as the mode (`mint` or `increase`). If missing or invalid, stop and print usage.

---

## Hardcoded mainnet configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | 18 |
| WBTC | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` | 8 |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | 6 |
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` | 6 |
| USDS | `0xdC035D45d973E3EC169d2276DDab16f1e407384F` | 18 |

AMM protocol (UniswapV3): `0x771477609736d06558e3f1D3eeF8AEC40d971FBb`

**Tick spacing by fee tier** (ticks must be multiples of spacing):
| Fee | Spacing |
|-----|---------|
| 100 | 1 |
| 500 | 10 |
| 3000 | 60 |
| 10000 | 200 |

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Compute deadline

```bash
DEADLINE=$(( $(date +%s) + <deadline_minutes> * 60 ))
```

---

## Mode: mint (new position)

### 3a. Resolve token addresses and decimals

Resolve `<token0>` and `<token1>` from the symbol table or fetch decimals for raw addresses.

Uniswap requires token0 address < token1 address. Check and swap if needed:
```bash
# Compare addresses numerically (cast --to-dec)
```
Print a warning if you reorder them so the user knows.

### 4a. Convert amounts to raw units

- 18 decimals: `cast to-unit <amount>ether wei`
- Other decimals: `<amount> * 10^<decimals>` as integer

Set `amount0Min = 0` and `amount1Min = 0` (slippage accepted at mint; tighten post-launch if needed).

### 5a. Encode calldata for mint

**Encode MintParams:**
```bash
MINT_PARAMS=$(cast abi-encode \
  "f(address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256)" \
  "<token0_address>" "<token1_address>" "<fee_tier>" \
  "<tick_lower>" "<tick_upper>" \
  "<amount0_raw>" "<amount1_raw>" \
  "0" "0" \
  "0x0000000000000000000000000000000000000000" \
  "$DEADLINE")
```

**Wrap in outer data (isMint=true):**
```bash
DATA=$(cast abi-encode "f(bool,bytes)" "true" "$MINT_PARAMS")
```

### 6a. Check vault balances

```bash
cast call <token0_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call <token1_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Stop if either balance < the requested amount.

### 7a. Show preview and ask for confirmation

Print:
```
⚠ This is Ethereum mainnet — real funds will be used.

Mode          : Mint new position
Vault         : $VAULT_ADDRESS
Token0        : <token0_symbol> (<token0_address>)
Token1        : <token1_symbol> (<token1_address>)
Amount0       : <amount0> (<amount0_raw> raw)
Amount1       : <amount1> (<amount1_raw> raw)
Fee tier      : <fee_tier>
Tick range    : [<tick_lower>, <tick_upper>]
Deadline      : <deadline_minutes> min from now
AMM protocol  : 0x771477609736d06558e3f1D3eeF8AEC40d971FBb
```

Ask: "Proceed? (yes/no)"

### 8a. Call addLiquidity on the vault

```bash
cast send $VAULT_ADDRESS \
  "addLiquidity(address,address,uint256,address,uint256,bytes)" \
  "0x771477609736d06558e3f1D3eeF8AEC40d971FBb" \
  "<token0_address>" "<amount0_raw>" \
  "<token1_address>" "<amount1_raw>" \
  "$DATA" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

Print tx hash and Etherscan link. Remind the user to save the NFT token ID from the transaction logs for future `increase` and `remove-liquidity` calls.

---

## Mode: increase (existing position)

### 3b. Fetch token0 and token1 from the existing position

```bash
cast call 0xC36442b4a4522E871399CD717aBDD847Ab11FE88 \
  "positions(uint256)(uint96,address,address,address,uint24,int24,int24,uint128,uint256,uint256,uint128,uint128)" \
  "<token_id>" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

The Uniswap V3 NonfungiblePositionManager on mainnet is `0xC36442b4a4522E871399CD717aBDD847Ab11FE88`.

Extract `token0` (field 3) and `token1` (field 4) from the result. Resolve their decimals.

### 4b. Convert amounts to raw units

Same as step 4a.

### 5b. Encode calldata for increase

```bash
INCREASE_PARAMS=$(cast abi-encode \
  "f(uint256,uint256,uint256,uint256,uint256,uint256)" \
  "<token_id>" "<amount0_raw>" "<amount1_raw>" "0" "0" "$DEADLINE")

DATA=$(cast abi-encode "f(bool,bytes)" "false" "$INCREASE_PARAMS")
```

### 6b. Check vault balances

Same as step 6a.

### 7b. Show preview and ask for confirmation

Print:
```
⚠ This is Ethereum mainnet — real funds will be used.

Mode          : Increase existing position
Vault         : $VAULT_ADDRESS
Token ID      : <token_id>
Token0        : <token0_address>
Token1        : <token1_address>
Amount0       : <amount0> (<amount0_raw> raw)
Amount1       : <amount1> (<amount1_raw> raw)
Deadline      : <deadline_minutes> min from now
AMM protocol  : 0x771477609736d06558e3f1D3eeF8AEC40d971FBb
```

Ask: "Proceed? (yes/no)"

### 8b. Call addLiquidity on the vault

Same cast send as step 8a.
