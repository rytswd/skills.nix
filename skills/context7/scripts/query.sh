#!/usr/bin/env bash
# Context7 library documentation query script
# Usage:
#   query.sh resolve <library-name>
#   query.sh docs <library-id> <query>

set -euo pipefail

BASE_URL="https://mcp.context7.com"

# --- Validation ---

for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  fi
done

usage() {
  echo "Usage:" >&2
  echo "  query.sh resolve <library-name>    Find the Context7 ID for a library" >&2
  echo "  query.sh docs <library-id> <query> Query documentation for a library" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  query.sh resolve \"nextjs\"" >&2
  echo "  query.sh docs \"/vercel/next.js\" \"app router middleware\"" >&2
  exit 1
}

if [ $# -lt 2 ]; then
  usage
fi

COMMAND="$1"

# --- Resolve Library ID ---

if [ "$COMMAND" = "resolve" ]; then
  LIBRARY_NAME="$2"
  ENCODED_NAME=$(jq -rn --arg q "$LIBRARY_NAME" '$q | @uri')

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    "${BASE_URL}/resolve?query=${ENCODED_NAME}&libraryName=${ENCODED_NAME}" \
    2>&1) || {
    echo "Error: Failed to connect to Context7 API." >&2
    exit 1
  }

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" -ne 200 ]; then
    echo "Error: Context7 API returned HTTP $HTTP_CODE" >&2
    echo "$BODY" >&2
    exit 1
  fi

  # Try to extract library ID from response
  # Response format may vary; attempt common patterns
  LIBRARY_ID=$(echo "$BODY" | jq -r '.libraryId // .id // .result // empty' 2>/dev/null)

  if [ -n "$LIBRARY_ID" ]; then
    echo "Library ID: $LIBRARY_ID"
  else
    # If structured extraction fails, show the full response
    echo "Resolve results for '$LIBRARY_NAME':"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
  fi

# --- Query Documentation ---

elif [ "$COMMAND" = "docs" ]; then
  if [ $# -lt 3 ]; then
    echo "Error: 'docs' command requires both <library-id> and <query>" >&2
    echo "  query.sh docs \"/vercel/next.js\" \"app router\"" >&2
    exit 1
  fi

  LIBRARY_ID="$2"
  QUERY="$3"
  ENCODED_ID=$(jq -rn --arg q "$LIBRARY_ID" '$q | @uri')
  ENCODED_QUERY=$(jq -rn --arg q "$QUERY" '$q | @uri')

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    "${BASE_URL}/query?libraryId=${ENCODED_ID}&query=${ENCODED_QUERY}" \
    2>&1) || {
    echo "Error: Failed to connect to Context7 API." >&2
    exit 1
  }

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" -ne 200 ]; then
    echo "Error: Context7 API returned HTTP $HTTP_CODE" >&2
    echo "$BODY" >&2
    exit 1
  fi

  # Try to extract documentation content
  CONTENT=$(echo "$BODY" | jq -r '.content // .result // .documentation // empty' 2>/dev/null)

  if [ -n "$CONTENT" ]; then
    echo "$CONTENT"
  else
    # Show full response if structured extraction fails
    echo "Documentation for $LIBRARY_ID (query: $QUERY):"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
  fi

else
  echo "Error: Unknown command '$COMMAND'" >&2
  usage
fi
