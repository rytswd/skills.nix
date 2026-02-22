#!/usr/bin/env bash
# Kagi Search API script
# Usage: search.sh <query> [limit]

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
  echo "Usage: search.sh <query> [limit]" >&2
  echo "  query  - Search query string (required)" >&2
  echo "  limit  - Maximum number of results (default: 5)" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  search.sh \"rust async tutorial\"" >&2
  echo "  search.sh \"nextjs migration guide\" 10" >&2
  exit 1
fi

QUERY="$1"
LIMIT="${2:-5}"

# --- API Call ---

ENCODED_QUERY=$(jq -rn --arg q "$QUERY" '$q | @uri')

RESPONSE=$(curl -s -w "\n%{http_code}" \
  "https://kagi.com/api/v0/search?q=${ENCODED_QUERY}&limit=${LIMIT}" \
  -H "Authorization: Bot ${KAGI_API_KEY}" \
  2>&1) || {
  echo "Error: Failed to connect to Kagi API." >&2
  exit 1
}

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

# --- Error Handling ---

if [ "$HTTP_CODE" -ne 200 ]; then
  ERROR_MSG=$(echo "$BODY" | jq -r '.error // .message // "Unknown error"' 2>/dev/null || echo "HTTP $HTTP_CODE")
  echo "Error: Kagi API returned HTTP $HTTP_CODE" >&2
  echo "  $ERROR_MSG" >&2
  exit 1
fi

# Check for API errors in response
API_ERROR=$(echo "$BODY" | jq -r '.error // empty' 2>/dev/null)
if [ -n "$API_ERROR" ]; then
  echo "Error: $API_ERROR" >&2
  exit 1
fi

# --- Format Results ---

RESULT_COUNT=$(echo "$BODY" | jq '[.data[] | select(.t == 0)] | length')

if [ "$RESULT_COUNT" -eq 0 ]; then
  echo "No results found for: $QUERY"
  exit 0
fi

echo "$BODY" | jq -r '
  [.data[] | select(.t == 0)] | to_entries[] |
  "\n[\(.key + 1)] \(.value.title)"
  + "\n    \(.value.url)"
  + if .value.snippet then "\n    \(.value.snippet | gsub("<[^>]*>"; "") | gsub("&amp;"; "&") | gsub("&lt;"; "<") | gsub("&gt;"; ">") | gsub("&#x27;"; "'"'"'"))" else "" end
  + if .value.published then "\n    Published: \(.value.published)" else "" end
'

# Show related searches if any
RELATED=$(echo "$BODY" | jq -r '[.data[] | select(.t == 1) | .list[]?] | if length > 0 then "\nRelated searches: " + join(", ") else empty end' 2>/dev/null)
if [ -n "$RELATED" ]; then
  echo "$RELATED"
fi

# Show API balance
BALANCE=$(echo "$BODY" | jq -r '.meta.api_balance // empty' 2>/dev/null)
if [ -n "$BALANCE" ]; then
  echo ""
  echo "API balance: \$${BALANCE}"
fi
