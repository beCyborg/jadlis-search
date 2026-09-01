# Exa API — контракт, цены, живая матрица

Источники (перечитаны 24–25.08.2026): `https://exa.ai/docs/llms-full.txt` (полный текст доков),
`/docs/reference/search-best-practices`, `/docs/reference/pricing`, `/docs/reference/rate-limits`,
`/docs/reference/exa-mcp`, репо `exa-labs/exa-mcp-server` (`src/toolRegistry.ts`) и `exa-labs/agent-skills`.
Живая сверка — раздел «Живая матрица» ниже. Скрипт: `scripts/websearch.py` (стройка тел — `--dry-run`).

## Auth, база, лимиты

- База `https://api.exa.ai`; заголовок `x-api-key: $EXA_API_KEY` (принимается и `Authorization: Bearer`).
- Ключ: env `EXA_API_KEY` (`~/.zshenv`), фоллбэк файл `~/.config/exa/key` (mode 600) — так же резолвят скиллы Exa.
- Бесплатно: $20 на старте (~2 800 поисков) + $10/мес, карта не нужна. Дашборд: https://dashboard.exa.ai
- QPS: `/search` 10 (free-тир 5), `/contents` 100, `/answer` 10. 429 → `{"error":"You've exceeded your Exa rate limit…"}`. Баланс лимиты не поднимает.

## Эндпоинты и цены

| Эндпоинт | Цена | Примечание |
|---|---|---|
| `POST /search` (`auto`/`fast`/`instant`/legacy `keyword`/`neural`) | **$0.007/запрос** (≤10 рез.) + $0.001/результат сверх 10 | `fast`/`instant` не дешевле `auto` |
| `POST /search` `deep-lite` / `deep` | $0.012/запрос | синтез, 4–15 с |
| `POST /search` `deep-reasoning` | $0.015/запрос | 12–40 с |
| AI-summary (`contents.summary`) | +$0.001/страница | один LLM-вызов на результат |
| `POST /contents` | $0.001/страница **за каждый тип контента** | text+highlights = ×2 |
| `POST /context` (Exa Code) | $0.007/запрос (по факту `costDollars.search.neural`) | |
| `POST /answer` | $0.005/запрос | **не использовать** — доки: «если LLM уже есть, дай ему `/search` как тул» |
| `POST /agent/runs` | $0.012 (minimal) · $0.025 (low, default) · $0.10 · $0.50 · $1.00 (xhigh); `auto` метрится, кап $5 | через MCP `agent_run`, только по явной просьбе |
| `/findSimilar`, `/research`, Websets | deprecated | `/research` заменён `type:"deep-reasoning"`, Websets → Agent API |

`costDollars` приходит в каждом ответе (`{"total":0.007,"search":{"neural":0.007},"contents":{…}}`) — скрипт берёт его (`cost_src:"api"`), при отсутствии считает по таблице (`cost_src:"fixed"`).

## `POST /search`

Тело (все поля кроме `query` — только когда задача явно требует; «оверспецификация — главная ошибка интеграции»):

| Поле | Значение |
|---|---|
| `query` | натуральная фраза-описание целевой страницы (правила — `exa-rules.md`) |
| `type` | `auto` (default, ~1 с) · `fast` (~450 мс) · `instant` (~250 мс) · `deep-lite` · `deep` · `deep-reasoning`. Legacy `keyword` / `neural` в enum доков нет, но на проводе живы (см. матрицу) |
| `numResults` | default 10, 1–100 по докам; «никогда >25» (best practices); скрипт режет >25 |
| `category` | `company` · `people` · `publication` · `news` · `personal site` · `financial report`. `company`/`people` **не поддерживают** `startPublishedDate`/`endPublishedDate`/`excludeDomains` → 400; `people` в `includeDomains` принимает только LinkedIn-домены |
| `includeDomains` / `excludeDomains` | string[], домены/пути/wildcard, ≤1200 |
| `startPublishedDate` / `endPublishedDate` | ISO 8601 (`YYYY-MM-DD` принимается) |
| `userLocation` | ISO-код страны (`US`, `PL`) |
| `includeText` / `excludeText` | string[], одна строка ≤5 слов (есть на проводе, в таблице доков нет) |
| `additionalQueries`, `systemPrompt`, `outputSchema`, `stream`, `moderation` | deep-варианты / синтез; в скрипте — через `--json-patch` |
| `contents.highlights` | `true` или `{query, maxCharacters}` — **дефолт для агентов** (×10 меньше токенов, без задержки) |
| `contents.text` | `true` или `{maxCharacters, verbosity: compact\|standard\|full, includeSections/excludeSections}` |
| `contents.summary` | `true` или `{query, schema}` — +$0.001/стр. |
| `contents.maxAgeHours` | свежесть **краула**, не публикации: omit = кэш с фоллбэком на live; `0` = всегда live; `-1` = только кэш (быстрее всего) |
| `contents.livecrawlTimeout` | default 10000 мс; с `maxAgeHours` ставить 12000–15000 |
| `contents.subpages` / `subpageTarget` | подстраницы на результат (0 default) + ключевые слова для их отбора |
| `contents.extras.links` / `imageLinks` | сколько ссылок/картинок вытащить |

Мёртвые поля (не слать): `useAutoprompt`, `numSentences`, `highlightsPerUrl`, `livecrawl`, `includeUrls`/`excludeUrls`, `startCrawlDate`/`endCrawlDate` (молча игнорируются с 15.04.2026), `tokensNum` (только `/context`).

Ответ: `requestId`, `searchType`/`resolvedSearchType` (живьём — пустая строка, ненадёжно), `searchTime` (мс), `results[]` = `{id,url,title,publishedDate,author,image,favicon,score?,text?,highlights[],highlightScores[],summary?,subpages[],extras}`, `statuses[]`, `output.{content,grounding[]}` (deep), `costDollars`.
Ошибки: 400 (невалидный фильтр/категория), 401 (ключ), 422 (валидация), 429, 500.

## `POST /contents`

`{"urls":[…], "text"|"highlights"|"summary": true|{…}, "maxAgeHours", "livecrawlTimeout", "subpages", "subpageTarget", "extras"}` — **`text/highlights/summary` здесь верхнего уровня**, не в `contents`.
Ответ: `results[]` (как у search + `text`/`subpages[]`) и `statuses[]` = `{id, status: success|error, error:{tag,httpStatusCode}}` — **HTTP 200 ≠ все URL успешны**. Теги: `CRAWL_NOT_FOUND` (404), `CRAWL_TIMEOUT`/`CRAWL_LIVECRAWL_TIMEOUT` (504), `SOURCE_NOT_AVAILABLE` (403), `UNSUPPORTED_URL`, `CRAWL_UNKNOWN_ERROR`.
Рецепт доков для документации: `{"urls":["https://platform.openai.com/docs"],"subpages":15,"subpageTarget":["api","models"],"maxAgeHours":24,"livecrawlTimeout":15000,"text":{"maxCharacters":5000}}` — «начинать с 5–10 подстраниц».

## `POST /context` (Exa Code)

`{"query": "1–2000 симв.", "tokensNum": "dynamic" | 50..100000}` (5000 — хороший дефолт, 10000 если мало). Ищет по GitHub/докам/StackOverflow. Ответ: `response` (markdown-блоб, **не** список), `resultsCount`, `outputTokens`, `costDollars`, `searchTime`. MCP-тул `get_code_context_exa` deprecated.

## Remote MCP `https://mcp.exa.ai/mcp`

- Ключ: заголовок `x-api-key` (в `~/.claude.json` — `"headers":{"x-api-key":"${EXA_API_KEY}"}`); без ключа — анонимный rate-limited режим.
- `?tools=a,b,c` **заменяет** дефолтный набор (дефолт — только `web_search_exa`, `web_fetch_exa`). Наш URL: `?tools=web_search_exa,web_fetch_exa,web_search_advanced_exa,agent_run` → живьём `tools/list` отдаёт ровно эти 4.
- `web_search_exa(query, numResults)` — категорию можно вшить в текст: `category:people John Doe`. `web_fetch_exa(urls, maxCharacters=3000)`. `web_search_advanced_exa` — type только `auto|fast|instant`, полные фильтры, `contextMaxCharacters` (недокументированный `contents.context`). `agent_run(query, effort=low default, outputSchema, systemPrompt, input, dataSources, runId/previousRunId)` — единственный тул, требующий ключа; при >750 с возвращает `status:"running"` + id.
- Плагин `exa@claude-plugins-official` несёт скилл с именем `search` (субагентный оркестратор на haiku) — коллизия с нашим `/search`, **не ставить**.

## Живая матрица 24–25.08.2026 (все HTTP 200, ключ пользователя)

| Вызов | Результат |
|---|---|
| `/search` `auto`, n=3, highlights+summary(query) | 3,4 с, `costDollars.total` **$0.01** = $0.007 + 3×$0.001 summary |
| RU-запрос «пробиотики при акне клинические исследования штаммы», `fast`, n=5 | 0,91 с (searchTime 657 мс), $0.007 (`search.neural`); выдача **англоязычная** — PMC ×3, Springer, PubMed (кросс-язычный семантический поиск) |
| тот же, `keyword` | 1,29 с (searchTime 1010 мс), $0.007 (`search.keyword`); выдача **русская** — pcr.news, instagram reel, interferons.info, science.mail.ru, maxiflor.ru |
| тот же, `neural` | searchTime 204 мс, $0.007; русская, но шумнее — PDF cassara.com.ar, ichgcp.net (реестр КИ), cyberleninka, zacofalk.ru PDF |
| `instant`, n=20, highlights | $0.017 (= 0.007 + 10×0.001), searchTime 268 мс, стенка 1,47 с; поля результата: `author, favicon, highlights, id, image, publishedDate, title, url` |
| `/context` «python urllib POST json…», tokensNum 800 | resultsCount 10, outputTokens 778, $0.007, 1,07 с |
| `mcp.exa.ai/mcp` `initialize` без ключа | 200 |
| `tools/list` с `x-api-key` и `?tools=…` | ровно 4 тула, схемы как в реестре |

Вывод для RU: `auto`/`fast` уводят в англоязычные источники (для науки — плюс), для Рунета нужен `--type keyword` (или `/yandex-search`); `neural` — компромисс с шумом. `resolvedSearchType` приходит пустым.

## Расхождения доков и провода

- Enum `type` в докax/валидаторе: `auto|fast|instant|deep-lite|deep|deep-reasoning`; `keyword` и `neural` приняты живьём (legacy) — могут отключить без предупреждения: дефолт `auto`, реальный `type` пишется в лог, `selftest.sh --live` ловит 400.
- Скилл `exa-search` ещё называет категорию `research paper`; актуальная — `publication`. MCP-enum `web_search_advanced_exa` принимает `pdf`/`github` — deprecated на сервере.
- Changelog апреля 2026: `resolvedSearchType`, `highlightScores` «удалены 1 мая» — в ответах присутствуют, доверять нельзя.
- `search-best-practices` разрешает совмещать `text`+`highlights`; `build-with-exa`/`common-mistakes` — «ровно один» (биллинг ×2). Скрипт следует строгому правилу.
- `numResults` max: доки 100, TS SDK «10 для basic», enterprise 1000 — при переборе `INVALID_NUM_RESULTS`/`NUM_RESULTS_EXCEEDED`.
- CLI `exa` не существует; единственный бинарь — `exa-mcp-server` (stdio). SDK: `pip install exa-py` (`search()` по умолчанию тянет text 10 000 симв. — `contents=False`), `npm i exa-js`.
