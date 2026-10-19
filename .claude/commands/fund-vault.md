Fund a BittyVault with WETH by sending ETH from the asset manager wallet on Sepolia.

**Usage:** `/fund-vault [eth_amount]`

- `[eth_amount]` — ETH to send (default: `0.01`)

Arguments: $ARGUMENTS

---

The vault's `receive()` wraps incoming ETH into its WETH (`0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9`)
on arrival, so a plain ETH transfer is all funding takes. If the owner has set an auto-yield route for
WETH, the vault also tries to deposit it there in the same transaction.

Any other token is funded with an ordinary ERC-20 `transfer` to the vault address.

---

## Steps

### 1. Check environment variables

```bash
: "${PRIVATE_KEY:?PRIVATE_KEY is not set — run /new-assetmanager first}"
: "${VAULT_ADDRESS:?VAULT_ADDRESS is not set — run /deploy-vault first}"
ASSET_MANAGER=$(cast wallet address --private-key "$PRIVATE_KEY")
WETH=0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9
```

### 2. Check the asset manager's ETH balance

```bash
cast balance $ASSET_MANAGER --ether --rpc-url "<rpc_url>"
```

If it is below `<eth_amount> + 0.005` (gas headroom), stop:
```
Error: asset manager <ASSET_MANAGER> holds <balance> ETH; needs <eth_amount> plus gas.
Get Sepolia ETH from https://cloud.google.com/application/web3/faucet/ethereum/sepolia
```

### 3. Preview and confirm

```bash
WETH_BEFORE=$(cast call $WETH "balanceOf(address)(uint256)" $VAULT_ADDRESS --rpc-url "<rpc_url>")
```

Print the vault, the amount and the vault's current WETH balance. Ask: "Send <eth_amount> ETH to the vault? (yes/no)"

### 4. Send

```bash
cast send $VAULT_ADDRESS --value <eth_amount>ether \
  --rpc-url "<rpc_url>" --private-key "$PRIVATE_KEY"
```

### 5. Show result

```bash
cast call $WETH "balanceOf(address)(uint256)" $VAULT_ADDRESS --rpc-url "<rpc_url>"
```

```
Vault funded!
  Tx           : https://sepolia.etherscan.io/tx/<tx_hash>
  Sent         : <eth_amount> ETH (wrapped to WETH by the vault)
  Vault WETH   : <before> → <after> (wei)
```

If WETH did not rise by the full amount, an auto-yield route moved it — run `/vault-balances`.
