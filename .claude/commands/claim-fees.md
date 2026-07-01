Collect accrued UniswapV3 trading fees from a position into a BittyVault on Sepolia.

**Usage:** `/claim-fees <token_id>`

- `<token_id>` — UniswapV3 NFT position token ID

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as one part. If missing, stop and print usage.

---

## Hardcoded Sepolia configuration

AMM protocol: `0xf4dAFAb9E813A8c69EDA1cB27f1A49b42b7aF50b`

UniswapV3 NonfungiblePositionManager (Sepolia): `0x1238536071E1c677A632429e3655c799b22cDA52`

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Fetch position info and uncollected fees

```bash
cast call 0x1238536071E1c677A632429e3655c799b22cDA52 \
  "positions(uint256)(uint96,address,address,address,uint24,int24,int24,uint128,uint256,uint256,uint128,uint128)" \
  "<token_id>" \
  --rpc-url "<rpc_url>"
```

Extract:
- `token0` (field index 2)
- `token1` (field index 3)
- `tokensOwed0` (field index 10) — uncollected fees in token0
- `tokensOwed1` (field index 11) — uncollected fees in token1

If both `tokensOwed0` and `tokensOwed1` are 0, print:
```
No uncollected fees for position <token_id>. Nothing to claim.
```
and stop.

### 3. Check vault token balances before

```bash
cast call <token0_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"

cast call <token1_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

Save as `<balance0_before>` and `<balance1_before>`.

### 4. Encode calldata

**CollectParams** (tokenId, recipient — overridden by vault, amount0Max, amount1Max):
```bash
DATA=$(cast abi-encode \
  "f(uint256,address,uint128,uint128)" \
  "<token_id>" \
  "0x0000000000000000000000000000000000000000" \
  "340282366920938463463374607431768211455" \
  "340282366920938463463374607431768211455")
```

Note: `340282366920938463463374607431768211455` is `type(uint128).max` — collects all available fees.
The `recipient` field is ignored; the vault contract overrides it to send fees to itself.

### 5. Show preview and ask for confirmation

Print:
```
Vault              : $VAULT_ADDRESS
Token ID           : <token_id>
Token0             : <token0_address>
Token1             : <token1_address>
Uncollected fees0  : <tokensOwed0> (raw)
Uncollected fees1  : <tokensOwed1> (raw)
AMM protocol       : 0xf4dAFAb9E813A8c69EDA1cB27f1A49b42b7aF50b
```

Ask: "Proceed with claiming fees? (yes/no)"
If no, stop.

### 6. Call claimAMMFees on the vault

```bash
cast send $VAULT_ADDRESS \
  "claimAMMFees(address,bytes)" \
  "0xf4dAFAb9E813A8c69EDA1cB27f1A49b42b7aF50b" \
  "$DATA" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop.

### 7. Show result

Fetch vault token balances after the tx:

```bash
cast call <token0_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"

cast call <token1_address> "balanceOf(address)(uint256)" $VAULT_ADDRESS \
  --rpc-url "<rpc_url>"
```

Print:
```
Fees claimed!
  Tx hash         : <tx_hash>
  Etherscan        : https://sepolia.etherscan.io/tx/<tx_hash>
  Token ID        : <token_id>
  Token0 received : <balance0_after - balance0_before> (raw)
  Token1 received : <balance1_after - balance1_before> (raw)
```
