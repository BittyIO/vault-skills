Remove liquidity from a UniswapV3 position held by a BittyVault on Ethereum mainnet.

This decreases the position's liquidity and collects both tokens back to the vault in a single transaction.

**Usage:** `/remove-liquidity <token_id> <liquidity_percent> <deadline_minutes>`

- `<token_id>` — UniswapV3 NFT position token ID
- `<liquidity_percent>` — percentage of liquidity to remove: `1`–`100` (use `100` to exit fully)
- `<deadline_minutes>` — tx deadline in minutes from now (e.g. `10`)

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as three parts. If any are missing, stop and print usage.

---

## Hardcoded mainnet configuration

UniswapV3 NonfungiblePositionManager (mainnet): `0xC36442b4a4522E871399CD717aBDD847Ab11FE88`

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

Then resolve the AMM protocol registered on the vault:

```bash
AMM_PROTOCOL=$(cast call $VAULT_ADDRESS "getAMMProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[] ' | cut -d, -f1)
```

If `$AMM_PROTOCOL` is empty, stop: `Error: no Uniswap AMM protocol registered on this vault.`

### 2. Fetch current position info

```bash
cast call 0xC36442b4a4522E871399CD717aBDD847Ab11FE88 \
  "positions(uint256)(uint96,address,address,address,uint24,int24,int24,uint128,uint256,uint256,uint128,uint128)" \
  "<token_id>" \
  --rpc-url "<rpc_url>"
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
  --rpc-url "<rpc_url>"

cast call <token1_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
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
⚠ This is Ethereum mainnet — real funds will be used.

Vault              : $VAULT_ADDRESS
Token ID           : <token_id>
Token0             : <token0_address>
Token1             : <token1_address>
Fee tier           : <fee>
Current liquidity  : <current_liquidity>
Removing           : <liquidity_percent>% → <LIQUIDITY_TO_REMOVE> units
Deadline           : <deadline_minutes> min from now
AMM protocol       : $AMM_PROTOCOL
```

Ask: "Proceed with removing liquidity? (yes/no)"
If no, stop.

### 8. Call removeLiquidity on the vault

```bash
cast send $VAULT_ADDRESS \
  "removeLiquidity(address,bytes)" \
  "$AMM_PROTOCOL" \
  "$DATA" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 9. Show result

Fetch vault token balances after the tx:

```bash
cast call <token0_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"

cast call <token1_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

Print:
```
Liquidity removed!
  Tx hash          : <tx_hash>
  Etherscan        : https://etherscan.io/tx/<tx_hash>
  Token ID         : <token_id>
  Liquidity removed: <LIQUIDITY_TO_REMOVE> (<liquidity_percent>%)
  Token0 received  : <balance0_after - balance0_before> (raw)
  Token1 received  : <balance1_after - balance1_before> (raw)
```
