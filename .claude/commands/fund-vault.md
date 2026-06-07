Fund a BittyVault with WETH, WETH_UNI, and WETH_AAVE by wrapping ETH held by the asset manager.

The asset manager wraps ETH into each of the three WETH variants via `deposit()`, then transfers them to the vault.

**Usage:** `/fund-vault [amount_each]`

- `[amount_each]` — ETH amount to wrap and send per token (default: `0.01`)

Arguments: $ARGUMENTS

Parse first token as optional `<amount_each>` (default `0.01`).

---

## Hardcoded Sepolia configuration

| Symbol | Address |
|--------|---------|
| WETH | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` |
| WETH_UNI | `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14` |
| WETH_AAVE | `0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c` |

---

## Steps

### 1. Check environment variables

```bash
echo "ALCHEMY_KEY=${ALCHEMY_KEY:?ALCHEMY_KEY is not set}" && \
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
```

### 2. Derive asset manager address and check ETH balance

```bash
ASSET_MANAGER=$(cast wallet address --private-key "$PRIVATE_KEY")
cast balance "$ASSET_MANAGER" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Convert `<amount_each>` to wei:
```bash
AMOUNT_RAW=$(cast to-unit <amount_each>ether wei)
```

Total ETH needed = `<amount_each> * 3` (plus gas). If balance is insufficient, stop and print:
```
Error: Asset manager ETH balance too low.
  Balance  : <balance> wei
  Required : <amount_each * 3> ETH + gas
Send more ETH to <asset_manager_address> and try again.
```

### 3. Show preview and ask for confirmation

Print:
```
Asset manager : <asset_manager_address>
Vault         : $VAULT_ADDRESS
Wrapping and sending:
  <amount_each> ETH → WETH     (0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
  <amount_each> ETH → WETH_UNI (0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14)
  <amount_each> ETH → WETH_AAVE(0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c)
```

Ask: "Proceed? (yes/no)"
If no, stop.

### 4. Wrap ETH → WETH and transfer to vault

```bash
cast send 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 \
  "deposit()" --value "$AMOUNT_RAW" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"

cast send 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 \
  "transfer(address,uint256)" "$VAULT_ADDRESS" "$AMOUNT_RAW" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

### 5. Wrap ETH → WETH_UNI and transfer to vault

```bash
cast send 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14 \
  "deposit()" --value "$AMOUNT_RAW" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"

cast send 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14 \
  "transfer(address,uint256)" "$VAULT_ADDRESS" "$AMOUNT_RAW" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

### 6. Wrap ETH → WETH_AAVE and transfer to vault

```bash
cast send 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c \
  "deposit()" --value "$AMOUNT_RAW" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"

cast send 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c \
  "transfer(address,uint256)" "$VAULT_ADDRESS" "$AMOUNT_RAW" \
  --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

### 7. Verify vault balances

```bash
cast call 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 "balanceOf(address)(uint256)" "$VAULT_ADDRESS" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
cast call 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14 "balanceOf(address)(uint256)" "$VAULT_ADDRESS" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
cast call 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c "balanceOf(address)(uint256)" "$VAULT_ADDRESS" --rpc-url "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
✓ Vault funded!
  WETH      : <weth_balance> (raw)
  WETH_UNI  : <weth_uni_balance> (raw)
  WETH_AAVE : <weth_aave_balance> (raw)
```
