#!/usr/bin/env bash
# Kagi Universal Summarizer API script
# Usage: summarize.sh <url-or-text> [engine] [summary_type]

set -euo pipefail

# --- Validation ---

if [ -z "${KAGI_API_KEY:-}" ]; then
  echo "Error: KAGI_API_KEY environment variable is not set." >&2
  echo "Get your API key from https://kagi.com/settings?p=api" >&2
  echo "Then: export KAGI_API_KEY='your-key-here'" >&2
  exit 1
fi

for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  fi
done

if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "Usage: summarize.sh <url-or-text> [engine] [summary_type]" >&2
  echo "" >&2
  echo "  url-or-text   - URL to summarize, or quoted text (required)" >&2
  echo "  engine        - cecil (default), agnes, muriel (default: cecil)" >&2
  echo "  summary_type  - summary (default) or takeaway" >&2
  echo "" >&2
  echo "Engines:" >&2
  echo "  cecil   - Friendly, descriptive, fast (\$0.03/1k tokens)" >&2
  echo "  agnes   - Formal, technical, analytical (\$0.03/1k tokens)" >&2
  echo "  muriel  - Best quality, enterprise-grade (\$1 flat per summary)" >&2
  echo "" >&2
  echo "Summary types:" >&2
  echo "  summary   - Paragraph(s) of prose (default)" >&2
  echo "  takeaway  - Bulleted list of key points" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  summarize.sh \"https://example.com/long-article\"" >&2
  echo "  summarize.sh \"https://youtube.com/watch?v=abc\" muriel" >&2
  echo "  summarize.sh \"https://example.com/paper.pdf\" agnes takeaway" >&2
  echo "  summarize.sh \"Long text to summarize...\" cecil summary" >&2
  exit 1
fi

INPUT="$1"
ENGINE="${2:-cecil}"
SUMMARY_TYPE="${3:-summary}"

# Validate engine
case "$ENGINE" in
  cecil|agnes|muriel) ;;
  *)
    echo "Error: Invalid engine '$ENGINE'. Use: cecil, agnes, or muriel" >&2
    exit 1
    ;;
esac

# Validate summary type
case "$SUMMARY_TYPE" in
  summary|takeaway) ;;
  *)
    echo "Error: Invalid summary_type '$SUMMARY_TYPE'. Use: summary or takeaway" >&2
    exit 1
    ;;
esac

# --- API Call ---

# Detect if input is a URL or text
if [[ "$INPUT" =~ ^https?:// ]]; then
  # URL input — use GET with URL parameters
  ENCODED_URL=$(jq -rn --arg u "$INPUT" '$u | @uri')
  API_URL="https://kagi.com/api/v0/summarize?url=${ENCODED_URL}&engine=${ENGINE}&summary_type=${SUMMARY_TYPE}"

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    "$API_URL" \
    -H "Authorization: Bot ${KAGI_API_KEY}" \
    2>&1) || {
    echo "Error: Failed to connect to Kagi API." >&2
    exit 1
  }
else
  # Text input — use POST with JSON body
  JSON_BODY=$(jq -n \
    --arg text "$INPUT" \
    --arg engine "$ENGINE" \
    --arg summary_type "$SUMMARY_TYPE" \
    '{text: $text, engine: $engine, summary_type: $summary_type}')

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "https://kagi.com/api/v0/summarize" \
    -H "Authorization: Bot ${KAGI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$JSON_BODY" \
    2>&1) || {
    echo "Error: Failed to connect to Kagi API." >&2
    exit 1
  }
fi

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

# --- Error Handling ---

if [ "$HTTP_CODE" -ne 200 ]; then
  ERROR_MSG=$(echo "$BODY" | jq -r '.error // .message // "Unknown error"' 2>/dev/null || echo "HTTP $HTTP_CODE")
  echo "Error: Kagi API returned HTTP $HTTP_CODE" >&2
  echo "  $ERROR_MSG" >&2
  exit 1
fi

API_ERROR=$(echo "$BODY" | jq -r '.error // empty' 2>/dev/null)
if [ -n "$API_ERROR" ]; then
  echo "Error: $API_ERROR" >&2
  exit 1
fi

# --- Format Output ---

OUTPUT=$(echo "$BODY" | jq -r '.data.output // empty')
TOKENS=$(echo "$BODY" | jq -r '.data.tokens // empty')

if [ -z "$OUTPUT" ]; then
  echo "No summary generated." >&2
  exit 1
fi

echo "$OUTPUT"

if [ -n "$TOKENS" ]; then
  echo ""
  echo "---"
  echo "Tokens processed: $TOKENS | Engine: $ENGINE | Type: $SUMMARY_TYPE"
fi
