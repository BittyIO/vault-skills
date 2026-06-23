Set up the AI asset manager by generating a new Ethereum keypair or importing an existing private key.

---

## Steps

### 1. Ask the user how they want to set up the asset manager

Ask the user:
```
How would you like to set up the asset manager?
  [1] Generate a new keypair
  [2] Enter an existing private key
```

### 2a. If the user chose "Generate" (option 1)

```bash
cast wallet new
```

Parse the output and extract:
- `<address>` — the `Address:` line
- `<private_key>` — the `Private key:` line

### 2b. If the user chose "Enter existing" (option 2)

Ask the user to paste their private key. Accept it as `<private_key>`.

Derive the address from the provided key:
```bash
cast wallet address --private-key "<private_key>"
```

Save the output as `<address>`.

### 3. Save the private key to `.env`

Check if a `.env` file exists in the current directory.

- If `PRIVATE_KEY` is already set in `.env`, **replace** that line.
- Otherwise **append** `PRIVATE_KEY=<private_key>` to the file (create it if it doesn't exist).

### 4. Display the result

Print clearly:

```
Asset Manager Address : <address>
Private key saved to  : .env (PRIVATE_KEY)

Use this address as the asset manager when running:
  /deploy-vault <owner_address> <vault_name>
```

Do NOT print the private key in full — show only the first 6 and last 4 characters (e.g. `0x1234...abcd`) so the user can verify it was saved without exposing it in the conversation history.
