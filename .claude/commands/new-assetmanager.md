Generate a new Ethereum keypair for the AI asset manager, save the private key, and display the address.

---

## Steps

### 1. Generate a new keypair

```bash
cast wallet new
```

Parse the output and extract:
- `<address>` — the `Address:` line
- `<private_key>` — the `Private key:` line

### 2. Save the private key to `.env`

Check if a `.env` file exists in the current directory.

- If `PRIVATE_KEY` is already set in `.env`, **replace** that line.
- Otherwise **append** `PRIVATE_KEY=<private_key>` to the file (create it if it doesn't exist).

### 3. Display the result

Print clearly:

```
Asset Manager Address : <address>
Private key saved to  : .env (PRIVATE_KEY)

Use this address as the asset manager when running:
  /deploy-vault <owner_address> <vault_name>
```

Do NOT print the private key in full — show only the first 6 and last 4 characters (e.g. `0x1234...abcd`) so the user can verify it was saved without exposing it in the conversation history.
