#!/usr/bin/env bash
# jina-read.sh — full page text through Jina Reader (r.jina.ai), step 3 of the page-text ladder:
# the fallback when firecrawl-read.sh fails (no key, 403, body rejected by the gate).
# Usage: jina-read.sh <url> [--timeout SEC]      → page text (markdown) on stdout
#
# Key: JINA_API_KEY via scripts/secret.sh (env → macOS Keychain). With the key the limit is 500 req/min
# (checked 04.11.2026, header x-ratelimit-limit); without it ~20 req/min per IP, so parallel agents get 429.
# The free key is non-commercial (Jina terms); a page costs ~5–10k tokens (x-usage-tokens: 9 385 on a
# docs page), so the free 10 M tokens ≈ 1 000 pages.
# Behaviour: 429 → wait (Retry-After ≤ 10 s, else 4 s) and retry once; 402/401 with a key (tokens spent
# or key revoked) → one keyless try and a hint on stderr. Bench 2026-11-09 (20 real pages): Jina 18/20,
# Firecrawl 20/20 — so Firecrawl goes first and Jina catches what it fails on.
# Exit: 0 ok · 1 usage · 3 HTTP error / empty body (caller moves to the next ladder step).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
url="${1:-}"; shift || true
TIMEOUT=60
while [ $# -gt 0 ]; do case "$1" in --timeout) TIMEOUT="${2:?}"; shift 2;; *) echo "unknown option: $1" >&2; exit 1;; esac; done
[ -n "$url" ] || { sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }

KEY="${JINA_API_KEY:-}"
[ -n "$KEY" ] || KEY="$(bash "$HERE/secret.sh" JINA_API_KEY 2>/dev/null || true)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/jina.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT

fetch() {  # fetch <use-key 0|1> → sets CODE, body in $TMP/body, headers in $TMP/h
  local auth=()
  [ "$1" = 1 ] && [ -n "$KEY" ] && auth=(-H "Authorization: Bearer $KEY")
  CODE=$(curl -sS -L --max-time "$TIMEOUT" ${auth[@]+"${auth[@]}"} -D "$TMP/h" -o "$TMP/body" -w '%{http_code}' \
         "https://r.jina.ai/$url" 2>"$TMP/err") || CODE=000
}

fetch 1
if [ "$CODE" = 429 ]; then
  ra=$(awk 'tolower($1)=="retry-after:"{print $2+0}' "$TMP/h" | tail -1)
  wait=4; [ -n "$ra" ] && [ "$ra" -gt 0 ] 2>/dev/null && [ "$ra" -le 10 ] && wait=$ra
  echo "[warn] jina 429 — retry in ${wait}s$([ -z "$KEY" ] && echo ' (no JINA_API_KEY: keyless limit ~20/min)')" >&2
  sleep "$wait"; fetch 1
fi
if [ -n "$KEY" ] && { [ "$CODE" = 402 ] || [ "$CODE" = 401 ]; }; then
  echo "[warn] jina HTTP $CODE with the key (tokens spent or key revoked) — one keyless try; top up or replace JINA_API_KEY" >&2
  fetch 0
fi
if [ "${CODE:0:1}" != 2 ] || [ ! -s "$TMP/body" ]; then
  echo "[error] jina HTTP $CODE for $url — ladder exhausted for this URL (behind login → /browser)" >&2
  head -c 300 "$TMP/body" >&2 2>/dev/null; echo >&2
  exit 3
fi
if grep -q -m1 -E '^Warning: Target URL returned error [45][0-9][0-9]' "$TMP/body"; then
  # Jina answers 200 but the target refused (404, 403 anti-bot, Reddit block) — not page text
  echo "[error] jina: $(grep -m1 -E '^Warning: Target URL returned error' "$TMP/body") — next ladder step" >&2
  exit 3
fi
tok=$(awk 'tolower($1)=="x-usage-tokens:"{print $2+0}' "$TMP/h" | tail -1)
echo "[jina] $([ -n "$KEY" ] && echo key || echo keyless) http=$CODE tokens=${tok:-?} | $url" >&2
cat "$TMP/body"
