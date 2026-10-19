#!/usr/bin/env bash
# Gasless CoW Swap orders for a BittyVault: sign off-chain with the asset manager key, post to the
# CoW orderbook with signingScheme=eip1271. The vault is the order owner; at settlement CoW calls the
# vault's isValidSignature, which the CoW clone answers by re-checking the order and the signer.
#
#   cow.sh limit     <vault> <sellToken> <buyToken> <sellAmount> <buyAmount> <validTo> <sell|buy>
#   cow.sh twap-new  <vault> <sellToken> <buyToken> <sellPerPart> <buyMinPerPart> <numParts> <partSeconds>
#   cow.sh twap-post <schedule_file>
#   cow.sh twap-uids <schedule_file>      # UIDs of every part not yet expired, as [0x..,0x..]
#
# Amounts are raw token units. Needs RPC_URL and PRIVATE_KEY (the asset manager) in the environment.
# Every order is checked against the vault's own CoW clone before it is posted, so a post only
# happens when settlement would accept the signature.
set -euo pipefail

: "${RPC_URL:?RPC_URL is not set}"
: "${PRIVATE_KEY:?PRIVATE_KEY is not set}"

MAGIC=0x1626ba7e
ORDER_TYPE_HASH=0xd5a25ba2e97094ad7d83dc28a6572da797d6b3e7fc6663bd93efb789fc17e489
KIND_SELL=0xf3b277728b3fee749481eb3e0b3b48980dbbab78658fc419025cb16eee346775
KIND_BUY=0x6ed88e868af0a1983e3886d5f3e95a2fafbd6c3450bc229e27342283dc429ccc
BALANCE_ERC20=0x5a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc9
ORDER_T="(address,address,address,uint256,uint256,uint32,bytes32,uint256,bytes32,bool,bytes32,bytes32)"
TWAP_T="(address,address,uint256,uint256,uint256,uint256,uint256)"
TWAP_DIR="${TWAP_DIR:-.twaps}"

c() { cast call "$@" --rpc-url "$RPC_URL"; }
die() { echo "Error: $*" >&2; exit 1; }

CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")
case "$CHAIN_ID" in
  1) COW_API=https://api.cow.fi/mainnet/api/v1; EXPLORER=https://explorer.cow.fi/orders ;;
  11155111) COW_API=https://api.cow.fi/sepolia/api/v1; EXPLORER=https://explorer.cow.fi/sepolia/orders ;;
  *) die "unsupported chain" ;;
esac

# The guard's intent protocol that this vault has a clone of. Sets PROTOCOL and CLONE.
resolve_intent() {
  local vault=$1 guard p
  guard=$(c "$vault" "guard()(address)")
  for p in $(c "$guard" "getProtocols()(address[])" | tr -d '[],'); do
    [ "$(c "$guard" "protocolCategory(address)(uint8)" "$p")" = 4 ] || continue
    CLONE=$(c "$vault" "getClone(address)(address)" "$p")
    if [ "$CLONE" != 0x0000000000000000000000000000000000000000 ]; then PROTOCOL=$p; return; fi
    die "CoW is not enabled on this vault yet. The OWNER must call updateProtocols([$p],[]) on $vault."
  done
  die "no CoW intent protocol is registered in the guard"
}

# The vault relayer pulls the sell token at settlement; approve it once per token (PERM_INTENT).
ensure_relayer() {
  local vault=$1 token=$2 amount=$3 relayer allowance
  relayer=$(c "$CLONE" "vaultRelayer()(address)")
  allowance=$(c "$token" "allowance(address,address)(uint256)" "$vault" "$relayer" | cut -d' ' -f1)
  if python3 -c "import sys; sys.exit(0 if int('$allowance') >= int('$amount') else 1)"; then return; fi
  echo "Approving CoW vault relayer for $token (one-time on-chain tx)..." >&2
  cast send "$vault" "approveIntentRelayer(address,address)" "$PROTOCOL" "$token" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" >/dev/null
}

# order_digest <sellToken> <buyToken> <receiver> <sellAmount> <buyAmount> <validTo> <appData> <kindHash>
order_digest() {
  local ds struct
  ds=$(c "$(c "$CLONE" "settlement()(address)")" "domainSeparator()(bytes32)")
  struct=$(cast keccak "$(cast abi-encode \
    "f(bytes32,address,address,address,uint256,uint256,uint32,bytes32,uint256,bytes32,bool,bytes32,bytes32)" \
    "$ORDER_TYPE_HASH" "$1" "$2" "$3" "$4" "$5" "$6" "$7" 0 "$8" false "$BALANCE_ERC20" "$BALANCE_ERC20")")
  cast keccak "$(cast concat-hex 0x1901 "$ds" "$struct")"
}

# uid <digest> <owner> <validTo>: GPv2 order UID = digest ‖ owner ‖ uint32 validTo
uid() { cast concat-hex "$1" "$2" "$(printf '0x%08x' "$3")" | tr A-F a-f; }

# preflight <validator_fn> <digest> <payload>: run the clone's own check, exactly as settlement will.
preflight() {
  local res
  res=$(c "$CLONE" "$1(bytes32,bytes)(bytes4)" "$2" "$3" 2>/dev/null || true)
  [ "$res" = "$MAGIC" ] || die "the vault would reject this order (validator returned ${res:-revert}).
  Check: signer is the owner or an unexpired asset manager with the intent permission,
  the buy token is allowed on the vault, and the vault holds the full sell amount."
}

register_app_data() {
  curl -sf -X PUT "$COW_API/app_data/$1" -H 'Content-Type: application/json' \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"fullAppData": sys.argv[1]}))' "$2")" >/dev/null \
    || die "CoW API refused the appData document $1"
}

# post <vault> <sellToken> <buyToken> <sellAmount> <buyAmount> <validTo> <appData> <sell|buy> <payload>
post() {
  local body resp
  body=$(python3 -c 'import json,sys; a=sys.argv[1:]; print(json.dumps({
    "sellToken": a[1], "buyToken": a[2], "receiver": a[0], "sellAmount": a[3], "buyAmount": a[4],
    "validTo": int(a[5]), "appData": a[6], "feeAmount": "0", "kind": a[7], "partiallyFillable": False,
    "signingScheme": "eip1271", "signature": a[8], "from": a[0],
    "sellTokenBalance": "erc20", "buyTokenBalance": "erc20"}))' "$@")
  resp=$(curl -s -X POST "$COW_API/orders" -H 'Content-Type: application/json' -d "$body")
  case "$resp" in
    \"0x*) echo "$resp" | tr -d '"' ;;
    *DuplicatedOrder*) echo "already-posted" ;;
    *) die "CoW API: $resp" ;;
  esac
}

cmd=${1:-}; shift || true
case "$cmd" in
limit)
  [ $# -eq 7 ] || die "usage: cow.sh limit <vault> <sellToken> <buyToken> <sellAmount> <buyAmount> <validTo> <sell|buy>"
  vault=$1 sell=$2 buy=$3 sellAmt=$4 buyAmt=$5 validTo=$6 kind=$7
  [ "$kind" = sell ] && kindHash=$KIND_SELL || kindHash=$KIND_BUY
  resolve_intent "$vault"
  appData=$(c "$CLONE" "APP_DATA()(bytes32)")
  full="{\"appCode\":\"BittyVault\",\"metadata\":{\"partnerFee\":{\"bps\":20,\"recipient\":\"$(c "$CLONE" "PARTNER_FEE_RECIPIENT()(address)")\"}},\"version\":\"1.3.0\"}"
  [ "$(cast keccak "$full")" = "$appData" ] || die "appData document does not match the clone's APP_DATA"
  ensure_relayer "$vault" "$sell" "$sellAmt"
  digest=$(order_digest "$sell" "$buy" "$vault" "$sellAmt" "$buyAmt" "$validTo" "$appData" "$kindHash")
  sig=$(cast wallet sign --no-hash "$digest" --private-key "$PRIVATE_KEY")
  payload=$(cast abi-encode "f($ORDER_T,bytes,uint256)" \
    "($sell,$buy,$vault,$sellAmt,$buyAmt,$validTo,$appData,0,$kindHash,false,$BALANCE_ERC20,$BALANCE_ERC20)" "$sig" 0)
  preflight validateOffchainOrder "$digest" "$payload"
  register_app_data "$appData" "$full"
  id=$(uid "$digest" "$vault" "$validTo")
  posted=$(post "$vault" "$sell" "$buy" "$sellAmt" "$buyAmt" "$validTo" "$appData" "$kind" "$payload")
  [ "$posted" = already-posted ] || [ "$posted" = "$id" ] || die "CoW returned uid $posted, expected $id"
  echo "UID=$id"
  echo "EXPLORER=$EXPLORER/$id"
  ;;

twap-new)
  [ $# -eq 7 ] || die "usage: cow.sh twap-new <vault> <sellToken> <buyToken> <sellPerPart> <buyMinPerPart> <numParts> <partSeconds>"
  vault=$1 sell=$2 buy=$3 sellPer=$4 buyPer=$5 n=$6 dur=$7
  resolve_intent "$vault"
  start=$(date +%s)
  ensure_relayer "$vault" "$sell" "$(python3 -c "print($sellPer * $n)")"
  twap="($sell,$buy,$sellPer,$buyPer,$start,$dur,$n)"
  # One signature over the whole schedule authorises every part.
  sig=$(cast wallet sign --no-hash "$(c "$CLONE" "twapDigest($TWAP_T)(bytes32)" "$twap")" --private-key "$PRIVATE_KEY")
  mkdir -p "$TWAP_DIR"
  file="$TWAP_DIR/$vault-$start.env"
  cat >"$file" <<EOF
VAULT=$vault
SELL=$sell
BUY=$buy
SELL_PER=$sellPer
BUY_PER=$buyPer
START=$start
DUR=$dur
N=$n
SIG=$sig
EOF
  echo "FILE=$file"
  exec "$0" twap-post "$file"
  ;;

twap-post | twap-uids)
  [ $# -eq 1 ] && [ -f "$1" ] || die "usage: cow.sh $cmd <schedule_file>"
  # shellcheck disable=SC1090
  source "$1"
  resolve_intent "$VAULT"
  appData=$(c "$CLONE" "twapAppData(uint256)(bytes32)" "$START")
  now=$(date +%s)
  i=$(( (now - START) / DUR ))
  if [ "$cmd" = twap-uids ]; then
    ids=()
    for ((p = i < 0 ? 0 : i; p < N; p++)); do
      validTo=$((START + (p + 1) * DUR))
      ids+=("$(uid "$(order_digest "$SELL" "$BUY" "$VAULT" "$SELL_PER" "$BUY_PER" "$validTo" "$appData" "$KIND_SELL")" "$VAULT" "$validTo")")
    done
    (IFS=,; echo "[${ids[*]}]")
    exit 0
  fi
  [ "$i" -lt "$N" ] || { echo "DONE=all $N parts have expired"; exit 0; }
  validTo=$((START + (i + 1) * DUR))
  digest=$(order_digest "$SELL" "$BUY" "$VAULT" "$SELL_PER" "$BUY_PER" "$validTo" "$appData" "$KIND_SELL")
  payload=$(cast abi-encode "f($ORDER_T,$TWAP_T,uint256,bytes)" \
    "($SELL,$BUY,$VAULT,$SELL_PER,$BUY_PER,$validTo,$appData,0,$KIND_SELL,false,$BALANCE_ERC20,$BALANCE_ERC20)" \
    "($SELL,$BUY,$SELL_PER,$BUY_PER,$START,$DUR,$N)" "$i" "$SIG")
  preflight validateOffchainTwapPart "$digest" "$payload"
  register_app_data "$appData" "$(c "$CLONE" "twapFullAppData(uint256)(string)" "$START" | python3 -c 'import json,sys; print(json.loads(sys.stdin.read()))')"
  id=$(uid "$digest" "$VAULT" "$validTo")
  post "$VAULT" "$SELL" "$BUY" "$SELL_PER" "$BUY_PER" "$validTo" "$appData" sell "$payload" >/dev/null
  echo "PART=$((i + 1))/$N"
  echo "UID=$id"
  echo "VALID_TO=$validTo"
  echo "EXPLORER=$EXPLORER/$id"
  ;;

selftest)
  # The hand-built order digest must sign identically to cast's own EIP-712 signer.
  CLONE=$(cast wallet new --json | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["address"])') # any address; only settlement() is read
  settlement=0x9008D19f58AAbD9eD0D60971565AA8510560ab41
  c() { [ "$2" = "settlement()(address)" ] && echo $settlement || cast call "$@" --rpc-url "$RPC_URL"; }
  key=0x$(openssl rand -hex 32)
  a=0x1111111111111111111111111111111111111111 b=0x2222222222222222222222222222222222222222 r=0x3333333333333333333333333333333333333333
  ad=0x$(printf 'ab%.0s' {1..32})
  mine=$(cast wallet sign --no-hash "$(order_digest $a $b $r 5 7 1900000000 $ad $KIND_BUY)" --private-key "$key")
  typed='{"types":{"EIP712Domain":[{"name":"name","type":"string"},{"name":"version","type":"string"},{"name":"chainId","type":"uint256"},{"name":"verifyingContract","type":"address"}],"Order":[{"name":"sellToken","type":"address"},{"name":"buyToken","type":"address"},{"name":"receiver","type":"address"},{"name":"sellAmount","type":"uint256"},{"name":"buyAmount","type":"uint256"},{"name":"validTo","type":"uint32"},{"name":"appData","type":"bytes32"},{"name":"feeAmount","type":"uint256"},{"name":"kind","type":"string"},{"name":"partiallyFillable","type":"bool"},{"name":"sellTokenBalance","type":"string"},{"name":"buyTokenBalance","type":"string"}]},"primaryType":"Order","domain":{"name":"Gnosis Protocol","version":"v2","chainId":'$CHAIN_ID',"verifyingContract":"'$settlement'"},"message":{"sellToken":"'$a'","buyToken":"'$b'","receiver":"'$r'","sellAmount":"5","buyAmount":"7","validTo":1900000000,"appData":"'$ad'","feeAmount":"0","kind":"buy","partiallyFillable":false,"sellTokenBalance":"erc20","buyTokenBalance":"erc20"}}'
  theirs=$(cast wallet sign --data "$typed" --private-key "$key")
  [ "$mine" = "$theirs" ] || die "order digest mismatch"
  [ "$(uid 0x$(printf '00%.0s' {1..32}) $r 1)" = "0x$(printf '00%.0s' {1..32})${r#0x}00000001" ] || die "uid layout mismatch"
  echo "selftest ok"
  ;;

*) sed -n '2,13p' "$0"; exit 1 ;;
esac
