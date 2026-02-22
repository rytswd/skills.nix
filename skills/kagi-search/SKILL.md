---
name: kagi-search
description: Web search and content summarization via Kagi APIs. Use for searching the web, finding documentation, verifying facts, summarizing articles/videos/PDFs, or extracting key points from URLs.
compatibility: Requires KAGI_API_KEY environment variable, curl, and jq.
metadata:
  version: "0.2"
  author: skills-nix
---

# Kagi Search & Summarizer

Search the web and summarize content using Kagi's APIs. Kagi provides high-quality, ad-free search results and a Universal Summarizer that handles articles, PDFs, videos, and more.

## Prerequisites

1. **Kagi API key** — Set as `KAGI_API_KEY` environment variable
2. **curl** and **jq** — For making API calls and parsing results
3. **API credits** — Pre-paid at https://kagi.com/settings?p=billing_api

## Search

Search the web using Kagi's search API.

```bash
# Basic search (default 5 results)
scripts/search.sh "rust async tutorial"

# More results
scripts/search.sh "nextjs app router migration" 10
```

### Output Format

```
[1] Understanding Async in Rust
    https://example.com/rust-async-guide
    A comprehensive guide to async/await in Rust...

[2] Rust Async Book
    https://rust-lang.github.io/async-book/
    The official Rust async programming book...
```

### When to Search

- **Documentation** — Library docs, API references, tutorials
- **Current information** — Recent releases, changelogs, announcements
- **Fact verification** — Check claims, find authoritative sources
- **Troubleshooting** — Error messages, known issues, solutions
- **Discovery** — Find libraries, tools, or approaches

## Summarize

Summarize any URL or text using Kagi's Universal Summarizer.

```bash
# Summarize a web article
scripts/summarize.sh "https://example.com/long-article"

# Summarize a YouTube video
scripts/summarize.sh "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

# Summarize a PDF
scripts/summarize.sh "https://example.com/paper.pdf"

# Get key takeaways instead of prose
scripts/summarize.sh "https://example.com/article" cecil takeaway

# Use the best engine for important content
scripts/summarize.sh "https://example.com/report" muriel

# Summarize raw text
scripts/summarize.sh "Long text content to summarize..."
```

### Engines

| Engine | Style | Cost |
|--------|-------|------|
| `cecil` (default) | Friendly, descriptive, fast | $0.03 / 1k tokens |
| `agnes` | Formal, technical, analytical | $0.03 / 1k tokens |
| `muriel` | Best quality, enterprise-grade | $1 flat per summary |

### Summary Types

| Type | Output |
|------|--------|
| `summary` (default) | Paragraph(s) of prose |
| `takeaway` | Bulleted list of key points |

### Supported Content

- Web pages and articles
- PDF documents
- YouTube videos
- PowerPoint and Word documents
- Audio files (mp3/wav)
- Scanned PDFs and images (OCR)

### When to Summarize

- **Long articles** — Get the gist before reading in full
- **Video content** — Extract key points from YouTube videos
- **Research papers** — Quick summary of PDF papers
- **Documentation** — Condense long docs into key takeaways
- **Meeting notes** — Summarize audio recordings

## Direct API Usage

### Search API

```bash
curl -s "https://kagi.com/api/v0/search?q=rust+async&limit=5" \
  -H "Authorization: Bot $KAGI_API_KEY"
```

Response: `data[]` array with `t: 0` (web results) and `t: 1` (related searches).

### Summarizer API

```bash
# Summarize URL
curl -s "https://kagi.com/api/v0/summarize?url=https://example.com&engine=cecil" \
  -H "Authorization: Bot $KAGI_API_KEY"

# Summarize text (POST)
curl -s -X POST "https://kagi.com/api/v0/summarize" \
  -H "Authorization: Bot $KAGI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"text": "Content to summarize...", "engine": "cecil", "summary_type": "takeaway"}'
```

Response: `data.output` (summary text), `data.tokens` (tokens processed).

## Pricing

- **Search**: ~$2.50 per 1,000 queries
- **Summarizer** (cecil/agnes): $0.03 per 1,000 tokens (capped at 10k tokens per request)
- **Summarizer** (muriel): $1 flat per summary
- Cached summarizer responses are free

## Error Handling

Both scripts handle:
- **Missing API key** — Clear message to set `KAGI_API_KEY`
- **Missing dependencies** — Checks for curl and jq
- **API errors** — Displays error message from Kagi
- **No results / no summary** — Reports clearly
- **Empty input** — Shows usage instructions
