Propose a one-off send from a BittyVault on Ethereum mainnet, as a **payout operator**. The batch is validated against the operator's rolling quota immediately, then queued until the vault owner approves it (in the Bitty web app); nothing moves before approval.

**Usage:** `/propose-send <recipient> <asset> <amount>`

- `<recipient>` — address to pay
- `<asset>` — asset symbol (e.g. USDC) or address; with a non-zero send cap or an operator quota, stablecoins only
- `<amount>` — amount to send (human-readable)

Arguments: $ARGUMENTS

If any token is missing, stop and print: "Usage: /propose-send <recipient> <asset> <amount>"

---

## Steps

### 1. Check environment variables

```bash
echo "PRIVATE_KEY=${PRIVATE_KEY:?PRIVATE_KEY is not set — the payout operator's key}" && \
echo "VAULT_ADDRESS=${VAULT_ADDRESS:?VAULT_ADDRESS is not set}"
```

### 2. Verify the caller is a payout operator

```bash
cast call $VAULT_ADDRESS "isPayoutOperator(address)(bool)" "<caller_address>" --rpc-url "<rpc_url>"
```

If `false`, stop and print: "This key is not a payout operator of the vault. The owner grants operator seats in the Bitty web app."

### 3. Resolve the asset

If `<asset>` is a symbol, resolve it against `getAssets()(address[])` / `getStableCoins()(address[])` and each token's `symbol()(string)`. Read `decimals()(uint8)` and convert `<amount>` to raw units.

### 4. Show preview and ask for confirmation

Print:
```
Vault     : $VAULT_ADDRESS
Recipient : <recipient>
Asset     : <symbol> (<asset_address>)
Amount    : <amount>
Status    : will await OWNER APPROVAL before anything is sent
```

This is Ethereum mainnet — real funds are at stake once approved.

Ask: "Propose this send? (yes/no)"
If no, stop.

### 5. Send the proposal

An operator calling `send` queues a proposal (only the owner's own `send` executes immediately):

```bash
cast send $VAULT_ADDRESS \
  "send(address[],address[],uint256[])" \
  "[<recipient>]" \
  "[<asset_address>]" \
  "[<amount_raw>]" \
  --rpc-url "<rpc_url>" \
  --private-key "$PRIVATE_KEY"
```

If the transaction reverts, print the revert reason and stop. Common reasons:
- `NotPayoutOperator()` — the key holds no operator seat on this vault
- `PaymentNotStableCoin()` — a send cap or operator quota is active and the asset isn't a registered stablecoin
- `PaymentExceedsRiskCap()` — batch total exceeds the vault's maxSendValue cap
- `PaymentExceedsPeriodLimit()` — batch would exceed the operator's rolling per-period quota

### 6. Show result

Decode the `SendProposed(uint256 indexed id, ...)` event from the receipt for the proposal id, then print:
```
Send proposed!
  Tx hash     : <tx_hash>
  Etherscan   : https://etherscan.io/tx/<tx_hash>
  Proposal id : <id>
  Next step   : the vault owner must approve it in the Bitty web app before funds move.
```
