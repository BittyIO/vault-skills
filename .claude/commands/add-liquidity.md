Add liquidity to a UniswapV3 position from a BittyVault on Sepolia.

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

## Hardcoded Sepolia configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | 18 |
| WETH_UNI | `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14` | 18 |
| WETH_AAVE | `0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c` | 18 |
| WBTC | `0x29f2D40B0605204364af54EC677bD022dA425d03` | 8 |
| USDT | `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` | 6 |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` | 6 |

AMM protocol: `0x942C4b8DC8b43FAbD2d7D7a90b3FeFC003Cd9e81`

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
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call <token1_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Stop if either balance < the requested amount.

### 7a. Show preview and ask for confirmation

Print:
```
Mode          : Mint new position
Vault         : $VAULT_ADDRESS
Token0        : <token0_symbol> (<token0_address>)
Token1        : <token1_symbol> (<token1_address>)
Amount0       : <amount0> (<amount0_raw> raw)
Amount1       : <amount1> (<amount1_raw> raw)
Fee tier      : <fee_tier>
Tick range    : [<tick_lower>, <tick_upper>]
Deadline      : <deadline_minutes> min from now
AMM protocol  : 0x942C4b8DC8b43FAbD2d7D7a90b3FeFC003Cd9e81
```

Ask: "Proceed? (yes/no)"

### 8a. Call addLiquidity on the vault

```bash
cast send $VAULT_ADDRESS \
  "addLiquidity(address,address,uint256,address,uint256,bytes)" \
  "0x942C4b8DC8b43FAbD2d7D7a90b3FeFC003Cd9e81" \
  "<token0_address>" "<amount0_raw>" \
  "<token1_address>" "<amount1_raw>" \
  "$DATA" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

Print tx hash and Etherscan link. Remind the user to save the NFT token ID from the transaction logs for future `increase` and `remove-liquidity` calls.

---

## Mode: increase (existing position)

### 3b. Fetch token0 and token1 from the existing position

```bash
cast call <POSITION_MANAGER_ADDRESS> \
  "positions(uint256)(uint96,address,address,address,uint24,int24,int24,uint128,uint256,uint256,uint128,uint128)" \
  "<token_id>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

The Uniswap V3 NonfungiblePositionManager on Sepolia is `0x1238536071E1c677A632429e3655c799b22cDA52`.

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
Mode          : Increase existing position
Vault         : $VAULT_ADDRESS
Token ID      : <token_id>
Token0        : <token0_address>
Token1        : <token1_address>
Amount0       : <amount0> (<amount0_raw> raw)
Amount1       : <amount1> (<amount1_raw> raw)
Deadline      : <deadline_minutes> min from now
AMM protocol  : 0x942C4b8DC8b43FAbD2d7D7a90b3FeFC003Cd9e81
```

Ask: "Proceed? (yes/no)"

### 8b. Call addLiquidity on the vault

Same cast send as step 8a.
