Collect accrued UniswapV3 trading fees from a position into a BittyVault on Ethereum mainnet.

**Usage:** `/claim-fees <token_id>`

- `<token_id>` — UniswapV3 NFT position token ID

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as one part. If missing, stop and print usage.

---

## Hardcoded mainnet configuration

UniswapV3 NonfungiblePositionManager (mainnet): `0xC36442b4a4522E871399CD717aBDD847Ab11FE88`

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — set it in .env to a vault where your key holds a seat}"
```

Then resolve the AMM protocol registered on the vault:

```bash
AMM_PROTOCOL=$(cast call $VAULT_ADDRESS "getAMMProtocols()(address[])" --rpc-url "<rpc_url>" | tr -d '[] ' | cut -d, -f1)
```

If `$AMM_PROTOCOL` is empty, stop: `Error: no Uniswap AMM protocol registered on this vault.`

### 2. Fetch position info and uncollected fees

```bash
cast call 0xC36442b4a4522E871399CD717aBDD847Ab11FE88 \
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
⚠ This is Ethereum mainnet — real funds will be used.

Vault              : $VAULT_ADDRESS
Token ID           : <token_id>
Token0             : <token0_address>
Token1             : <token1_address>
Uncollected fees0  : <tokensOwed0> (raw)
Uncollected fees1  : <tokensOwed1> (raw)
AMM protocol       : $AMM_PROTOCOL
```

Ask: "Proceed with claiming fees? (yes/no)"
If no, stop.

### 6. Call claimAMMFees on the vault

```bash
cast send $VAULT_ADDRESS \
  "claimAMMFees(address,bytes)" \
  "$AMM_PROTOCOL" \
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
  Etherscan        : https://etherscan.io/tx/<tx_hash>
  Token ID        : <token_id>
  Token0 received : <balance0_after - balance0_before> (raw)
  Token1 received : <balance1_after - balance1_before> (raw)
```
