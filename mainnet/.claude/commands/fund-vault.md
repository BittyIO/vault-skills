Fund a BittyVault with WETH by wrapping ETH held by the asset manager on Ethereum mainnet.

The asset manager wraps ETH into WETH via `deposit()`, then transfers it to the vault.

**Usage:** `/fund-vault [amount]`

- `[amount]` — ETH amount to wrap and send (default: `0.01`)

Arguments: $ARGUMENTS

Parse first token as optional `<amount>` (default `0.01`).

---

## Hardcoded mainnet configuration

| Symbol | Address | Decimals |
|--------|---------|----------|
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | 18 |

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
cast balance "$ASSET_MANAGER" --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Convert `<amount>` to wei:
```bash
AMOUNT_RAW=$(cast to-unit <amount>ether wei)
```

Total ETH needed = `<amount>` (plus gas). If balance is insufficient, stop and print:
```
Error: Asset manager ETH balance too low.
  Balance  : <balance> wei
  Required : <amount> ETH + gas
Send more ETH to <asset_manager_address> and try again.
```

### 3. Show preview and ask for confirmation

Print:
```
⚠ This is Ethereum mainnet — real ETH will be used.

Asset manager : <asset_manager_address>
Vault         : $VAULT_ADDRESS
Wrapping and sending:
  <amount> ETH → WETH (0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
```

Ask: "Proceed? (yes/no)"
If no, stop.

### 4. Wrap ETH → WETH and transfer to vault

```bash
cast send 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 \
  "deposit()" --value "$AMOUNT_RAW" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"

cast send 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 \
  "transfer(address,uint256)" "$VAULT_ADDRESS" "$AMOUNT_RAW" \
  --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --private-key "$PRIVATE_KEY"
```

### 5. Verify vault balance

```bash
cast call 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 "balanceOf(address)(uint256)" "$VAULT_ADDRESS" --rpc-url "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
```

Print:
```
✓ Vault funded!
  WETH : <weth_balance> (raw)
```
