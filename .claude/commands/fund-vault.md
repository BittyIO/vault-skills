Fund a BittyVault by sending ETH from the asset manager's wallet. The vault wraps it into WETH on
arrival.

**Usage:** `/fund-vault [eth_amount]`

- `[eth_amount]` — ETH to send (default `0.01`)

Arguments: $ARGUMENTS

Run every command from the repo root.

---

Funding never deposits anywhere by itself: an auto-yield route the owner set is swept later by the
keeper, not on arrival. Any other token is funded with an ordinary ERC-20 `transfer` to the vault.

---

## Steps

### 1. Who pays

```bash
bin/bitty env                                          # NETWORK, VAULT_ADDRESS
bin/bitty me                                           # → <payer>, the asset manager's address
bin/bitty role                                         # must not be "owner"
bin/bitty token WETH                                   # → <weth> 18 WETH
```

- `VAULT_ADDRESS=<unset>` → stop: `Error: no vault yet — run /deploy-vault first.`
- `bin/bitty me` errors → stop: no key yet, run `/new-assetmanager` first.
- `role` prints `owner` → stop: the owner's key must never be used here.

No preflight: funding works before the manager's grant is in force.

### 2. Enough ETH?

```bash
bin/bitty cast balance <payer> --ether
```

Below `<eth_amount> + 0.005` (gas headroom) → stop:
```
Error: <payer> holds <balance> ETH; it needs <eth_amount> plus gas.
```
On Sepolia, add: `Get Sepolia ETH from https://cloud.google.com/application/web3/faucet/ethereum/sepolia`.
On mainnet, say this is real ETH.

### 3. Preview and confirm

```bash
bin/bitty balance <weth>                               # the vault's WETH before
```

```
Fund vault
  Vault : <vault>
  Send  : <eth_amount> ETH from <payer>, wrapped to WETH by the vault
```

Ask: `Send <eth_amount> ETH to the vault? (yes/no)`. Stop on anything but yes.

### 4. Send

```bash
bin/bitty send --value <eth_amount>ether
```

### 5. Result

```bash
bin/bitty balance <weth>
```

```
Vault funded!
  Tx         : <hash and explorer link>
  Sent       : <eth_amount> ETH (wrapped to WETH)
  Vault WETH : <before> → <after>   (bin/bitty human <raw> 18)
```
