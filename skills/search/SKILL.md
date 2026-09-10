---
name: search
description: "Web search via Brave (keyword) + Exa (semantic) through scripts/websearch.py with cost log; contents/Firecrawl for full pages. research/news → brave, describe-a-page → exa. Triggers: search the web, google it, find info on. RU triggers: найди в интернете, поищи в сети, загугли, найди информацию о, что известно о. Do NOT use for: communities → /full-research; papers → /search-paper."
argument-hint: <query>
---

# Web Search — Brave + Exa через `websearch.py`

Два движка, один скрипт: `S=${CLAUDE_PLUGIN_ROOT}/scripts/websearch.py`. Ключи — `EXA_API_KEY`, `BRAVE_API_KEY`: скрипт резолвит их сам по стандарту плагина (env → Связка ключей macOS через `scripts/secret.sh`; заводит их `/jadlis-search:keys`, Brave — ещё и `/plugin configure jadlis-search@jadlis`). Каждый вызов пишет `[cost]` в stderr и строку в лог `$WEBSEARCH_LOG` (дефолт — `telemetry/search-ab/events.jsonl` в конфиг-дире Claude); лог остаётся источником для `report` и телеметрии стоимости.

Перед Фазой 1 прочитать `references/gotchas.md` — ловушки Exa/Firecrawl (кап, crawl, json-формат, прайсы).

**Итог A/B «Exa vs Brave» (окно 25.08–07.09.2026, закрыто досрочно 01.09):** счёт 38:34:30 (exa:brave:tie) — ничья. Решение: **роутинг по интенту**, `both` больше не дефолт, `verdict` после пары — по желанию (лог принимает, отчёт считает). Движок выбирается по тому, что он умеет, а не «оба и сравнить».

**Запрос пользователя:** `$ARGUMENTS`

---

## Фаза 1 — Интент → команда

| Интент | Команда |
|---|---|
| Research, «что известно о X», список источников, новости, свежесть — **default** | `python3 $S brave "<q>" --tag research\|sources\|news [--freshness pw\|pm] [-n 8]` |
| «Опиши целевую страницу» (семантика, Exa сильнее) | `python3 $S exa "<описание страницы>" --tag …` |
| Люди / компании / научные публикации / новости по типу | `python3 $S exa "…" --tag people\|company\|research\|news --category people\|company\|publication\|news` |
| Ограничить домены / даты | Exa: `--include-domains a.com,b.org` `--exclude-domains …` `--start 2026-01-01 --end …`; Brave: `--goggles $'$discard\n$site=vc.ru'` `--freshness pd\|pw\|pm\|py` |
| Оба движка — **только по явной просьбе** («сравни движки», «через оба») | `python3 $S both "<q>" --tag … [--query-exa "<описание страницы>"]` → синтез → `verdict` (опционально) |
| Одна страница целиком / подстраницы / свежий краул | `python3 $S contents <url…> --full [--text\|--highlights\|--summary] [--subpages 5 --subpage-target api,pricing] [--max-age-hours 0]` (~$0.001/стр.; **`--full` обязателен для снапшотов** — дефолт `--max-chars 8000` молча режет страницу) → фоллбэк `mcp__plugin_jadlis-search_firecrawl__firecrawl_scrape` |
| Код / API / библиотека | Context7 → `python3 $S context "<q>" [--tokens 5000]` (Exa Code, $0.007) |
| **Страница = PDF** | `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pdf-fetch.sh" "<url>"` → `Read` (0 кр; Firecrawl биллит 1 кр/стр, хук deny-ит) |
| Новости / картинки / видео | `mcp__plugin_jadlis-search_brave-search__brave_news_search` / `brave_image_search` / `brave_video_search` (или `exa --category news`) |
| Контент из многих страниц одним вызовом (Brave LLM Context) | `python3 $S brave "<q>" --tag … --mode context` |
| **Рунет глубже**, региональная выдача, операторы Яндекса | канал `yandex` в `/research` (ключ `YC_SEARCH_API_KEY`) или локальный скилл Яндекс-поиска, если установлен |
| Многошаговый агентный поиск / список компаний / обогащение | `mcp__exa__agent_run` — $0.025–$1.00 за run, **только по явной просьбе** |

`--tag` обязателен: `research` · `sources` · `news` · `code` · `people` · `company` · `product` · `other`. Фан-аут **>5 запросов — спросить пользователя**; дневной софт-кап $2 (`--force` — обход). Нет ключа одного движка (`exit 2`) → второй движок без вопросов; `both` при Brave 402/403 печатает `── PAIR DEGRADED` и работает на Exa.

## Формулировка запроса — движки разные

- **Brave = keyword-индекс:** ключевые слова, операторы (`site:`, кавычки), goggles. `React server components architecture explained 2026`.
- **Exa = эмбеддинги:** описание целевой страницы натуральной фразой, без булевых операторов и кавычек; 1–2 слова = разброс. `technical blog post explaining how React server components work internally`. Дефолт `--type auto` + highlights; `-n` не поднимать выше 10–15 — лучше 2–3 запроса с разных углов.
- **Русский:** Exa `auto`/`fast` на RU-запрос уводит в **англоязычные** источники (для науки — плюс). Для Рунета — `--type keyword` (лексический, даёт русские страницы) или Яндекс; `neural` — русские, но шумнее.
- В `both` один текст уходит обоим; когда формулировки должны различаться — `--query-exa "<описание страницы>"`.
- Полные правила Exa — `references/exa-rules.md`.

## Быстрый старт

```bash
S=${CLAUDE_PLUGIN_ROOT}/scripts/websearch.py
python3 $S brave "exa vs brave neural search" --tag research -n 5           # default: research/news
python3 $S exa "detailed practitioner blog post about X" --tag research     # семантика (auto + highlights)
python3 $S exa "пробиотики при акне исследования" --tag research --type keyword   # RU-страницы
python3 $S exa "systematic review of X" --tag research --category publication --start 2026-01-01 -n 10
python3 $S both "exa vs brave neural search" --tag research -n 5            # только по просьбе: пара + pair_id
python3 $S verdict 8e509b38 exa --why relevance --note "Brave дал маркетинг"  # опционально после both
python3 $S contents https://exa.ai/docs --full --subpages 5 --subpage-target api            # --full: без обрезки 8000 симв.
python3 $S context "python urllib POST json custom headers" --tokens 5000
python3 $S report --since 14d                                               # сводка лога (стоимость, пары)
python3 $S exa "q" --tag other --dry-run                                    # тело запроса, $0, ключ не нужен
```

Общие флаги: `--out text|json|urls` · `--dry-run` · `--no-log` · `--full` (снять кэпы длины) · `--force` (обход капа) · `--timeout 20` · `--json-patch '{…}'` (редкие поля: `systemPrompt`, `outputSchema`, `includeText`…).
Exit: 0 ок (в т.ч. деградированная пара) · 1 usage · 2 нет ключа · 3 API · 4 таймаут · 5 не разобрали.

## Вывод `both` и что с ним делать

```
pair=8e509b38 tag=research lang=en n=5  q="…"
── EXA auto · 1081 ms · $0.0070 · 5 res
 1 groundroute.ai/rankings/brave-vs-exa · Brave Search vs Exa: cost, speed & quality… · 2026-03-11
   ↳ выдержка ≤160 симв.
── BRAVE web · 640 ms · $0.0050 · 5 res
 …
── OVERLAP top-5 доменов 2/5 · только exa: … · только brave: …
verdict: python3 …/websearch.py verdict 8e509b38 exa|brave|tie --why relevance|freshness|coverage|lang|noise [--note "…"]
```

- Ответ синтезируй из **обоих** блоков; если одного не хватает — добей `contents <url>` по 1–2 URL или `exa` с другого угла.
- `--out json` — сырые ответы API (когда нужны поля `author`, `publishedDate`, полный текст); `--out urls` — только ссылки.

## Фаза 2 — Синтез

1. Синтезируй информацию из источников; ключевые факты и выводы; источники `[Title](url)`; расхождения отметь.
2. После `both` — при желании `verdict <pair_id> exa|brave|tie --why … --note "…"` (A/B закрыт; вердикт нужен только если пользователь собирает новую серию сравнений). Правила вердикта и чтение отчёта — `references/ab-log.md`.

## Лимиты и цены

| Движок | Цена | Лимит |
|---|---|---|
| Exa `/search` (`auto`/`fast`/`instant`/legacy `keyword`/`neural`) | $0.007/запрос ≤10 рез., +$0.001/рез. сверх; summary +$0.001/стр. | 10 QPS (free 5); `both` = 2 запроса |
| Exa `deep-lite`/`deep` · `deep-reasoning` | $0.012 · $0.015 | 4–40 с |
| Exa `/contents` | $0.001/стр. **за тип контента** (text+highlights = ×2) | 100 QPS |
| Exa `/context` | $0.007 | |
| Brave web/search | $0.005/запрос | 50 req/s; 429 → ретрай 1 с (max 2) |
| Brave llm/context | $0.005 (assumed) | |
| Firecrawl scrape | 1 кр/стр (PDF — 1 кр/**страница** PDF) | 1 req/s |

Бесплатный тир Exa: $20 на старте + $10/мес. Legacy `keyword`/`neural` могут отключить — при 400 повторить `--type auto`. Регресс: `bash scripts/selftest.sh` ($0) · `--live` (~$0.02).

## MCP `exa` (без лога)

Если у пользователя подключён MCP `exa` (`mcp__exa__web_search_exa` / `web_fetch_exa` / `web_search_advanced_exa` / `agent_run`): использовать субагентам без Bash, `web_fetch_exa` как быстрый fetch, `agent_run` — по явной просьбе. В главном треде — скрипт (лог и учёт стоимости).

## Routing details

Canonical web-tool rules (moved here from `~/.claude/rules/routing.md`, 2026-09-06).

- **Native `WebSearch`/`WebFetch` are not used** — Brave and Exa are paid and logged. Main thread goes through `websearch.py` (cost log), not `mcp__exa__*` / `brave_web_search` directly.
- **Exa** (`EXA_API_KEY`, $0.007/search, free $10/mo): query = description of the target page, no operators. RU query in `auto` drifts to English sources → `--type keyword` or `/yandex-search`. MCP `exa` (`web_search_exa`, `web_fetch_exa`, `web_search_advanced_exa`, `agent_run`) — for subagents; `agent_run` only on explicit request ($0.025–$1/run). Do not install plugin `exa@claude-plugins-official` (ships a `search` skill — name collision).
- **Brave** (Search plan, $0.005/req): `brave_web_search` (+`extra_snippets`), `brave_llm_context` (page content in one call; script `brave --mode context`; Brave's recommended AI path). Domain filter: Goggles `$discard\n$site=domain.com` or `site:` operator. Specialized: `brave_news_search`, `brave_image_search`, `brave_video_search`. `brave_summarizer` / Answers API not used. Brave 402/403 (billing) → `both` degrades to Exa, exit 0.
- **BUG (checked 2026-08-06):** any single non-web type in `result_filter` (`discussions`, `faq`, `infobox`…) → `No web results found`, 0 results. Always add `"web"`: `result_filter=["web","discussions"]`.
- **Rate limits:** Brave 50 req/s (parallel OK); Exa `/search` 10 QPS (free tier 5), `/contents` 100 QPS; script daily soft cap $2 (`--force`); Firecrawl scrape 1 req/s. On 429: wait 1 s, retry (max 2).
- **Firecrawl:** scrape = one full page or dynamic/interactive site; `map` = site discovery; `extract` = multi-URL structured data (json format + jsonOptions). Fallback chain: scrape → scrape+waitFor(5000) → firecrawl_interact → firecrawl_map → defuddle → Playwright. Requests go through a local 5-key rotator (`127.0.0.1:8642`, launchd `com.becyborg.firecrawl-rotator`): 402 "insufficient credits" marks the key exhausted and retries the next, transparent to tools; all five exhausted → `All 5 Firecrawl keys exhausted (…)` + macOS notification. Status: `curl -s 127.0.0.1:8642/rotator/status | jq`.
- **Full-text snapshot ladder** (order fixed; first rung yielding a body ≥ ~1 000 chars and not a challenge page wins): PDF → `pdf-fetch.sh`; HTML → `defuddle parse <url> --md` (0.19.3; 403 → `-u "<browser UA>"`); empty/CSR → `curl --max-time 45 https://r.jina.ai/<url>` (local alternative on the same rung: Crawl4AI 0.9.3 in `~/.cache/crawl4ai-venv`); URL-exact index → `websearch.py contents <url> --full` (default cuts at 8 000 chars); Tavily extract — only with `TAVILY_API_KEY` (no keyless mode: 401, checked 2026-09-06); anti-bot → Firecrawl scrape **last**, never for PDF or x.com/twitter.com (hook denies: AI summary for 30 credits); behind login → Playwright. `timeout`/`gtimeout` don't exist on macOS — use the Bash tool's `timeout` parameter.
- **PDF / documents — never via Firecrawl:** Firecrawl bills PDF parsing **per page, 1 credit/page** (HTML = 1 credit); a 150-page PDF = 150 credits, fan-out without dedup multiplies ×8–12. PreToolUse hook `block-pdf-firecrawl.py` denies PDF URLs in `firecrawl_scrape`/`extract`. Default: `out=$(bash ~/.claude/scripts/pdf-fetch.sh "<url>")` → `Read "$out"` (0 credits, curl+pdftotext, cache+lock, fan-out dedup; `--md` = markitdown). 1–2 pages: `Read <pdf>` directly. `exit 2` (`PDF_UNREACHABLE`/`PDF_EMPTY` = JS gate/scan/paywall) → free-first escalation: (1) paper by DOI → Unpaywall OA link → `pdf-fetch.sh` again; (2) `/browser` (logged-in Chrome) → save/Read; (3) budget loader: Firecrawl with `parsers:[]` (~1 credit, raw PDF, no per-page parsing — check the MCP wrapper passes an empty array) → local `pdftotext`; (4) last resort: `firecrawl_scrape` with `parsers:["pdf"]` AND `pdfOptions.maxPages ≤ 20` (the only form the hook allows). Residual risk: `firecrawl_search`/`crawl`/`agent` don't see PDF URLs in their input — if the target is known to be a PDF, route via `pdf-fetch.sh`. **Key numbers may exist only inside raster figures** (Anthropic system cards: BrowseComp, HLE, GDPval-AA, Terminal-Bench…) — `pdftotext` returns the captions but not the values, so read the cached original `.pdf` with the `pages` parameter as well; details in `../search-paper/references/gotchas.md`.

## Когда НЕ использовать этот skill

- **Рунет / региональная выдача / операторы Яндекса** → канал `yandex` в full-research или локальный Яндекс-скилл
- **Соцсети/сообщества** → `/research`
- **Документация библиотек/SDK** → Context7 MCP (`resolve-library-id` → `query-docs`), затем `context`
- **GitHub issues/PRs/repos** → `gh` CLI или GitHub MCP
- **Глубокое исследование** → `/research` / `/science-research`

Контракт API Exa и живая матрица — `references/exa-api.md`; правила формулировки — `references/exa-rules.md`; схема лога и отчёта — `references/ab-log.md`.
