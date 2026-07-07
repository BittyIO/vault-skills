#!/usr/bin/env bash
# Post each CoW TWAP part to the mainnet API as its window opens.
# Idempotent: reposting the same part returns the same order UID.
#
# Usage: post-mainnet-twap.sh <twapId>
set -u

TWAP_ID="${1:?usage: post-mainnet-twap.sh <twapId>}"

cd "$(dirname "$0")/.."
set -a; . vault-skills/.env 2>/dev/null; set +a

RPC="https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}"
V=0xB6171444358F490fd64eD38d13a74F327B291632
INTENT=0xDf923AEFEe2Ac3a995C66f6998C52680154C56Ca
COW_API="https://api.cow.fi/mainnet/api/v1/orders"

CLONE=$(cast call "$V" "getClone(address)(address)" "$INTENT" --rpc-url "$RPC")
APP_DATA=$(cast call "$CLONE" "APP_DATA()(bytes32)" --rpc-url "$RPC")

# TwapParams: (sellToken, buyToken, sellAmountPerPart, buyAmountMinPerPart, startTime, partDuration, span, n)
read -r ST BT SPP BAM START PDUR SPAN N < <(
  cast call "$CLONE" \
    "twapOrders(bytes32)(address,address,uint256,uint256,uint32,uint32,uint32,uint32)" \
    "$TWAP_ID" --rpc-url "$RPC" | tr '\n' ' '
)
SPP=${SPP%% *}; BAM=${BAM%% *}
echo "[twap] clone=$CLONE start=$START part=$PDUR span=$SPAN n=$N"
echo "[twap] sell/part=$SPP buyMin/part=$BAM"

post_current() {
  local es pi ps validto body resp
  es=$([ "$SPAN" -gt 0 ] && echo "$SPAN" || echo "$PDUR")
  local now; now=$(date -u +%s)
  pi=$(( (now - START) / PDUR ))
  ps=$(( START + pi * PDUR ))
  validto=$(( ps + es ))
  body=$(python3 -c "
import json
print(json.dumps({'sellToken':'$ST','buyToken':'$BT','receiver':'$V','sellAmount':'$SPP','buyAmount':'$BAM','validTo':$validto,'appData':'$APP_DATA','feeAmount':'0','kind':'sell','partiallyFillable':False,'signingScheme':'eip1271','signature':'0x','from':'$V','sellTokenBalance':'erc20','buyTokenBalance':'erc20'}))")
  resp=$(curl -s -X POST "$COW_API" -H "Content-Type: application/json" -d "$body")
  echo "[twap] part=$pi validTo=$validto -> $resp"
}

# Post every part window from now until the TWAP ends.
for (( i=0; i<N; i++ )); do
  window_start=$(( START + i * PDUR ))
  now=$(date -u +%s)
  # Skip windows already elapsed.
  if (( now >= window_start + PDUR )); then continue; fi
  # Wait until this window opens.
  if (( now < window_start )); then sleep $(( window_start - now )); fi
  active=$(cast call "$CLONE" "isTwapActive(bytes32)(bool)" "$TWAP_ID" --rpc-url "$RPC")
  if [ "$active" != "true" ]; then echo "[twap] inactive at part $i, stopping"; break; fi
  post_current
done
echo "[twap] done"
