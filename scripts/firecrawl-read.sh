#!/usr/bin/env bash
# firecrawl-read.sh — full page text through Firecrawl /v2/scrape, step 2 of the page-text ladder (HTML).
# Usage: firecrawl-read.sh <url> [--timeout SEC]      → page text (markdown) on stdout
#
# Endpoint: $FIRECRAWL_API_URL if set → the local key rotator at 127.0.0.1:8642 if it answers →
# https://api.firecrawl.dev with FIRECRAWL_API_KEY via scripts/secret.sh (env → macOS Keychain).
# No endpoint and no key → exit 3 at once (the caller marks the page unread).
# Cost: 1 credit per HTML page (proxy "auto" may retry with the stealth proxy on anti-bot pages).
# Never for PDF (billed per page — use pdf-fetch.sh) or x.com/twitter.com (30 credits, AI-processed);
# the script refuses both. Bench 2026-11-09 (20 real pages, Chrome render as ground truth): Firecrawl
# read 20/20; RU median 4 s. Last rung: on exit 3 the page is unread (main session → browser-operator).
# Behaviour: 429 → wait (the "retry after Ns" hint ≤ 15 s, else 5 s) and retry once (the rotator already
# switches keys on 429). Exit: 0 ok · 1 usage · 3 HTTP error / empty body / refused URL (page unread).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
url="${1:-}"; shift || true
TIMEOUT=60
while [ $# -gt 0 ]; do case "$1" in --timeout) TIMEOUT="${2:?}"; shift 2;; *) echo "unknown option: $1" >&2; exit 1;; esac; done
[ -n "$url" ] || { sed -n '2,3p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }

low=$(printf '%s' "$url" | tr '[:upper:]' '[:lower:]')
case "$low" in
  *.pdf|*.pdf\?*|*.pdf\#*) echo "[error] firecrawl-read: PDF — use pdf-fetch.sh" >&2; exit 3;;
  *://x.com/*|*://www.x.com/*|*://twitter.com/*|*://www.twitter.com/*|*://mobile.twitter.com/*)
    echo "[error] firecrawl-read: x.com/twitter.com cost 30 credits — next ladder step" >&2; exit 3;;
esac

BASE="${FIRECRAWL_API_URL:-}"; KEY=""
if [ -z "$BASE" ] && curl -s --max-time 1 -o /dev/null http://127.0.0.1:8642/rotator/health; then
  BASE="http://127.0.0.1:8642"          # the rotator injects its own keys
fi
if [ -z "$BASE" ]; then
  KEY="${FIRECRAWL_API_KEY:-}"
  [ -n "$KEY" ] || KEY="$(bash "$HERE/secret.sh" FIRECRAWL_API_KEY 2>/dev/null || true)"
  [ -n "$KEY" ] || { echo "[error] firecrawl-read: no FIRECRAWL_API_KEY and no rotator — page unread (a page the conclusion needs → browser-operator)" >&2; exit 3; }
  BASE="https://api.firecrawl.dev"
fi
BASE="${BASE%/}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/fcread.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
PAYLOAD=$(python3 -c 'import json,sys; print(json.dumps({"url": sys.argv[1], "formats": ["markdown"], "onlyMainContent": True, "proxy": "auto", "timeout": int(sys.argv[2]) * 1000}))' "$url" "$TIMEOUT")

fetch() {
  local auth=()
  [ -n "$KEY" ] && auth=(-H "Authorization: Bearer $KEY")
  CODE=$(curl -sS --max-time $((TIMEOUT + 30)) -X POST "$BASE/v2/scrape" ${auth[@]+"${auth[@]}"} \
         -H 'Content-Type: application/json' -d "$PAYLOAD" -o "$TMP/resp" -w '%{http_code}' 2>"$TMP/err") || CODE=000
}

fetch
if [ "$CODE" = 429 ]; then
  wait=$(python3 -c 'import re,sys; m=re.search(r"retry after (\d+)", open(sys.argv[1]).read(), re.I); n=int(m.group(1))+1 if m else 5; print(n if n<=15 else 5)' "$TMP/resp" 2>/dev/null || echo 5)
  echo "[warn] firecrawl 429 — retry in ${wait}s" >&2
  sleep "$wait"; fetch
fi

python3 - "$TMP/resp" "$CODE" "$url" <<'PY'
import json, sys
path, code, url = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    raw = open(path, errors="replace").read()
except OSError:
    raw = ""
try:
    j = json.loads(raw)
except Exception:
    j = {}
d = j.get("data") or {}
md = d.get("markdown") or ""
meta = d.get("metadata") or {}
st = meta.get("statusCode")
if not (code.startswith("2") and j.get("success") and md.strip()):
    err = j.get("error") or raw[:300] or "no response"
    sys.stderr.write(f"[error] firecrawl HTTP {code} for {url}: {str(err)[:300]} — page unread (a page the conclusion needs → browser-operator)\n")
    sys.exit(3)
if isinstance(st, int) and st >= 400:
    sys.stderr.write(f"[error] firecrawl: target returned {st} for {url} — page unread (a page the conclusion needs → browser-operator)\n")
    sys.exit(3)
sys.stderr.write(f"[firecrawl] http={code} target={st} credits={meta.get('creditsUsed', '?')} | {url}\n")
sys.stdout.write(md)
PY
