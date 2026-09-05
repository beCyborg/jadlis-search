---
name: search
description: "Поиск в интернете двумя движками — Brave Search (keyword) + Exa (семантический, api.exa.ai) — через scripts/websearch.py с логом вызовов, Firecrawl для полной страницы. Роутинг по интенту (A/B Exa vs Brave закрыт 2026-09: ничья): research/news/свежесть → brave; «опиши целевую страницу», people/company/publication, домены/даты → exa; both — только по явной просьбе; contents (страница/подстраницы), context (код), brave_*_search MCP (news/images/video).\nTRIGGER when: user says \"найди в интернете\", \"поищи в интернете\", \"загугли\", \"найди информацию о\", \"что известно о\", \"поищи в сети\", \"search\", \"/search\", \"web search\", \"exa\", \"поищи через exa\", or asks to find/research information online.\nDO NOT TRIGGER when: social media research (use /jadlis-research:full-research with community channels), scraping known URL (use `contents <url>` here or `mcp__plugin_jadlis-research_firecrawl__firecrawl_scrape`), code/library docs (use Context7 first), GitHub (use gh CLI), RU-специфичный поиск — Рунет, операторы Яндекса, региональная выдача (канал yandex в full-research или локальный скилл Яндекс-поиска, если установлен)."
argument-hint: <query>
---

# Web Search — Brave + Exa через `websearch.py`

Два движка, один скрипт: `S=${CLAUDE_PLUGIN_ROOT}/scripts/websearch.py`. Ключи — env `EXA_API_KEY`, `BRAVE_API_KEY` (блок `env` в settings.json, ставит `/jadlis-research:keys`). Каждый вызов пишет `[cost]` в stderr и строку в лог `$WEBSEARCH_LOG` (дефолт — `telemetry/search-ab/events.jsonl` в конфиг-дире Claude); лог остаётся источником для `report` и телеметрии стоимости.

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
| Одна страница целиком / подстраницы / свежий краул | `python3 $S contents <url…> --full [--text\|--highlights\|--summary] [--subpages 5 --subpage-target api,pricing] [--max-age-hours 0]` (~$0.001/стр.; **`--full` обязателен для снапшотов** — дефолт `--max-chars 8000` молча режет страницу) → фоллбэк `mcp__plugin_jadlis-research_firecrawl__firecrawl_scrape` |
| Код / API / библиотека | Context7 → `python3 $S context "<q>" [--tokens 5000]` (Exa Code, $0.007) |
| **Страница = PDF** | `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pdf-fetch.sh" "<url>"` → `Read` (0 кр; Firecrawl биллит 1 кр/стр, хук deny-ит) |
| Новости / картинки / видео | `mcp__plugin_jadlis-research_brave-search__brave_news_search` / `brave_image_search` / `brave_video_search` (или `exa --category news`) |
| Контент из многих страниц одним вызовом (Brave LLM Context) | `python3 $S brave "<q>" --tag … --mode context` |
| **Рунет глубже**, региональная выдача, операторы Яндекса | канал `yandex` в `/jadlis-research:full-research` (ключ `YC_SEARCH_API_KEY`) или локальный скилл Яндекс-поиска, если установлен |
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

## Когда НЕ использовать этот skill

- **Рунет / региональная выдача / операторы Яндекса** → канал `yandex` в full-research или локальный Яндекс-скилл
- **Соцсети/сообщества** → `/jadlis-research:full-research`
- **Документация библиотек/SDK** → Context7 MCP (`resolve-library-id` → `query-docs`), затем `context`
- **GitHub issues/PRs/repos** → `gh` CLI или GitHub MCP
- **Глубокое исследование** → `/jadlis-research:full-research` / `/jadlis-research:search-paper`

Контракт API Exa и живая матрица — `references/exa-api.md`; правила формулировки — `references/exa-rules.md`; схема лога и отчёта — `references/ab-log.md`.
