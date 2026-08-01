#!/usr/bin/env python3
# PreToolUse: deny Firecrawl PDF-скрапа (1 кредит/страница) → редирект на pdf-fetch.sh.
import sys, json, re, os
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ROOT = os.environ.get("CLAUDE_PLUGIN_ROOT", "")
PDF_FETCH = (ROOT.rstrip("/") + "/scripts/pdf-fetch.sh") if ROOT else "${CLAUDE_PLUGIN_ROOT}/scripts/pdf-fetch.sh"
ti = d.get("tool_input", {}) or {}
PDF = re.compile(r'(?i)(\.pdf($|[?#])|/TXT/PDF/|coredownload.*pdf|[?&]format=pdf)')
urls = []
if isinstance(ti.get("url"), str): urls.append(ti["url"])
if isinstance(ti.get("urls"), list): urls += [u for u in ti["urls"] if isinstance(u, str)]
if any(PDF.search(u) for u in urls):
    parsers = ti.get("parsers") or []
    maxp = (ti.get("pdfOptions") or {}).get("maxPages")
    capped = ("pdf" in parsers) and isinstance(maxp, int) and 1 <= maxp <= 20
    if not capped:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason":
                "PDF-URL: Firecrawl биллит 1 кредит/страница. Извлеки локально — "
                "bash " + PDF_FETCH + " <url> → Read .txt (0 кредитов). "
                "Если Firecrawl реально нужен как загрузчик: parsers:[\"pdf\"] И pdfOptions.maxPages ≤ 20."}}))
sys.exit(0)
