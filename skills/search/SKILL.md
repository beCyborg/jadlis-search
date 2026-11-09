---
name: search
description: "Web search via Exa (lite, default) + Brave (news) through scripts/websearch.py with cost log; full page text via pdf-fetch → Firecrawl. Default → exa (lite, RU too); news/freshness → brave; HN/Substack threads → exa --include-domains; Reddit → brave site:reddit.com. Triggers: search the web, google it, find info on. RU triggers: найди в интернете, поищи в сети, загугли, найди информацию о, что известно о. Do NOT use for: communities → /jadlis-research:research; papers → /jadlis-science-research:science-research."
argument-hint: <query>
---

# Web Search — Brave + Exa через `websearch.py`

Два движка, один скрипт: `S=${CLAUDE_PLUGIN_ROOT}/scripts/websearch.py`. Ключи — `EXA_API_KEY`, `BRAVE_API_KEY`: скрипт резолвит их сам по стандарту плагина (env → Связка ключей macOS через `scripts/secret.sh`; заводит их `/jadlis-search:keys`, Brave — ещё и `/plugin configure jadlis-search@jadlis`). Каждый вызов пишет `[cost]` в stderr и строку в лог `$WEBSEARCH_LOG` (дефолт — `telemetry/search-ab/events.jsonl` в конфиг-дире Claude); лог остаётся источником для `report` и телеметрии стоимости.

Перед Фазой 1 прочитать `references/gotchas.md` — ловушки Exa/Firecrawl (кап, crawl, json-формат, прайсы).

**Итог A/B «Exa vs Brave» (окно 25.08–07.09.2026, закрыто досрочно 01.09):** счёт 38:34:30 (exa:brave:tie) — ничья. Решение: **роутинг по интенту**, `both` больше не дефолт, `verdict` после пары — по желанию (лог принимает, отчёт считает). Движок выбирается по тому, что он умеет, а не «оба и сравнить».

**Повтор 10.2026 (48 запросов, слепо, два судьи разных семейств):** Exa `auto` 27 : Brave 13; Exa `auto` против `keyword` на RU — 14 : 0.

**Пересмотр 11.2026 (50 реальных запросов владельца за 3 месяца, 5 движков, слепые судьи Opus 5.5 + Codex):** средний ранг Exa `auto` 2,14 · Exa `lite` 2,16 · Brave 2,96 · Serper 3,82 · Parallel 3,92. `lite` = `auto` по качеству (p = 0,74), оба лучше Brave (32 : 12, p = 0,004), `lite` на 43 % дешевле → **дефолт `exa` = `lite`**, и на RU тоже. Brave лучший только на новостях. Поиск по площадкам (45 тем): HN и Substack — Exa `lite` с `--include-domains`; Reddit Exa не индексирует (0 результатов без ошибки) → Brave `site:reddit.com`. Отчёт: `Знания/Ресерчи/Система/Инструменты поиска и ресёрча — пересмотр 2026-11.md`.

**Запрос пользователя:** `$ARGUMENTS`

---

## Фаза 1 — Интент → команда

| Интент | Команда |
|---|---|
| Research, «что известно о X», список источников, люди, компании, продукты, документация — **default** | `python3 $S exa "<описание целевой страницы>" --tag research\|sources\|people\|company\|product [--category people\|company]` (тип `lite` по умолчанию) |
| Новости, свежесть «за неделю/месяц» | `python3 $S brave "<q>" --tag news [--freshness pd\|pw\|pm] [-n 8]` |
| Треды Hacker News / посты Substack | `python3 $S exa "<описание треда>" --tag research --include-domains news.ycombinator.com` (или `substack.com`); вторым — `brave "<q> site:substack.com"` |
| Треды Reddit | `python3 $S brave "<q> site:reddit.com" --tag research` (Exa по reddit.com возвращает 0) → дерево комментариев — Reddit MCP / `reddit-archive.py comments <id> --compact` |
| Научные публикации / новости по типу | `python3 $S exa "…" --tag research\|news --category publication\|news` |
| Ограничить домены / даты | Exa: `--include-domains a.com,b.org` `--exclude-domains …` `--start 2026-01-01 --end …`; Brave: `--goggles $'$discard\n$site=vc.ru'` `--freshness pd\|pw\|pm\|py` |
| Оба движка — **только по явной просьбе** («сравни движки», «через оба») | `python3 $S both "<q>" --tag … [--query-exa "<описание страницы>"]` → синтез → `verdict` (опционально) |
| Одна страница целиком (снимок под цитату) | лестница из «Routing details»: PDF → `pdf-fetch.sh`; HTML → `bash "${CLAUDE_PLUGIN_ROOT}/scripts/firecrawl-read.sh" "<url>"`, не прочиталась (exit 3) → пометь «не прочитано»; если от неё зависит вывод — отдай субагенту `browser-operator` (его нет — страница остаётся «не прочитано»); Reddit → Reddit-инструменты. Подстраницы / свежий краул сайта — `python3 $S contents <url> --full --subpages 5` (~0.001 $/стр.) |
| Код / API / библиотека | Context7 → `python3 $S context "<q>" [--tokens 5000]` (Exa Code, 0.007 $) |
| **Страница = PDF** | `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pdf-fetch.sh" "<url>"` → `Read` (0 кр; Firecrawl биллит 1 кр/стр, хук deny-ит) |
| Новости / картинки / видео | `mcp__plugin_jadlis-search_brave-search__brave_news_search` / `brave_image_search` / `brave_video_search` (или `exa --category news`) |
| Контент из многих страниц одним вызовом (Brave LLM Context) | `python3 $S brave "<q>" --tag … --mode context` |
| **Рунет глубже**, региональная выдача, операторы Яндекса | канал `yandex` в `/research` (ключ `YC_SEARCH_API_KEY`) или локальный скилл Яндекс-поиска, если установлен |
| Многошаговый агентный поиск / список компаний / обогащение | `mcp__exa__agent_run` — 0.025 $–1.00 $ за run, **только по явной просьбе** |

`--tag` обязателен: `research` · `sources` · `news` · `code` · `people` · `company` · `product` · `other`. Фан-аут **>5 запросов — спросить пользователя**; дневной софт-кап 2 $ (`--force` — обход). Нет ключа одного движка (`exit 2`) → второй движок без вопросов; `both` при Brave 402/403 печатает `── PAIR DEGRADED` и работает на Exa. **HTTP 402 останавливает серию:** 15 минут все вызовы к тому же хосту сразу отвечают `STOP … 402` без сети — переключи движок, не повторяй (30.10.2026 было 888 вызовов за час после 402).

## Формулировка запроса — движки разные

- **Brave = keyword-индекс:** ключевые слова, операторы (`site:`, кавычки), goggles. `React server components architecture explained 2026`.
- **Exa = эмбеддинги:** описание целевой страницы натуральной фразой, без булевых операторов и кавычек; 1–2 слова = разброс. `technical blog post explaining how React server components work internally`. Дефолт `--type lite` + highlights (`auto` — то же качество за 7 $ вместо 4 $, медленнее); `-n` не поднимать выше 10–15 — лучше 2–3 запроса с разных углов. Запросы с `site:` на 50-запросном тесте без надёжного победителя: для домена — `--include-domains`, не `site:`.
- **Русский:** Exa — дефолт `lite`, запрос по-русски полным предложением (на RU `lite` лучший, ранг 1,92). `keyword`/`neural` — legacy, для RU не использовать. Глубокий Рунет, регионы, операторы — Яндекс.
- В `both` один текст уходит обоим; когда формулировки должны различаться — `--query-exa "<описание страницы>"`.
- Полные правила Exa — `references/exa-rules.md`.

## Быстрый старт

```bash
S=${CLAUDE_PLUGIN_ROOT}/scripts/websearch.py
python3 $S exa "detailed practitioner blog post about X" --tag research     # default: lite + highlights
python3 $S brave "Tesla FSD Europe approval" --tag news --freshness pw -n 8   # новости
python3 $S exa "исследования пробиотиков при акне: какие штаммы помогают" --tag research   # RU: тоже lite
python3 $S exa "practitioners discussing MCP security problems" --tag research --include-domains news.ycombinator.com
python3 $S exa "systematic review of X" --tag research --category publication --start 2026-01-01 -n 10
python3 $S both "exa vs brave neural search" --tag research -n 5            # только по просьбе: пара + pair_id
python3 $S verdict 8e509b38 exa --why relevance --note "Brave дал маркетинг"  # опционально после both
python3 $S contents https://exa.ai/docs --full --subpages 5 --subpage-target api            # --full: без обрезки 8000 симв.
python3 $S context "python urllib POST json custom headers" --tokens 5000
python3 $S report --since 14d                                               # сводка лога (стоимость, пары)
python3 $S exa "q" --tag other --dry-run                                    # тело запроса, 0 $, ключ не нужен
```

Общие флаги: `--out text|json|urls` · `--dry-run` · `--no-log` · `--full` (снять кэпы длины) · `--force` (обход капа) · `--timeout 20` · `--json-patch '{…}'` (редкие поля: `systemPrompt`, `outputSchema`, `includeText`…).
Exit: 0 ок (в т.ч. деградированная пара) · 1 usage · 2 нет ключа · 3 API · 4 таймаут · 5 не разобрали.

## Вывод `both` и что с ним делать

```
pair=8e509b38 tag=research lang=en n=5  q="…"
── EXA auto · 1081 ms · 0.0070 $ · 5 res
 1 groundroute.ai/rankings/brave-vs-exa · Brave Search vs Exa: cost, speed & quality… · 2026-03-11
   ↳ выдержка ≤160 симв.
── BRAVE web · 640 ms · 0.0050 $ · 5 res
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
| Exa `/search` `lite` (дефолт) | 0.004 $/запрос ≤10 рез. | 10 QPS |
| Exa `/search` (`auto`/`fast`/`instant`/legacy `keyword`/`neural`) | 0.007 $/запрос ≤10 рез., +0.001 $/рез. сверх; summary +0.001 $/стр. | 10 QPS (free 5); `both` = 2 запроса |
| Exa `deep-lite`/`deep` · `deep-reasoning` | 0.012 $ · 0.015 $ | 4–40 с |
| Exa `/contents` | 0.001 $/стр. **за тип контента** (text+highlights = ×2) | 100 QPS |
| Exa `/context` | 0.007 $ | |
| Brave web/search | 0.005 $/запрос | 50 req/s; 429 → ретрай 1 с (max 2, в `http_json`); 402 → стоп серии на 15 мин |
| Brave llm/context | 0.005 $ (assumed) | |
| Firecrawl scrape | 1 кр/стр (PDF — 1 кр/**страница** PDF) | 1 req/s |

Бесплатный тир Exa: 10 $/мес + разовые 10 $ (11.2026). Legacy `keyword`/`neural` могут отключить — при 400 повторить `--type lite`. Регресс: `bash scripts/selftest.sh` (0 $) · `--live` (~0.02 $).

## MCP `exa` (без лога)

Если у пользователя подключён MCP `exa` (`mcp__exa__web_search_exa` / `web_fetch_exa` / `web_search_advanced_exa` / `agent_run`): использовать субагентам без Bash, `web_fetch_exa` как быстрый fetch, `agent_run` — по явной просьбе. В главном треде — скрипт (лог и учёт стоимости).

## Routing details

Canonical web-tool rules (moved here from `~/.claude/rules/routing.md`, 2026-09-06).

- **Native `WebSearch`/`WebFetch` are not used** — Brave and Exa are paid and logged. Main thread goes through `websearch.py` (cost log), not `mcp__exa__*` / `brave_web_search` directly.
- **Exa** (`EXA_API_KEY`; `lite` 0.004 $/search is the default, `auto` 0.007 $): query = description of the target page, no operators. Default engine for every intent except news (blind test 2026-11 on 50 real queries: lite = auto, both beat Brave 32:12; Russian too). Domain-scoped thread search: `--include-domains news.ycombinator.com|substack.com`. **Exa does not index reddit.com** — 0 results, no error, no charge → Reddit via Brave `site:reddit.com` or the Reddit MCP. Deep Runet/regional → `/yandex-search`. MCP `exa` (`web_search_exa`, `web_fetch_exa`, `web_search_advanced_exa`, `agent_run`) — for subagents; `agent_run` only on explicit request (0.025 $–1 $/run). Do not install plugin `exa@claude-plugins-official` (ships a `search` skill — name collision).
- **Brave** (Search plan, 0.005 $/req): news and freshness (`--freshness`, `brave_news_search`); `brave_web_search` (+`extra_snippets`); `site:reddit.com` for Reddit threads. `brave_llm_context` (page content in one call; script `brave --mode context`): pass `maximum_number_of_tokens` (4096 when you need sources, 8192 only when you need page text) — research agents never set it and got 36k-char answers 16× per run (not yet bench-tested for quality). Domain filter: Goggles `$discard\n$site=domain.com` or `site:` operator. Specialized: `brave_news_search`, `brave_image_search`, `brave_video_search`. `brave_summarizer` / Answers API not used. Brave 402/403 (billing) → `both` degrades to Exa, exit 0.
- **BUG (checked 2026-08-06):** any single non-web type in `result_filter` (`discussions`, `faq`, `infobox`…) → `No web results found`, 0 results. Always add `"web"`: `result_filter=["web","discussions"]`.
- **Rate limits:** Brave 50 req/s (parallel OK); Exa `/search` 10 QPS (free tier 5), `/contents` 100 QPS; script daily soft cap 2 $ (`--force`; `JADLIS_SEARCH_DAILY_CAP_USD=0` disables it); Firecrawl scrape ≈ 10 req/min per free key — the rotator moves to the next key on 429 (5 keys ≈ 50 req/min; 50 parallel scrapes passed 09.11). 429: `websearch.py` waits (Retry-After ≤ 5 s, else 1 s) and retries twice by itself. 402: stop the series (see Phase 1).
- **Firecrawl:** scrape = one full page or dynamic/interactive site; `map` = site discovery; `extract` = multi-URL structured data (json format + jsonOptions). Fallback chain for a page Firecrawl fails on: scrape+waitFor(5000) → firecrawl_interact → Playwright (`/browser`). Requests go through a local 5-key rotator (`127.0.0.1:8642`, launchd `com.becyborg.firecrawl-rotator`): 402 "insufficient credits" marks the key exhausted and retries the next, transparent to tools; all five exhausted → `All 5 Firecrawl keys exhausted (…)` + macOS notification. Status: `curl -s 127.0.0.1:8642/rotator/status | jq`.
- **Full-text snapshot ladder** (bench 2026-11-04 on 60 real research pages, ground truth = headless Chromium render: the old defuddle-first ladder read 54/57 with 2 silent false accepts; bench 2026-11-09 on 20 more pages, Chrome render, 3 quotes each: Firecrawl read 20/20 pages and 53/60 quotes, RU median 4 s, 0 false accepts):
  1. PDF → `pdf-fetch.sh` (free; Firecrawl bills per PDF page).
  2. HTML → `bash "${CLAUDE_PLUGIN_ROOT}/scripts/firecrawl-read.sh" "<url>"` (Firecrawl `/v2/scrape`, `proxy:"auto"`, `onlyMainContent:true`, 1 credit per page). Endpoint: `$FIRECRAWL_API_URL` → the local rotator → `api.firecrawl.dev` with `FIRECRAWL_API_KEY` from the Keychain. The script refuses PDF and x.com/twitter.com, retries one 429, and exits 3 on no key, an HTTP error or a target 4xx/5xx → go to step 3. Interactive alternative: `firecrawl_scrape` with the same options.
  3. Firecrawl failed (exit 3: no key, HTTP error, target 4xx/5xx, anti-bot; or the body is rejected by the gate) → the page is not read: mark it «не прочитано» (unread) in the snapshot/citation, the same way as any unavailable URL. If the conclusion depends on that page, the main session hands it to the `browser-operator` subagent to read; where `browser-operator` is not installed, the page stays «не прочитано» and the answer says so. Subagents and workflow agents never open a browser themselves — they only mark the page unread.
  4. Reddit threads → Reddit tools (Reddit MCP `fetch_comments`, `reddit-archive.py comments <id> --compact`), not this ladder: every extractor is blocked there.
  5. Behind login → Playwright (`/browser`).
  - **Gate — a body is accepted only if:** ≥ 1 000 chars left after removing `data:…;base64` blobs and `<Base64-Image-Removed>`; base64 < 30 % of the body; the script matches the expected language (RU: Cyrillic ≥ 50 % of letters; EN: CJK < 5 %); no block phrase in a short body («Just a moment», «Access denied», «captcha», «verify you are human»); and, when a quote is known (snapshot for a citation), the quote is in the body verbatim or ≥ 80 % of its 6-word shingles — compare after stripping Markdown link targets `](…)`, bare URLs and punctuation. The old «≥ ~1 000 chars» rule let through a base64 loader GIF, a zh-CN copy of a Google doc and a site footer.
  - Not in the ladder any more: defuddle (the defuddle-first ladder let 2 false accepts through on 57 pages; still fine for a quick manual read), the fallback reader rung after Firecrawl (removed 09.11.2026: in 6 days of logs it read no page Firecrawl had missed), Exa `contents` (partial pages 3× in 57; keep for `--subpages` crawls), Tavily keyless (429 and 3 truncated bodies at volume), Crawl4AI (venv gone). `timeout`/`gtimeout` don't exist on macOS — use the Bash tool's `timeout` parameter.
- **PDF / documents — never via Firecrawl:** Firecrawl bills PDF parsing **per page, 1 credit/page** (HTML = 1 credit); a 150-page PDF = 150 credits, fan-out without dedup multiplies ×8–12. PreToolUse hook `block-pdf-firecrawl.py` denies PDF URLs in `firecrawl_scrape`/`extract`. Default: `out=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/pdf-fetch.sh" "<url>")` → `Read "$out"` (0 credits, curl+pdftotext, cache+lock, fan-out dedup; `--md` = markitdown). 1–2 pages: `Read <pdf>` directly. `exit 2` (`PDF_UNREACHABLE`/`PDF_EMPTY` = JS gate/scan/paywall) → free-first escalation: (1) paper by DOI → Unpaywall OA link → `pdf-fetch.sh` again; (2) `/browser` (logged-in Chrome) → save/Read; (3) budget loader: Firecrawl with `parsers:[]` (~1 credit, raw PDF, no per-page parsing — check the MCP wrapper passes an empty array) → local `pdftotext`; (4) last resort: `firecrawl_scrape` with `parsers:["pdf"]` AND `pdfOptions.maxPages ≤ 20` (the only form the hook allows). Residual risk: `firecrawl_search`/`crawl`/`agent` don't see PDF URLs in their input — if the target is known to be a PDF, route via `pdf-fetch.sh`. **Key numbers may exist only inside raster figures** (Anthropic system cards: BrowseComp, HLE, GDPval-AA, Terminal-Bench…) — `pdftotext` returns the captions but not the values, so read the cached original `.pdf` with the `pages` parameter as well; details in the jadlis-science-research plugin, `skills/science-research/references/gotchas.md`.

## Когда НЕ использовать этот skill

- **Рунет / региональная выдача / операторы Яндекса** → канал `yandex` в full-research или локальный Яндекс-скилл
- **Соцсети/сообщества** → `/research`
- **Документация библиотек/SDK** → Context7 MCP (`resolve-library-id` → `query-docs`), затем `context`
- **GitHub issues/PRs/repos** → `gh` CLI или GitHub MCP
- **Глубокое исследование** → `/research` / `/science-research`

Контракт API Exa и живая матрица — `references/exa-api.md`; правила формулировки — `references/exa-rules.md`; схема лога и отчёта — `references/ab-log.md`.
