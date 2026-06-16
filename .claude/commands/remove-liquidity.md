Remove liquidity from a UniswapV3 position held by a BittyVault on Sepolia.

This decreases the position's liquidity and collects both tokens back to the vault in a single transaction.

**Usage:** `/remove-liquidity <token_id> <liquidity_percent> <deadline_minutes>`

- `<token_id>` — UniswapV3 NFT position token ID
- `<liquidity_percent>` — percentage of liquidity to remove: `1`–`100` (use `100` to exit fully)
- `<deadline_minutes>` — tx deadline in minutes from now (e.g. `10`)

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as three parts. If any are missing, stop and print usage.

---

## Hardcoded Sepolia configuration

AMM protocol: `0x942C4b8DC8b43FAbD2d7D7a90b3FeFC003Cd9e81`

UniswapV3 NonfungiblePositionManager (Sepolia): `0x1238536071E1c677A632429e3655c799b22cDA52`

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Fetch current position info

```bash
cast call 0x1238536071E1c677A632429e3655c799b22cDA52 \
  "positions(uint256)(uint96,address,address,address,uint24,int24,int24,uint128,uint256,uint256,uint128,uint128)" \
  "<token_id>" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Extract:
- `token0` (field index 2)
- `token1` (field index 3)
- `fee` (field index 4)
- `liquidity` (field index 7) → save as `<current_liquidity>`

If `<current_liquidity>` is 0, stop and print:
```
Error: Position <token_id> has no liquidity.
```

### 3. Compute liquidity to remove

```bash
LIQUIDITY_TO_REMOVE=$(( <current_liquidity> * <liquidity_percent> / 100 ))
```

### 4. Compute deadline

```bash
DEADLINE=$(( $(date +%s) + <deadline_minutes> * 60 ))
```

### 5. Check vault token balances before (to measure received amounts)

```bash
cast call <token0_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call <token1_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Save as `<balance0_before>` and `<balance1_before>`.

### 6. Encode calldata

**DecreaseLiquidityParams** (tokenId, liquidity, amount0Min, amount1Min, deadline):
```bash
DATA=$(cast abi-encode \
  "f(uint256,uint128,uint256,uint256,uint256)" \
  "<token_id>" \
  "$LIQUIDITY_TO_REMOVE" \
  "0" "0" \
  "$DEADLINE")
```

### 7. Show preview and ask for confirmation

Print:
```
Vault              : $VAULT_ADDRESS
Token ID           : <token_id>
Token0             : <token0_address>
Token1             : <token1_address>
Fee tier           : <fee>
Current liquidity  : <current_liquidity>
Removing           : <liquidity_percent>% → <LIQUIDITY_TO_REMOVE> units
Deadline           : <deadline_minutes> min from now
AMM protocol       : 0x942C4b8DC8b43FAbD2d7D7a90b3FeFC003Cd9e81
```

Ask: "Proceed with removing liquidity? (yes/no)"
If no, stop.

### 8. Call removeLiquidity on the vault

```bash
cast send $VAULT_ADDRESS \
  "removeLiquidity(address,bytes)" \
  "0x942C4b8DC8b43FAbD2d7D7a90b3FeFC003Cd9e81" \
  "$DATA" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 9. Show result

Fetch vault token balances after the tx:

```bash
cast call <token0_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"

cast call <token1_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
Liquidity removed!
  Tx hash          : <tx_hash>
  Etherscan        : https://sepolia.etherscan.io/tx/<tx_hash>
  Token ID         : <token_id>
  Liquidity removed: <LIQUIDITY_TO_REMOVE> (<liquidity_percent>%)
  Token0 received  : <balance0_after - balance0_before> (raw)
  Token1 received  : <balance1_after - balance1_before> (raw)
```
