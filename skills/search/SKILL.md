---
name: search
description: "Поиск информации в интернете через Brave Search API (тариф Search) + Firecrawl. Tiered routing по интенту: brave_llm_context (контент), brave_web_search (источники), firecrawl_scrape (полная страница).\nTRIGGER when: user says \"найди в интернете\", \"поищи в интернете\", \"загугли\", \"найди информацию о\", \"что известно о\", \"поищи в сети\", \"search\", \"/search\", \"web search\", or asks to find/research information online.\nDO NOT TRIGGER when: research across communities (use /jadlis-research:full-research), scraping known URL (use `mcp__plugin_jadlis-research_firecrawl__firecrawl_scrape` напрямую), code/library docs (use Context7), GitHub (use gh CLI)."
argument-hint: <query>
---

# /jadlis-research:search — Web Search: поиск в интернете через Brave Search API

Ключ — тариф **Search** (включает web search + **LLM Context** + news/images/videos, **50 req/s**). Инструмент выбирается по интенту, НЕ «всегда снипеты → скрап».

**Запрос пользователя:** `$ARGUMENTS`

---

## Фаза 1 — Определи интент → выбери путь

| Интент | Путь | Инструмент |
|---|---|---|
| Research, «что известно о X», нужен контент из многих источников — **default** | A | `brave_llm_context` |
| Нужен ранжированный список источников / навигация | B | `brave_web_search` (+`extra_snippets`) |
| Нужна одна конкретная страница целиком | C | `firecrawl_scrape` |
| **Страница = PDF** (`.pdf`/`/TXT/PDF/`/`?format=pdf`) | C-pdf | `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pdf-fetch.sh" "<url>"` → `Read` (0 кр; Firecrawl биллит 1 кр/стр, хук deny-ит) |
| Новости / картинки / видео | — | `brave_news_search` / `brave_image_search` / `brave_video_search` |

**Формулировка запроса (Brave = keyword-based, для путей A и B):**
- Давай ключевые слова, НЕ описание страницы.
- ПЛОХО: `"comprehensive blog post explaining how React server components work"`
- ХОРОШО: `"React server components architecture explained 2026"`
- Формулируй на языке, на котором ожидаются результаты.

---

## Path A — LLM Context (default для research)

`mcp__plugin_jadlis-research_brave-search__brave_llm_context` возвращает **сам контент** страниц одним вызовом: `grounding.generic[]` (url, title, `snippets[]` — текст/таблицы/код) + `sources` (метаданные, `age`). Ты синтезируешь ответ и цитируешь URL из `sources`. Скрапинг НЕ нужен.

**Token budget по сложности задачи:**

| Тип | count | maximum_number_of_tokens |
|---|---|---|
| Простой факт | 5 | 2048 |
| Стандарт (default) | 20 | 8192 |
| Глубокий research | 50 | 16384 |

**Параметры:**
- `query` — keyword-запрос (max 400 chars)
- `context_threshold_mode` — `balanced` (default) / `strict` (точность) / `lenient` / `disabled`
- `freshness` — `pd`/`pw`/`pm`/`py` или `YYYY-MM-DDtoYYYY-MM-DD`
- `goggles` — domain-фильтр: `"$discard\n$site=domain.com"`
- `country` / `search_lang` — гео: при поиске по нероссийскому/нерусскоязычному рынку ставь обе явно, иначе Brave отдаёт локальную выдачу
- `maximum_number_of_urls`, `maximum_number_of_snippets_per_url` — тонкая настройка

**Если `grounding.generic` пуст** → фоллбэк на Path B. **Если по одному источнику нужна полная страница** → добей Path C.

## Path B — Web Search + extra_snippets (источники)

Когда нужен список ссылок/источников, а не синтезированный контент:

```
mcp__plugin_jadlis-research_brave-search__brave_web_search(query: "...", extra_snippets: true, count: 10-20)
```

- `extra_snippets: true` — до 5 выдержек на результат (больше контекста без скрапа).
- `freshness`, `goggles`, `country`/`search_lang` — как в Path A.
- `result_filter` — для дискуссий `"web,discussions"`. **ВСЕГДА с `"web"`:** `result_filter="discussions"` в одиночку возвращает 0 результатов — известный баг API.

## Path C — Скрапинг конкретной страницы (Firecrawl)

Когда нужен ПОЛНЫЙ текст одной страницы (длинная статья, документация):

```
mcp__plugin_jadlis-research_firecrawl__firecrawl_scrape(url: "<url>", formats: ["markdown"], onlyMainContent: true)
```

- `onlyMainContent: true` — тело без меню/футера (это «полная страница» для чтения); `false` — всё, включая навигацию.
- Структурные данные (цены, таблицы, списки) → `formats: ["json"]` + `jsonOptions`.
- Один URL за вызов; для нескольких — параллельные tool calls в одном сообщении.
- Fallback chain: scrape+`waitFor: 5000` → `firecrawl_interact` → `firecrawl_map(url, search)` → `defuddle parse <url> --md` (если CLI установлен). Страница за логином через Firecrawl не берётся — открой её сам и скопируй текст.

---

## Лимиты

- **Brave (тариф Search): 50 req/s** — параллельные вызовы допустимы. При 429 — ретрай через 1 с (max 2).
- **Firecrawl scrape: 1 req/s** — не наваливать.

## Фаза 2 — Синтез и ответ

- Синтезируй информацию из всех источников; приведи ключевые факты и выводы.
- Источники с URL в формате `[Title](url)`.
- Если информация противоречива — отметь расхождения.

## Когда НЕ использовать этот skill

- **Соцсети/сообщества, глубокое исследование** → `/jadlis-research:full-research`
- **Научная литература** → `/jadlis-research:search-paper`
- **Контент известного URL** → `mcp__plugin_jadlis-research_firecrawl__firecrawl_scrape` напрямую
- **Документация библиотек/SDK** → Context7 MCP (`resolve-library-id` → `query-docs`)
- **GitHub issues/PRs/repos** → `gh` CLI или GitHub MCP
