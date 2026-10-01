#!/bin/bash
set -euo pipefail
set +x
umask 077

fail() { printf '%s\n' "$*" >&2; exit 1; }
CONFIG="$HOME/.config/opencode/opencode.json"
MODEL="" PROMPT="" OUTPUT="" SIZE="" IMAGE="" MASK=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            printf '%s\n' 'Usage: image-gen.sh --model <id> --prompt-file <file> --output <file.png>' \
                'Options: --size WIDTHxHEIGHT --image file.png --mask file.png --config file.json' \
                'PNG/base64 output only; one image; existing files are never replaced.'
            exit 0 ;;
        --model|--prompt-file|--output|--size|--image|--mask|--config)
            [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || fail "Missing value for $1."
            case "$1" in
                --model) MODEL="$2" ;; --prompt-file) PROMPT="$2" ;; --output) OUTPUT="$2" ;;
                --size) SIZE="$2" ;; --image) IMAGE="$2" ;; --mask) MASK="$2" ;; --config) CONFIG="$2" ;;
            esac
            shift 2 ;;
        *) fail 'Unknown option; use --help.' ;;
    esac
done
[[ -n "$MODEL" && -f "$PROMPT" && -s "$PROMPT" && "$OUTPUT" == *.png ]] || fail 'Model, non-empty prompt file, and .png output are required.'
[[ -z "$SIZE" || "$SIZE" =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]] || fail 'Size must be WIDTHxHEIGHT.'
[[ -z "$MASK" || -n "$IMAGE" ]] || fail 'A mask requires a reference image.'
[[ ! -e "$OUTPUT" && ! -L "$OUTPUT" ]] || fail 'Output already exists.'
for tool in jq curl base64 od tr; do command -v "$tool" >/dev/null || fail "Missing dependency: $tool."; done

TMP_DIR="$(mktemp -d)"
PARTIAL=""
cleanup() {
    [[ -z "$PARTIAL" ]] || rm -f -- "$PARTIAL"
    rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

BASE_URL=$(jq -er '.provider.litellm.options.baseURL
    | select(type == "string" and length > 0)
    | select(test("^https://[^/?#@\\s]+(/[^?#\\s]*)?$"))' "$CONFIG" 2>/dev/null) || fail 'Invalid configuration: HTTPS base URL required.'
jq -er '.provider.litellm.options.apiKey
    | select(type == "string" and length > 0)
    | select(test("[\\x00-\\x1f\\x7f]") | not)
    | "Authorization: Bearer " + .' "$CONFIG" > "$TMP_DIR/auth-header" 2>/dev/null || fail 'Invalid configuration: API key required.'

# Lightweight format check, not a complete PNG decoder.
png_dimensions() {
    local signature dimensions width height
    [[ -f "$1" ]] || return 1
    signature=$(od -An -tx1 -N16 -- "$1" | tr -d '[:space:]')
    [[ "$signature" == 89504e470d0a1a0a0000000d49484452 ]] || return 1
    dimensions=$(od -An -tu4 --endian=big -j16 -N8 -- "$1") || return 1
    read -r width height <<< "$dimensions"
    [[ "${width:-0}" -gt 0 && "${height:-0}" -gt 0 ]] || return 1
    printf '%sx%s\n' "$width" "$height"
}

ENDPOINT=generations
BODY=()
if [[ -n "$IMAGE" ]]; then
    REFERENCE_SIZE=$(png_dimensions "$IMAGE") || fail 'Reference must have a valid PNG header.'
    cp -- "$IMAGE" "$TMP_DIR/reference.png"
    cp -- "$PROMPT" "$TMP_DIR/prompt.txt"
    ENDPOINT=edits
    BODY=(--form-string "model=$MODEL" --form-string 'n=1' --form-string 'response_format=b64_json'
        -F "prompt=<\"$TMP_DIR/prompt.txt\"" -F "image=@\"$TMP_DIR/reference.png\";type=image/png")
    [[ -z "$SIZE" ]] || BODY+=(--form-string "size=$SIZE")
    if [[ -n "$MASK" ]]; then
        MASK_SIZE=$(png_dimensions "$MASK") || fail 'Mask must have a valid PNG header.'
        [[ "$MASK_SIZE" == "$REFERENCE_SIZE" ]] || fail 'Mask and reference dimensions must match.'
        cp -- "$MASK" "$TMP_DIR/mask.png"
        BODY+=(-F "mask=@\"$TMP_DIR/mask.png\";type=image/png")
    fi
else
    jq -n --arg model "$MODEL" --rawfile prompt "$PROMPT" --arg size "$SIZE" \
        '{model: $model, prompt: $prompt, n: 1, response_format: "b64_json"}
         + (if $size == "" then {} else {size: $size} end)' > "$TMP_DIR/request.json"
    BODY=(-H 'Content-Type: application/json' --data-binary "@$TMP_DIR/request.json")
fi
if ! curl -q --fail-with-body --silent --show-error --proto =https --proto-redir =https \
    --connect-timeout 15 --max-time 300 -X POST "${BASE_URL%/}/images/$ENDPOINT" \
    -H "@$TMP_DIR/auth-header" "${BODY[@]}" -o "$TMP_DIR/response.json" \
    -w 'HTTP %{http_code} | time: %{time_total}s\n' > "$TMP_DIR/status" 2>/dev/null; then
    cat -- "$TMP_DIR/status" >&2
    fail 'Request failed; no automatic retry. Raw server diagnostics are withheld.'
fi
read -r _ HTTP_CODE _ < "$TMP_DIR/status"
[[ "$HTTP_CODE" == 2[0-9][0-9] ]] || fail 'Request returned a non-success HTTP status.'
jq -er 'select(.error == null) | .data | select(type == "array" and length == 1)
    | .[0].b64_json | select(type == "string" and length > 0)' \
    "$TMP_DIR/response.json" > "$TMP_DIR/image.b64" 2>/dev/null || fail 'Expected one base64 image; URL-only responses are unsupported.'
base64 --decode "$TMP_DIR/image.b64" > "$TMP_DIR/image.png" 2>/dev/null || fail 'Invalid base64 image.'
DIMENSIONS=$(png_dimensions "$TMP_DIR/image.png") || fail 'Response has no valid PNG header.'
[[ -z "$SIZE" || "$SIZE" == "$DIMENSIONS" ]] || fail 'Returned dimensions differ from requested size.'
mkdir -p -- "$(dirname -- "$OUTPUT")"
set -C
if ! { PARTIAL="$OUTPUT"; cat -- "$TMP_DIR/image.png"; } > "$OUTPUT"; then
    fail 'Cannot save image; existing files are never replaced.'
fi
PARTIAL=""
cat -- "$TMP_DIR/status"
printf 'Saved %s (%s, PNG; header checked)\n' "$OUTPUT" "$DIMENSIONS"
