#!/usr/bin/env python3
# PreToolUse: deny Firecrawl PDF scrapes (1 credit/page) -> redirect to pdf-fetch.sh;
# deny x.com/twitter.com (30 credits for an AI summary, no verbatim body);
# deny firecrawl_parse on a local PDF without pdfOptions.maxPages <= 20.
import sys, json, re, os
from urllib.parse import urlsplit
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ROOT = os.environ.get("CLAUDE_PLUGIN_ROOT", "")
PDF_FETCH = (ROOT.rstrip("/") + "/scripts/pdf-fetch.sh") if ROOT else "${CLAUDE_PLUGIN_ROOT}/scripts/pdf-fetch.sh"
TWITTERAPI = (ROOT.rstrip("/") + "/scripts/twitterapi.sh") if ROOT else "${CLAUDE_PLUGIN_ROOT}/scripts/twitterapi.sh"
ti = d.get("tool_input", {}) or {}
PDF = re.compile(r'(?i)(\.pdf($|[?#])|/TXT/PDF/|coredownload.*pdf|[?&]format=pdf)')
X_HOSTS = ("x.com", "twitter.com", "mobile.twitter.com")
def x_host(u):
    try:
        h = (urlsplit(u).hostname or "").lower()
    except Exception:
        return False
    return any(h == dom or h.endswith("." + dom) for dom in X_HOSTS)
urls = []
if isinstance(ti.get("url"), str): urls.append(ti["url"])
if isinstance(ti.get("urls"), list): urls += [u for u in ti["urls"] if isinstance(u, str)]
def deny(reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason}}, ensure_ascii=False))
    sys.exit(0)
if any(x_host(u) for u in urls):
    deny("x.com/twitter.com: Firecrawl returns an AI-written summary for ~30 credits, not the verbatim page body — "
         "a snapshot from it will not satisfy a quote gate. Verbatim text: `defuddle parse <url> --md` or "
         "`curl https://r.jina.ai/<url>`; tweets and threads: bash " + TWITTERAPI + " (TwitterAPI.io REST).")
if any(PDF.search(u) for u in urls):
    parsers = ti.get("parsers") or []
    maxp = (ti.get("pdfOptions") or {}).get("maxPages")
    capped = ("pdf" in parsers) and isinstance(maxp, int) and 1 <= maxp <= 20
    if not capped:
        deny("PDF URL: Firecrawl bills 1 credit per page. Extract locally instead — "
             "bash " + PDF_FETCH + " <url> then Read the .txt (0 credits). "
             "If Firecrawl really is needed as the fetcher: parsers:[\"pdf\"] AND pdfOptions.maxPages <= 20.")
# firecrawl_parse (firecrawl-mcp 3.25+): a LOCAL file, billed per page for PDFs like scrape.
fp = ti.get("filePath") if isinstance(ti.get("filePath"), str) else ""
ctype = str(ti.get("contentType") or "").lower()
if fp.lower().endswith(".pdf") or "pdf" in ctype:
    maxp = (ti.get("pdfOptions") or {}).get("maxPages")
    if not (isinstance(maxp, int) and 1 <= maxp <= 20):
        deny("Local PDF: firecrawl_parse bills 1 credit per page. Extract it for free — "
             "`pdftotext -layout <file> -` or Read the .pdf with the `pages` parameter. "
             "If Firecrawl really is needed: pdfOptions.maxPages <= 20.")
sys.exit(0)
