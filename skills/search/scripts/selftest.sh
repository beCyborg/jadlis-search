#!/usr/bin/env bash
set -uo pipefail

# selftest.sh — regression for /search websearch.py.
#
# Default: dry-run matrix — every row builds a request with --dry-run and asserts the JSON
#   with jq; plus validation guards and a report over a synthetic log. No HTTP, no key, $0.
# --live: minimal billed smoke ≈ $0.02 — exa fast, exa auto+highlights, brave web, exa contents.
#   Brave rows are skipped with [warn] while the subscription is 403 (billing), not failed.
#
# Exit: 0 all pass, 1 otherwise.

SD=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WS="${WEBSEARCH_PY:-$SD/websearch.py}"
# plugin layout: websearch.py lives in <plugin-root>/scripts/ (skills/search/scripts/ keeps a symlink in the live contour)
[[ -f "$WS" ]] || WS="$SD/../../../scripts/websearch.py"
PY=${PYTHON:-python3}

PASS=0; FAIL=0
pass() { printf 'ok   %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf 'FAIL %s%s\n' "$1" "${2:+ — $2}" >&2; FAIL=$((FAIL+1)); }

# row <name> <jq-assert> -- <args...>: run with --dry-run --no-log, assert on stdout JSON
row() {
  local name="$1" assert="$2"; shift 2
  [[ "${1:-}" == "--" ]] && shift
  local out
  if ! out=$("$PY" "$WS" "$@" --dry-run --no-log 2>/dev/null); then
    fail "$name" "dry-run exited non-zero"; return
  fi
  if ! jq -e "$assert" >/dev/null 2>&1 <<<"$out"; then
    fail "$name" "assert failed: $assert"; jq . <<<"$out" >&2; return
  fi
  pass "$name"
}

# expect_exit <name> <code> -- <args...>
expect_exit() {
  local name="$1" want="$2"; shift 2
  [[ "${1:-}" == "--" ]] && shift
  "$PY" "$WS" "$@" >/dev/null 2>&1
  local got=$?
  if [[ "$got" == "$want" ]]; then pass "$name"; else fail "$name" "exit $got, want $want"; fi
}

echo "== wave 0: python & syntax =="
if "$PY" -c 'import sys; sys.exit(0 if sys.version_info >= (3,9) else 1)'; then pass "python >= 3.9 ($($PY --version 2>&1))"; else fail "python version"; fi
if "$PY" -m py_compile "$WS" 2>/dev/null; then pass "py_compile"; else fail "py_compile"; fi

echo "== wave 1: dry-run matrix (\$0) =="
row "01 exa defaults → auto, n=10, highlights, x-api-key placeholder" \
  '.engine=="exa" and .body.type=="auto" and .body.numResults==10 and .body.contents.highlights==true
   and .headers["x-api-key"]=="${EXA_API_KEY}" and (.url|endswith("/search"))' \
  -- exa "detailed blog post about python packaging written by a practitioner" --tag research

row "02 exa keyword + RU query passes through" \
  '.body.type=="keyword" and .body.query=="пробиотики при акне клинические исследования штаммы"' \
  -- exa "пробиотики при акне клинические исследования штаммы" --tag research --type keyword

row "03 exa category publication + dates + domains" \
  '.body.category=="publication" and .body.startPublishedDate=="2026-01-01" and .body.endPublishedDate=="2026-08-01"
   and .body.includeDomains==["arxiv.org","pubmed.ncbi.nlm.nih.gov"] and .body.excludeDomains==["medium.com"]' \
  -- exa "systematic review of oral probiotics for acne" --tag research --category publication \
     --start 2026-01-01 --end 2026-08-01 --include-domains arxiv.org,pubmed.ncbi.nlm.nih.gov --exclude-domains medium.com

row "04 exa --contents text --max-chars → text.maxCharacters" \
  '.body.contents.text.maxCharacters==2000 and (.body.contents|has("highlights")|not)' \
  -- exa "q" --tag other --contents text --max-chars 2000

row "05 exa --contents summary --summary-query" \
  '.body.contents.summary.query=="pricing per request"' \
  -- exa "q" --tag other --contents summary --summary-query "pricing per request"

row "06 exa --contents none → no contents key" \
  '(.body|has("contents")|not)' \
  -- exa "q" --tag other --contents none

row "07 exa --max-age-hours 0 → livecrawl" \
  '.body.contents.maxAgeHours==0 and .body.contents.livecrawlTimeout==12000' \
  -- exa "q" --tag other --max-age-hours 0

row "08 exa --json-patch deep-merges last" \
  '.body.systemPrompt=="be terse" and .body.contents.highlights==true and .body.includeText==["exa"]' \
  -- exa "q" --tag other --json-patch '{"systemPrompt":"be terse","includeText":["exa"]}'

row "09 exa --country → userLocation upper" \
  '.body.userLocation=="PL"' \
  -- exa "q" --tag other --country pl

row "10 exa -n 25 accepted (cap)" \
  '.body.numResults==25' \
  -- exa "q" --tag other -n 25

row "11 brave web defaults → extra_snippets, count, token placeholder" \
  '.engine=="brave" and .params.extra_snippets=="true" and .params.count==10
   and (.url|test("res/v1/web/search\\?")) and .headers["X-Subscription-Token"]=="${BRAVE_API_KEY}"' \
  -- brave "React server components architecture explained 2026" --tag sources

row "12 brave country/lang/freshness/goggles" \
  '.params.country=="RU" and .params.search_lang=="ru" and .params.freshness=="pw"
   and .params.goggles==["$discard\n$site=vc.ru"] and (.url|test("goggles=") )' \
  -- brave "нейросети для бизнеса" --tag sources --country ru --lang ru --freshness pw --goggles $'$discard\n$site=vc.ru'

row "13 brave --mode context → llm/context + tokens" \
  '(.url|test("res/v1/llm/context")) and .params.maximum_number_of_tokens==4096 and .params.context_threshold_mode=="strict"
   and (.params|has("extra_snippets")|not)' \
  -- brave "q" --tag research --mode context --tokens-brave 4096 --threshold strict

row "14 both → exa auto+highlights n=8, brave web n=8, same query" \
  '.exa.body.type=="auto" and .exa.body.numResults==8 and .exa.body.contents.highlights==true
   and .brave.params.count==8 and .exa.body.query=="exa vs brave neural search" and .brave.params.q=="exa vs brave neural search"' \
  -- both "exa vs brave neural search" --tag research

row "15 both --query-exa diverges, -n 12 capped to 10" \
  '.exa.body.query=="comparison article of Exa and Brave search APIs" and .brave.params.q=="exa vs brave"
   and .exa.body.numResults==10 and .brave.params.count==10' \
  -- both "exa vs brave" --tag research --query-exa "comparison article of Exa and Brave search APIs" -n 12

row "16 both --mode context --type keyword --lang ru" \
  '(.brave.url|test("llm/context")) and .exa.body.type=="keyword" and .brave.params.search_lang=="ru"' \
  -- both "q" --tag research --mode context --type keyword --lang ru

row "17 contents default → text.maxCharacters 8000, top-level" \
  '.body.urls==["https://exa.ai/docs"] and .body.text.maxCharacters==8000 and (.body|has("contents")|not)
   and (.url|endswith("/contents"))' \
  -- contents https://exa.ai/docs

row "18 contents --full → text:true" \
  '.body.text==true' \
  -- contents https://exa.ai/docs --full

row "19 contents subpages + target + max-age" \
  '.body.subpages==5 and .body.subpageTarget==["api","pricing"] and .body.maxAgeHours==24 and .body.livecrawlTimeout==15000' \
  -- contents https://exa.ai/docs --subpages 5 --subpage-target api,pricing --max-age-hours 24 --livecrawl-timeout 15000

row "20 contents --highlights, two urls" \
  '.body.highlights==true and (.body.urls|length)==2 and (.body|has("text")|not)' \
  -- contents https://a.com https://b.com --highlights

row "21 context default → tokensNum dynamic" \
  '.body.tokensNum=="dynamic" and (.url|endswith("/context"))' \
  -- context "python urllib POST json with custom headers example"

row "22 context --tokens 5000 → int" \
  '.body.tokensNum==5000' \
  -- context "q" --tokens 5000

row "23 verdict --dry-run shape (force, pair absent)" \
  '.kind=="verdict" and .pair_id=="deadbeef" and .winner=="exa" and .why=="relevance" and .note=="n"' \
  -- verdict deadbeef exa --why relevance --note n --force

echo "== wave 2: validation guards =="
expect_exit "help exits 0" 0 -- --help
expect_exit "no tag → exit 1" 1 -- exa "q" --dry-run
expect_exit "bad tag → exit 1" 1 -- exa "q" --tag nope --dry-run
expect_exit "exa -n 26 → exit 1" 1 -- exa "q" --tag other -n 26 --dry-run
expect_exit "exa -n 0 → exit 1" 1 -- exa "q" --tag other -n 0 --dry-run
expect_exit "bad --type → exit 1" 1 -- exa "q" --tag other --type deepest --dry-run
expect_exit "category company + --start → exit 1" 1 -- exa "q" --tag company --category company --start 2026-01-01 --dry-run
expect_exit "category people + --exclude-domains → exit 1" 1 -- exa "q" --tag people --category people --exclude-domains x.com --dry-run
expect_exit "category people + non-linkedin include → exit 1" 1 -- exa "q" --tag people --category people --include-domains github.com --dry-run
expect_exit "bad --start format → exit 1" 1 -- exa "q" --tag other --start 01.01.2026 --dry-run
expect_exit "bad --json-patch → exit 1" 1 -- exa "q" --tag other --json-patch '{broken' --dry-run
expect_exit "brave -n 21 → exit 1" 1 -- brave "q" --tag other -n 21 --dry-run
expect_exit "brave bad freshness → exit 1" 1 -- brave "q" --tag other --freshness yesterday --dry-run
expect_exit "contents no url → exit 1" 1 -- contents --dry-run
expect_exit "contents not-a-url → exit 1" 1 -- contents exa.ai --dry-run
expect_exit "contents --text --summary mutually exclusive → exit 1" 1 -- contents https://a.com --text --summary --dry-run
expect_exit "context --tokens 10 → exit 1" 1 -- context "q" --tokens 10 --dry-run
expect_exit "verdict bad pair id → exit 1" 1 -- verdict xyz exa --why relevance --dry-run
expect_exit "verdict missing --why → exit 1" 1 -- verdict deadbeef exa --dry-run
expect_exit "verdict bad winner → exit 1" 1 -- verdict deadbeef both --why relevance --dry-run
expect_exit "report bad --since → exit 1" 1 -- report --since yesterday

echo "== wave 3: log + report on a synthetic log (\$0) =="
TMPLOG=$(mktemp "${TMPDIR:-/tmp}/ws-selftest.XXXXXX")
export WEBSEARCH_LOG="$TMPLOG"
"$PY" "$WS" report >/dev/null 2>&1 && pass "report on empty log exits 0" || fail "report on empty log"
if "$PY" "$WS" report 2>/dev/null | grep -q 'сравнимых 0'; then pass "empty report says 0 comparable"; else fail "empty report text"; fi
# synthesize 12 comparable pairs (tag research, lang en) + 1 degraded + verdicts
"$PY" - "$TMPLOG" <<'EOF'
import json, sys
p = sys.argv[1]
ts = "2026-08-25T01:00:00+02:00"
with open(p, "a", encoding="utf-8") as f:
    for i in range(12):
        pid = "%08x" % (0xa0000000 + i)
        for eng, mode, lat, cost, src in (("exa", "auto", 900 + i, 0.007, "api"), ("brave", "web", 600 + i, 0.005, "fixed")):
            f.write(json.dumps({"kind": "call", "ts": ts, "pair_id": pid, "host_cmd": "both", "engine": eng, "cmd": "search" if eng == "exa" else "web",
                                "mode": mode, "query": "q%d" % i, "lang": "en", "tag": "research", "n_req": 8, "n_res": 8, "latency_ms": lat,
                                "cost_usd": cost, "cost_src": src, "http": 200, "top_urls": [], "top_domains": ["a.com", "b.com", "%s.com" % eng, "d%d.com" % i, "e.com"],
                                "err": None, "degraded": False}, ensure_ascii=False) + "\n")
        f.write(json.dumps({"kind": "verdict", "ts": ts, "pair_id": pid, "winner": "exa" if i % 3 else "brave", "why": "relevance" if i % 2 else "noise", "note": None}) + "\n")
    pid = "deadbeef"
    f.write(json.dumps({"kind": "call", "ts": ts, "pair_id": pid, "host_cmd": "both", "engine": "exa", "cmd": "search", "mode": "auto", "query": "x", "lang": "ru", "tag": "news",
                        "n_req": 8, "n_res": 8, "latency_ms": 700, "cost_usd": 0.007, "cost_src": "api", "http": 200, "top_urls": [], "top_domains": ["a.com"], "err": None, "degraded": True}) + "\n")
    f.write(json.dumps({"kind": "call", "ts": ts, "pair_id": pid, "host_cmd": "both", "engine": "brave", "cmd": "web", "mode": "web", "query": "x", "lang": "ru", "tag": "news",
                        "n_req": 8, "n_res": 0, "latency_ms": 200, "cost_usd": 0, "cost_src": "fixed", "http": 403, "top_urls": [], "top_domains": [], "err": "HTTP 403 SUBSCRIPTION_TOKEN_DEACTIVATED", "degraded": True}) + "\n")
    f.write("{this is not json}\n")
EOF
REP=$("$PY" "$WS" report --since 2026-08-01 2>/dev/null)
if grep -q 'пар 13 · сравнимых 12 · с вердиктом 12 (100%)' <<<"$REP"; then pass "report counts pairs/comparable/verdicts"; else fail "report counts" "$(head -3 <<<"$REP")"; fi
if grep -q 'битых строк 1' <<<"$REP"; then pass "report counts bad lines"; else fail "report bad lines"; fi
if grep -q '| research | 8 | 4 | 0 | 12 | 0.67 | 0.39 |' <<<"$REP"; then pass "win-rate by tag with Wilson LB"; else fail "win-rate by tag" "$(grep research <<<"$REP")"; fi
if grep -q 'победителя не называем' <<<"$REP"; then pass "n<20 → no winner declared"; else fail "n<20 note"; fi
if grep -q 'Средний overlap top-5 доменов: 0.80' <<<"$REP"; then pass "mean overlap 4/5"; else fail "overlap" "$(grep overlap <<<"$REP")"; fi
if grep -q '| brave/web | 13 | 8% |' <<<"$REP"; then pass "engine table err% (1 of 13)"; else fail "engine table" "$(grep 'brave/web' <<<"$REP")"; fi
if "$PY" "$WS" report --since 2026-08-01 --out json 2>/dev/null | jq -e '.comparable==12 and .by_tag[0].wilson_lb>0.38 and .xtab.exa.relevance==4' >/dev/null; then pass "report --out json"; else fail "report json"; fi
expect_exit "verdict on unknown pair → exit 1" 1 -- verdict 0badc0de exa --why relevance
if "$PY" "$WS" verdict a0000001 tie --why coverage --note "selftest" 2>/dev/null | grep -q 'verdict recorded: pair=a0000001 winner=tie'; then pass "verdict appends"; else fail "verdict append"; fi
if tail -1 "$TMPLOG" | jq -e '.kind=="verdict" and .winner=="tie" and .note=="selftest"' >/dev/null; then pass "verdict line is valid JSON"; else fail "verdict line"; fi
if "$PY" "$WS" verdict deadbeef exa --why lang 2>&1 >/dev/null | grep -q 'degraded'; then pass "verdict on degraded pair warns"; else fail "degraded warn"; fi
rm -f "$TMPLOG"
unset WEBSEARCH_LOG

if [[ "${1:-}" == "--live" ]]; then
  echo "== wave 4: live smoke (≈\$0.02) =="
  export WEBSEARCH_LOG="${WEBSEARCH_LOG_LIVE:-$HOME/.claude/telemetry/search-ab/events.jsonl}"
  # Key standard: env -> macOS Keychain. websearch.py resolves on its own; the guards below
  # need the values in the environment too, so pull whatever is missing through secret.sh.
  SECRET_SH="$(cd "$(dirname "$WS")" && pwd)/secret.sh"
  [[ -f "$SECRET_SH" ]] && eval "$(bash "$SECRET_SH" --export EXA_API_KEY BRAVE_API_KEY 2>/dev/null || true)"
  if [[ -z "${EXA_API_KEY:-}" && ! -s "$HOME/.config/exa/key" ]]; then
    fail "live: EXA_API_KEY not set"
  else
    out=$("$PY" "$WS" exa "Exa search API pricing and free credits" --tag other --type fast -n 3 --contents none --out urls 2>/dev/null); rc=$?
    if [[ $rc -eq 0 && -n "$out" ]]; then pass "live exa fast → $(wc -l <<<"$out" | tr -d ' ') urls"; else fail "live exa fast" "exit $rc"; fi
    out=$("$PY" "$WS" exa "detailed comparison of neural and keyword web search APIs for AI agents" --tag research -n 3 2>/dev/null); rc=$?
    if [[ $rc -eq 0 ]] && grep -q '── EXA auto' <<<"$out" && grep -q '↳' <<<"$out"; then pass "live exa auto+highlights renders"; else fail "live exa auto" "exit $rc"; fi
    out=$("$PY" "$WS" contents https://exa.ai/docs/reference/pricing --highlights 2>/dev/null); rc=$?
    if [[ $rc -eq 0 ]] && grep -q '── EXA contents highlights' <<<"$out"; then pass "live exa contents highlights"; else fail "live exa contents" "exit $rc"; fi
    "$PY" "$WS" exa "q" --tag other --type keyword -n 1 --contents none >/dev/null 2>"$TMPDIR/ws-kw.err"; rc=$?
    if [[ $rc -eq 0 ]]; then pass "live exa legacy keyword still accepted"; elif grep -q 'HTTP 400' "$TMPDIR/ws-kw.err"; then fail "live exa keyword" "API now rejects legacy type — switch docs/SKILL to auto"; else fail "live exa keyword" "exit $rc"; fi
    rm -f "$TMPDIR/ws-kw.err"
  fi
  if [[ -z "${BRAVE_API_KEY:-}" ]]; then
    fail "live: BRAVE_API_KEY not set"
  else
    out=$("$PY" "$WS" brave "exa search api" --tag other -n 3 --out urls 2>"$TMPDIR/ws-brave.err"); rc=$?
    if [[ $rc -eq 0 && -n "$out" ]]; then pass "live brave web → $(wc -l <<<"$out" | tr -d ' ') urls"
    elif grep -q 'HTTP 40[23]' "$TMPDIR/ws-brave.err"; then printf '[warn] live brave skipped: %s\n' "$(grep -o 'HTTP 40[23][^|]*' "$TMPDIR/ws-brave.err" | head -1)"; pass "live brave 402/403 reported cleanly (billing, not a code failure)"
    else fail "live brave web" "exit $rc"; fi
    rm -f "$TMPDIR/ws-brave.err"
  fi
fi

echo "== $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
