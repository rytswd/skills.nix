---
name: context7
description: Look up current, version-specific library documentation using Context7. Use when you need accurate API docs for a library, when the user says "use context7", when you suspect your training data may be outdated for a library, or when you encounter unfamiliar APIs that might be new.
compatibility: Requires curl and jq for direct API usage. For MCP setup, requires npx (Node.js) or network access to mcp.context7.com.
metadata:
  version: "0.1"
  author: skills-nix
---

# Context7: Current Library Documentation

Context7 provides **up-to-date, version-specific documentation** for libraries and frameworks. It solves the problem of LLMs relying on outdated training data, which leads to hallucinated APIs and wrong usage patterns.

## When to Use

- **Unfamiliar library APIs** — When you're not sure about correct function signatures or parameters
- **Recently updated libraries** — When using new versions that may differ from training data
- **Preventing hallucination** — When accuracy of API usage is critical
- **Version-specific docs** — When the user is on a specific version and needs matching docs

## Quick Usage (Script)

```bash
# Step 1: Find the library ID
scripts/query.sh resolve "nextjs"

# Step 2: Query documentation
scripts/query.sh docs "/vercel/next.js" "app router middleware"
```

## MCP Setup (Recommended)

If your agent supports MCP (Model Context Protocol), configure Context7 as an MCP server for seamless integration.

### Remote MCP Server

No installation needed — connect to the hosted server:

**Pi** — Add to settings:
```json
{
  "mcpServers": {
    "context7": {
      "url": "https://mcp.context7.com/mcp"
    }
  }
}
```

**Claude Code** — Add to `.claude/settings.json` or `~/.claude/settings.json`:
```json
{
  "mcpServers": {
    "context7": {
      "url": "https://mcp.context7.com/mcp"
    }
  }
}
```

**Gemini CLI** — Add to settings or extension config:
```json
{
  "mcpServers": {
    "context7": {
      "url": "https://mcp.context7.com/mcp"
    }
  }
}
```

### Local MCP Server

Run the MCP server locally (useful for custom API keys or offline caching):

```bash
npx -y @upstash/context7-mcp --api-key YOUR_API_KEY
```

Configure your agent to use it as a stdio MCP server:
```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
  }
}
```

### MCP Tools

Once configured, two tools become available:

| Tool | Purpose | Parameters |
|------|---------|------------|
| `resolve-library-id` | Find the Context7 ID for a library | `query` (required), `libraryName` (required) |
| `query-docs` | Get documentation for a library | `libraryId` (required), `query` (required) |

**Library IDs** use a slash format: `/mongodb/docs`, `/vercel/next.js`, `/supabase/supabase`

## Direct API Usage (Without MCP)

For agents without MCP support, use the query script or call the API directly.

### Using the Query Script

```bash
# Resolve a library name to its Context7 ID
scripts/query.sh resolve "react"
# Output: /facebook/react

# Query docs for a specific topic
scripts/query.sh docs "/facebook/react" "useEffect cleanup"
# Output: Relevant documentation about useEffect cleanup patterns

# One-step: resolve and query in sequence
scripts/query.sh resolve "supabase"
scripts/query.sh docs "/supabase/supabase" "realtime subscriptions"
```

### Manual curl Usage

**Step 1: Resolve library ID**
```bash
curl -s "https://mcp.context7.com/resolve?query=nextjs&libraryName=nextjs" | jq
```

**Step 2: Query documentation**
```bash
curl -s "https://mcp.context7.com/query?libraryId=/vercel/next.js&query=app+router" | jq
```

## Common Libraries

Here are some frequently used library IDs for reference:

| Library | Context7 ID |
|---------|-------------|
| Next.js | `/vercel/next.js` |
| React | `/facebook/react` |
| Supabase | `/supabase/supabase` |
| MongoDB | `/mongodb/docs` |
| Tailwind CSS | `/tailwindlabs/tailwindcss` |

**Note:** Always use `resolve` first to confirm the exact ID — these are examples that may change.

## Tips

1. **Be specific in queries** — "useEffect cleanup function" gets better results than "hooks"
2. **Resolve before querying** — Always confirm the library ID first
3. **Use for verification** — When you write code using a library API, verify with Context7 if unsure
4. **MCP is preferred** — If your agent supports MCP, use it instead of the script for smoother integration
5. **Works with any library** — Not limited to the examples above; Context7 indexes thousands of libraries
