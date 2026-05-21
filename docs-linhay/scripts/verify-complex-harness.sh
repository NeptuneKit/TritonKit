#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
triton="${TRITON_BIN:-$root/.build/cli/debug/triton}"
host="${TRITON_HOST:-127.0.0.1}"
port="${TRITON_PORT:-19421}"
target="${TRITON_TARGET:-triton:local}"
text="${TRITON_COMPLEX_TEXT:-complex-script}"
out_dir="${TRITON_VERIFY_OUT_DIR:-/tmp/triton-complex-harness}"

mkdir -p "$out_dir"

if [[ ! -x "$triton" ]]; then
  echo "missing triton binary: $triton" >&2
  echo "run: swift build --package-path CLI --scratch-path .build/cli --product triton" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "missing jq" >&2
  exit 1
fi

ax_json="$out_dir/ax.json"
gestures="$out_dir/gestures.ndjson"
input_jsonl="$out_dir/input.jsonl"
screenshot="$out_dir/screenshot.png"
archive="$out_dir/archive.triton"

"$triton" ax --host "$host" --port "$port" --target "$target" --json --output "$ax_json"

oid_for() {
  local identifier="$1"
  jq -er --arg identifier "$identifier" '
    [.. | objects | select(.identifier? == $identifier) | (.viewOID // .targetOID)] | first
  ' "$ax_json"
}

frame_expr_for() {
  local identifier="$1"
  local expr="$2"
  jq -er --arg identifier "$identifier" "$expr" "$ax_json"
}

required_identifiers=(
  ComplexHarnessStatus
  ComplexHarnessSummary
  ComplexHarnessMode
  ComplexHarnessSlider
  ComplexHarnessStepper
  ComplexHarnessSwitch
  ComplexHarnessTextField
  ComplexHarnessTextView
  ComplexHarnessCarousel
  ComplexHarnessPrimary
  ComplexHarnessSecondary
)

for identifier in "${required_identifiers[@]}"; do
  oid_for "$identifier" >/dev/null
done

mode_oid="$(oid_for ComplexHarnessMode)"
slider_oid="$(oid_for ComplexHarnessSlider)"
stepper_oid="$(oid_for ComplexHarnessStepper)"
switch_oid="$(oid_for ComplexHarnessSwitch)"
field_oid="$(oid_for ComplexHarnessTextField)"

carousel_start_x="$(frame_expr_for ComplexHarnessCarousel '[.. | objects | select(.identifier? == $identifier) | (.frame.x + .frame.width - 12)] | first')"
carousel_end_x="$(frame_expr_for ComplexHarnessCarousel '[.. | objects | select(.identifier? == $identifier) | (.frame.x + 20)] | first')"
carousel_y="$(frame_expr_for ComplexHarnessCarousel '[.. | objects | select(.identifier? == $identifier) | (.frame.y + (.frame.height / 2))] | first')"

jq -cn --argjson oid "$mode_oid" '{type:"tap",targetOID:$oid}' > "$gestures"
jq -cn --argjson oid "$slider_oid" '{type:"tap",targetOID:$oid}' >> "$gestures"
jq -cn --argjson oid "$stepper_oid" '{type:"tap",targetOID:$oid}' >> "$gestures"
jq -cn --argjson oid "$switch_oid" '{type:"tap",targetOID:$oid}' >> "$gestures"
jq -cn --argjson oid "$field_oid" '{type:"tap",targetOID:$oid}' >> "$gestures"
jq -cn --arg text "$text" '{type:"type",text:$text}' >> "$gestures"
jq -cn \
  --argjson startX "$carousel_start_x" \
  --argjson startY "$carousel_y" \
  --argjson endX "$carousel_end_x" \
  --argjson endY "$carousel_y" \
  '{type:"swipe",startX:$startX,startY:$startY,endX:$endX,endY:$endY}' >> "$gestures"

"$triton" input --host "$host" --port "$port" --target "$target" --json --summary --strict < "$gestures" > "$input_jsonl"

jq -s -e 'last | .ok == true and .actionCount == 7 and .failedCount == 0' "$input_jsonl" >/dev/null

"$triton" ax --host "$host" --port "$port" --target "$target" --json --output "$out_dir/ax-after.json"
jq -e --arg text "$text" '
  [.. | objects | select(.identifier? == "ComplexHarnessSummary") | .label?] |
  any(. != null and contains("mode=Edit") and contains("progress=60") and contains("count=3") and contains("switch=on") and contains("text=" + $text))
' "$out_dir/ax-after.json" >/dev/null

"$triton" screenshot --host "$host" --port "$port" --target "$target" --output "$screenshot" --json > "$out_dir/screenshot.json"
jq -e '.bytes > 0 and .width > 0 and .height > 0' "$out_dir/screenshot.json" >/dev/null

"$triton" export --host "$host" --port "$port" --target "$target" --format archive --output "$archive" >/dev/null
jq -e '
  .schemaVersion == 1 and
  (.screenshot.dataBase64 | length > 0) and
  ([.. | objects | select(.identifier? == "ComplexHarnessMode" and ((.viewOID // .targetOID) != null))] | length > 0)
' "$archive" >/dev/null

cat <<REPORT
complex harness verification passed
ax: $ax_json
input: $input_jsonl
screenshot: $screenshot
archive: $archive
REPORT
