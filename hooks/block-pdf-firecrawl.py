#!/usr/bin/env python3
# PreToolUse: deny Firecrawl PDF-скрапа (1 кредит/страница) → редирект на pdf-fetch.sh;
# deny x.com/twitter.com (30 кредитов за AI-обработанный пересказ, дословного тела нет).
import sys, json, re, os
from urllib.parse import urlsplit
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ROOT = os.environ.get("CLAUDE_PLUGIN_ROOT", "")
PDF_FETCH = (ROOT.rstrip("/") + "/scripts/pdf-fetch.sh") if ROOT else "${CLAUDE_PLUGIN_ROOT}/scripts/pdf-fetch.sh"
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
    deny("x.com/twitter.com: Firecrawl отдаёт AI-обработанный пересказ за ~30 кредитов, дословного тела страницы нет — "
         "снапшот из него гейт не закроет. Дословный текст — `defuddle parse <url> --md` или `curl https://r.jina.ai/<url>`; "
         "твиты/треды — канал twitter (Grok x_*).")
if any(PDF.search(u) for u in urls):
    parsers = ti.get("parsers") or []
    maxp = (ti.get("pdfOptions") or {}).get("maxPages")
    capped = ("pdf" in parsers) and isinstance(maxp, int) and 1 <= maxp <= 20
    if not capped:
        deny("PDF-URL: Firecrawl биллит 1 кредит/страница. Извлеки локально — "
             "bash " + PDF_FETCH + " <url> → Read .txt (0 кредитов). "
             "Если Firecrawl реально нужен как загрузчик: parsers:[\"pdf\"] И pdfOptions.maxPages ≤ 20.")
sys.exit(0)
