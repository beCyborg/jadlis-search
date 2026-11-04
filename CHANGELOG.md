# Changelog — jadlis-search

Формат: [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), версии — [SemVer](https://semver.org/lang/ru/).
История до 1.0.0 — плагин `jadlis-research` 1.0.0–1.3.0 в репо [jadlis-hub](https://github.com/beCyborg/jadlis-hub) (`plugins/jadlis-research/CHANGELOG.md` до split).

## [Unreleased]

## [2.4.0] — 2026-11-04 — Jina с ключом: скрипт jina-read.sh / Jina with a key: jina-read.sh

### Для человека

- Текст страницы через Jina теперь идёт скриптом `jina-read.sh`. Он сам берёт ключ `JINA_API_KEY` из Связки ключей: лимит 500 запросов в минуту вместо ~20 без ключа, поэтому параллельные агенты больше не упираются в 429.
- Если Jina или сам сайт отказал (в том числе когда Jina отвечает «200», а внутри «Target URL returned error 403/404»), скрипт выходит с кодом 3, и лестница идёт дальше, в Firecrawl.
- Бесплатный ключ Jina — только для некоммерческого использования; страница стоит 2–10 тыс. токенов, 10 млн бесплатных токенов ≈ 1 000 страниц.

### For agents

- Added: `scripts/jina-read.sh <url> [--timeout SEC]` — key via `secret.sh` (env → Keychain), one retry on 429 (Retry-After ≤ 10 s, else 4 s), keyless retry on 401/402 with a hint, exit 3 on non-2xx, an empty body or a `Warning: Target URL returned error 4xx/5xx` body; stderr `[jina] key|keyless http=… tokens=…`.
- Changed: `skills/search/SKILL.md` ladder step 2 uses the script.
- Changed: `.claude-plugin/plugin.json` version 2.3.2 → 2.4.0.

## [2.3.2] — 2026-11-04 — Bright Data повторяет пустую выдачу / Bright Data retries an empty page

### Для человека

- Если Bright Data вернул пустую страницу или страницу без выдачи Яндекса, скрипт сам повторяет запрос (до двух раз). 04.11 такой сбой случился на живом запросе, повтор вручную сразу дал 10 результатов.

### For agents

- Fixed: `scripts/yandex-bd.py` `fetch()` treats a body without `serp-item` as a retryable failure; `--retries` default 1 → 2; test `test_fetch_retries_empty_page`.
- Changed: `.claude-plugin/plugin.json` version 2.3.1 → 2.3.2.

## [2.3.1] — 2026-11-04 — Яндекс сразу через Bright Data, пока API недоступен / Yandex goes straight to Bright Data while the API is down

### Для человека

- Если Yandex Search API ответил 401/402/403 (биллинг приостановлен, нет роли или ключа), скрипт 6 часов не стучится в API и сразу идёт в Bright Data. Раньше каждый запрос сначала получал 403 и писал ошибку в журнал. Решение владельца 04.11: пока платить за Yandex Cloud нечем, Рунет идёт через Bright Data.
- Запросы к Bright Data можно гонять параллельно: два запроса вместе — 96 с.

### For agents

- Added: `scripts/yandex-search.sh` writes `~/.cache/jadlis-search/yandex-api-down` on 401/402/403 (`JADLIS_SEARCH_STOP_DIR` overrides the dir); under `YANDEX_BACKEND=auto` with a Bright Data key, a fresh mark (< 6 h) hands the query to `yandex-bd.py` before any API call; delete the mark to retry the API.
- Changed: `.claude-plugin/plugin.json` version 2.3.0 → 2.3.1.

## [2.3.0] — 2026-11-04 — Exa lite по умолчанию, новая лестница текста, запасные бэкенды X и Яндекса / Exa lite default, new page-text ladder, fallback backends for X and Yandex

### Для человека

- Поиск по умолчанию теперь идёт через Exa типа `lite`. Слепой тест на 50 реальных запросах за три месяца (два судьи, Opus и Codex): `lite` равен `auto` по качеству, оба лучше Brave, а `lite` на 43 % дешевле. Brave остаётся для свежих новостей.
- Треды Hacker News и Substack ищутся через Exa с фильтром домена. Reddit Exa не индексирует, поэтому треды Reddit ищутся через Brave `site:reddit.com`.
- Полный текст страницы снимается по лестнице pdf-fetch → r.jina.ai → Firecrawl с новым гейтом. Он отбраковывает base64-заглушки, чужой язык, страницы блокировки и тела без нужной цитаты. На 60 реальных страницах — 57 из 57; прежняя лестница давала 54 и дважды молча брала пустышку.
- Если сервис ответил 402 (кончились деньги или лимит), скрипт поиска 15 минут не шлёт туда запросы. 30.10 было 888 вызовов Brave за час после такого ответа.
- X: у `twitterapi.sh` появился второй бэкенд — TwittrAPI ($0,0001 за вызов). Он включается сам, когда у TwitterAPI.io кончится баланс.
- Яндекс: днём скрипт ходит синхронно (асинхронный режим Яндекс теперь принимает только с 00:00 до 06:00 МСК). Если API отвечает 401/402/403, запрос уходит в Bright Data SERP (новый `yandex-bd.py`, тот же вывод).
- Reddit выключает RSS 13.11.2026: поиск через RSS убран, у комментариев Arctic Shift есть сжатый вид `--compact`.
- Hacker News: тред идёт в порядке сайта (10 из 10 лучших комментариев вместо 1–4), поиск больше не требует совпадения всех слов.
- Новый ключ, если хочешь: `TWITTRAPI_API_KEY`, `BRIGHTDATA_API_KEY` и `BRIGHTDATA_ZONE` — через `/jadlis-search:keys`. Без них всё работает как раньше.
- Репозиторий теперь живёт на GitHub: https://github.com/becyb-org/jadlis-search. GitLab остаётся копией и CI. Лицензия — Apache-2.0.

### For agents

- Changed: `scripts/websearch.py` — `lite` added to `EXA_TYPES` ($0.004) and is the default for `exa` and `both`; `http_json` retries HTTP 429 twice (Retry-After ≤ 5 s, else 1 s); HTTP 402 writes a per-host stop mark (`~/.cache/jadlis-search/stop-402-<host>`, `JADLIS_SEARCH_STOP_DIR`) and for 15 min returns 402 without a network call; Brave 422 with `country`/`search_lang` retries once without them; empty query dies before the paid call; Exa warns when `--include-domains` has reddit.com; missing-key hints point to the Keychain.
- Changed: `skills/search/SKILL.md` — routing per the 2026-11 audit (default exa lite, news → brave, HN/Substack → exa `--include-domains`, Reddit → brave `site:reddit.com`), page-text ladder and gate, 402 stop, `brave_llm_context` `maximum_number_of_tokens`; dead `/search-paper`, `/full-research` links fixed; `pdf-fetch.sh` via `${CLAUDE_PLUGIN_ROOT}`. References `exa-rules.md`, `exa-api.md` follow.
- Added: `scripts/twitterapi.sh` TwittrAPI backend (`TWITTER_BACKEND=auto|twittrapi|twitterapiio`, `format=simple`, stderr `backend=…`, fallback on 401/402/5xx); `balance` prints both backends.
- Added: `scripts/yandex-bd.py` (Bright Data SERP, raw yandex.ru HTML → yaparse-compatible output, timeout 180 s + 1 retry); `scripts/yandex-search.sh` `MODE=auto` (async 00:00–06:00 MSK, sync otherwise), `--async`, quota note 1 rps, `YANDEX_BACKEND=auto|yandex|brightdata` with fallback on 401/402/403 or a missing key.
- Changed: `scripts/reddit-archive.py` — `search` without `--sub` exits 2 and points to the MCP `reddit_search`; `--sub` uses Arctic Shift title search (`--fulltext` for bodies); `comments --compact [N]`; Arctic 422 «Timeout» retried.
- Changed: `scripts/hn-fetch.sh` — `thread` follows Firebase `kids` order (all top-level + ≤ 3 replies, `[id]` per line), `--full` keeps the old tree, Algolia down → ClickHouse Playground; `search` sets `optionalWords` (by-date: all words, auto-retry under 5 hits; `--all-words` opt-out).
- Changed: `scripts/substack-fetch.py` — custom domains in `<pub>`, `PAYWALL_PREVIEW` on `only_paid`; `scripts/yt-transcript.py` finds the jadlis-tldr venv in the active profile.
- Changed: `hooks/hooks.json` matcher adds `firecrawl_parse`; `block-pdf-firecrawl.py` denies a local PDF without `pdfOptions.maxPages ≤ 20`.
- Changed: `.mcp.json` pins `@brave/brave-search-mcp-server@2.1.4`, `firecrawl-mcp@3.25.3`, `redditapis-mcp@0.15.0`, `youtube-data-mcp-server@1.0.16`. Tool names unchanged.
- Changed: `scripts/secret.sh` knows `TWITTERAPI_IO_KEY`, `TWITTRAPI_API_KEY`, `JINA_API_KEY`, `BRIGHTDATA_API_KEY`, `BRIGHTDATA_ZONE`.
- Added: tests `test_websearch_retry_jadlis_search.py` (429, 402 stop/expiry), `test_yandex_bd_parse_jadlis_search.py`; evals `route-company-exa-lite`, `route-news-brave`.
- Changed: `plugin.json` version 2.2.4 → 2.3.0, `license` Apache-2.0 (+ `LICENSE`), `homepage`/`repository` → GitHub becyb-org.
- Note: jadlis-research and jadlis-science-research vendor `scripts/` — re-vendor (`tools/sync-shared.sh jadlis-search--v2.3.0`).

## [2.2.4] — 2026-10-19 — дневной лимит поиска настраивается и выключается / daily search cap is configurable and can be turned off

### Для человека

- Дневной лимит расходов на поиск ($2 в день) теперь можно поменять или выключить переменной `JADLIS_SEARCH_DAILY_CAP_USD`. `0` или `off` выключает лимит, число задаёт свой лимит в долларах. Без переменной всё как раньше: $2 в день и `--force` для обхода.

### For agents

- Added: `scripts/websearch.py` `_daily_cap()` reads `JADLIS_SEARCH_DAILY_CAP_USD` (`0`/`0.0`/`off`/`none` → no cap; a number → that cap in USD; empty or unparsable → 2.0). `check_cap()` returns early when the cap is 0 (no block, no 75 % warning). `--force` help mentions the variable.
- Changed: `skills/search/SKILL.md` rate-limits line names the variable.
- Changed: `.claude-plugin/plugin.json` version 2.2.3 → 2.2.4.
- Note: `jadlis-research` vendors `scripts/websearch.py` — re-vendor to pick up the variable.

## [2.2.3] — 2026-10-12 — транскрипт YouTube на языке видео, русские запросы в Exa через auto / YouTube transcript in the video's language, Russian Exa queries via auto

### Для человека

- Транскрипт YouTube теперь приходит на языке, на котором говорят в видео. Раньше у видео с авто-дубляжом скрипт брал первую дорожку по алфавиту, поэтому англоязычное видео приходило арабским текстом. Так было в 13 из 23 прогонов канала youtube с 24.09.
- Если старого плагина youtube-tldr нет, скрипт молча идёт сразу через yt-dlp. В тексте ошибки теперь сказано «skipped (plugin not installed)», а не «n/a».
- `/search` больше не советует `--type keyword` для русских запросов в Exa. Слепой тест с двумя судьями: `auto` выиграл 14 : 0, у `keyword` меньше результатов, меньше русских страниц и они старее.
- Для запросов про людей, компании и продукты `/search` теперь берёт Exa первым: в том же тесте Exa выиграл у Brave 7 : 0 на английских запросах.

### For agents

- Fixed: `scripts/yt-transcript.py` `pick_track` returned `orig[0]` — the first `*-orig` key in `automatic_captions`. Auto-dubbing adds one `-orig` key per dubbed audio track (`Ajqub1jgsVM`: 21 keys, first `ar-orig`, `language: en-US`), and `--lang` did not help because the `-orig` branch ran before `by_pref`. New order after manual subs: `<info.language>-orig` (exact, then base `en-orig`, then a regional key with the same base like `de-DE-orig`) → if `language` is unknown and there is exactly one `-orig`, that one → `<--lang>-orig` → `--lang` among non-`-orig` auto keys → any auto key as before. A foreign `-orig` is never picked ahead of a requested-language track. Live check 2026-10-12: `Ajqub1jgsVM` → `en-orig` with and without `--lang ru`.
- Changed: `try_plugin` path to the youtube-tldr plugin is documented as optional; new `plugin_available()`; the final `blocked_or_network` message says `skipped (plugin not installed)` when the files are absent. Docstring no longer names `/search-community`.
- Added: `tests/test_yt_transcript_pick_track_jadlis_search.py` — dubbed video (fake `yt-dlp -J` info), `--lang ru` not pulling a dub, regional and exact regional `-orig`, unknown language, manual-first, no captions, silent skip of the missing plugin.
- Changed: `skills/search/SKILL.md` — RU rule is now `--type auto` (was `--type keyword`), quick-start RU example without `--type keyword`, new intent row «люди / компании / продукты → Exa первым», R3 summary line (blind test 2026-10, 48 queries, Claude Opus 5.5 + Codex judges: Exa-auto 27 : Brave 13; auto vs keyword on RU 14 : 0), description and Routing details updated. `references/exa-rules.md` § Русский язык, `references/exa-api.md` RU conclusion and `references/ab-log.md` interpretation note follow.
- Changed: `scripts/websearch.py` `--type` help (`exa`, `both`) says auto is the default for Russian queries too; the legacy-type warning now says to use `--type auto`. `skills/search/scripts/selftest.sh` live-row hint text updated.
- Changed: `.claude-plugin/plugin.json` version 2.2.2 → 2.2.3.
- Note: `jadlis-research` vendors `scripts/` — re-vendor `yt-transcript.py` and `websearch.py` there to pick up the fix.

## [2.2.2] — 2026-10-08 — репозиторий переехал на GitLab / repository moved to GitLab

### Для человека

- Плагин теперь живёт на GitLab: https://gitlab.com/beCyborg/jadlis-search. Аккаунт GitHub beCyborg заблокирован, поэтому старые ссылки открывают 404.
- Каталог ставится новой командой: `claude plugin marketplace add https://gitlab.com/beCyborg/jadlis-hub.git`. Если ты уже ставил его со старой ссылки GitHub, удали каталог командой `claude plugin marketplace remove jadlis` и поставь всё заново по README. Плагины этого каталога при удалении тоже снимутся, ключи для `jadlis-search` придётся ввести ещё раз.
- Работа плагина не изменилась.

### For agents

- Changed: every `github.com/beCyborg/*` link in README pairs now points to `gitlab.com/beCyborg/*`; `marketplace add` uses the full `https://…/jadlis-hub.git` URL (non-GitHub hosts have no `owner/repo` shorthand).
- Changed: `.claude-plugin/plugin.json` `homepage`/`repository` → GitLab; version 2.2.1 → 2.2.2.
- Changed: CI moved from `.github/workflows/ci.yml` (reusable workflow in `beCyborg/jadlis-hub`) to `.gitlab-ci.yml` including `/ci/plugin-ci.yml` from `beCyborg/jadlis-hub` on GitLab — same checks: `claude plugin validate --strict`, gitleaks full history, README parity, privacy grep.

## [2.2.1] — 2026-10-07 — поиск Brave в режиме context больше не падает / Brave context mode no longer crashes

### Для человека

- `websearch.py brave --mode context` снова печатает результаты. Раньше он падал с `TypeError` на любом запросе, где у источника была дата; обходом был только `--out json`.
- Дата у результатов Brave теперь всегда в виде `2025-01-08` или пустая.

### For agents

- Fixed: `norm_brave_ctx` sliced `sources[url].age` with `[:10]`, but Brave `llm/context` sends `age` as a list of four renderings (`["Wednesday, January 08, 2025", "2025-01-08", "636 days ago", "2025-01-08T13:37:18Z"]`) or `[]`; the list reached `render_results` and `" · " + list` raised `TypeError` (seen live 2026-10-07). New `brave_date()` takes the first `YYYY-MM-DD` string from a string or a list; `norm_brave_web` uses it too, so a relative `age` like `"2 days ago"` now gives `""` instead of the cut `"2 days ag"`.
- Added: `tests/test_websearch_brave_dates_jadlis_search.py` — list / empty list / string `age`, missing source, render without crash.
- Changed: `.claude-plugin/plugin.json` version 2.2.0 → 2.2.1.

## [2.2.0] — 2026-10-02 — общий MCP-сервер вместо копии в каждой сессии / shared MCP server instead of a copy per session

### Для человека

- Можно не запускать четыре MCP-сервера (Brave, Firecrawl, Reddit redditapis, YouTube) заново в каждой сессии Claude Code: в `/plugin configure jadlis-search@jadlis` появились поля «общий MCP-сервер» — адрес одного сервера на машину или на твой сервер. Сессия подключается к нему через лёгкий переходник (~17 МБ против ~290 МБ у полного сервера на сессию, замер 02.10.2026).
- Поля пустые — всё работает как раньше, ничего делать не нужно.
- Для серверов с авторизацией есть поле токена; оно уезжает в Связку ключей.

### For agents

- Added: `scripts/mcp-run` (POSIX sh launcher; empty `JADLIS_MCP_URL` → `exec` the stdio package from args, set → `exec python3 scripts/mcp-relay.py`) and `scripts/mcp-relay.py` (stdlib-only stdio↔Streamable HTTP relay, Python ≥3.9; bearer from `JADLIS_MCP_BEARER` env, not argv; on 404 after a daemon restart replays the cached initialize once and retries; JSON and SSE replies; no GET-stream server notifications).
- Changed: `.mcp.json` — `brave-search`, `firecrawl`, `reddit-alt`, `youtube` now start via `${CLAUDE_PLUGIN_ROOT}/scripts/mcp-run`; server keys unchanged, so tool names `mcp__plugin_jadlis-search_<server>__*` stay the same. `reddit` (hosted `https://mcp.dialog.tools/mcp`) unchanged.
- Added: `userConfig` `brave_mcp_url`, `firecrawl_mcp_url`, `reddit_alt_mcp_url`, `youtube_mcp_url` (string, default `""`) and `shared_mcp_token` (sensitive, default `""`).
- Added: `tests/test_mcp_relay_jadlis_search.py` — round-trip (JSON + SSE) and restart recovery against a fake daemon.
- Why: the personal build pointed `.mcp.json` at localhost daemons on a separate branch (`local-http`) that needed a manual rebase on every release; Claude Code cannot switch a plugin server's transport by variable (`mcp.md:625-633` — no expansion in `type`), so the switch lives in the launcher. Measured 02.10.2026 on brave: full `npx` server tree 290–298 MB / 2 procs, relay 16–27 MB / 1 proc, `mcp-remote` 350 MB.
- Changed: `.claude-plugin/plugin.json` version 2.1.1 → 2.2.0 (dependents require `^2`).

## [2.1.1] — 2026-09-30

### Для человека

- Хук, который не пускает Firecrawl на x.com/twitter.com, больше не отсылает к каналу Grok (Grok отключён с 14.09.2026): для твитов и тредов он теперь предлагает `scripts/twitterapi.sh` (TwitterAPI.io). Тексты отказов хука — на английском.

### For agents

- `hooks/block-pdf-firecrawl.py`: deny reasons rewritten in English; the x.com/twitter.com reason now points to `${CLAUDE_PLUGIN_ROOT}/scripts/twitterapi.sh` (new `TWITTERAPI` constant, resolved like `PDF_FETCH`) instead of «канал twitter (Grok x_*)». Matching logic unchanged.
- `.claude-plugin/plugin.json`: `version` → 2.1.1 (PATCH: message text only).

## [2.1.0] — 2026-09-10

### Для человека

- В диалоге установки появилось необязательное поле `FIRECRAWL_API_URL` — адрес Firecrawl API. По умолчанию официальный `https://api.firecrawl.dev`, поведение у тех, кто ничего не вводит, не меняется. Нужно только тем, кто держит свой прокси или ротатор ключей Firecrawl: вводится при установке `--config FIRECRAWL_API_URL=http://…` или позже через `/plugin configure jadlis-search@jadlis`.

### For agents

- `.claude-plugin/plugin.json`: new `userConfig.FIRECRAWL_API_URL` (`type: string`, `required: false`, `sensitive: false`, `default: "https://api.firecrawl.dev"`); `version` → 2.1.0 (MINOR: additive, backwards compatible).
- `.mcp.json`: `firecrawl.env.FIRECRAWL_API_URL = "${user_config.FIRECRAWL_API_URL}"` — `firecrawl-mcp` reads the base URL from that env var.
- README RU/EN: one sentence about the field in «Границы, стоимость, обновление» / «Limits, cost, updating».

## [2.0.0] — 2026-09-10

### Для человека

- Плагин переименован: `search` → `jadlis-search`. Ставится теперь строкой `claude plugin install jadlis-search@jadlis`, маркетплейс добавляется из хаба — `claude plugin marketplace add https://github.com/beCyborg/jadlis-hub`. Обновление и снятие — тем же новым именем (`claude plugin update jadlis-search@jadlis`, `claude plugin uninstall jadlis-search@jadlis --keep-data`), диалог ключей — `/plugin configure jadlis-search@jadlis`.
- Короткая команда `/search` не изменилась. Полная форма второй команды стала `/jadlis-search:keys` вместо `/search:keys`.
- Совместимости со старым именем нет: внешних установок не было, псевдонимов и обёрток не заводили. Если плагин уже стоял под именем `search` — сними его и поставь заново под новым.
- В README (RU и EN) закрыты две заглушки: сказано, что минимальные версии бинарников не фиксируются — плагин проверяет только их наличие (`jq`, `uv`, `pdftotext` из poppler, опционально `yt-dlp`), и что проверено всё на macOS, на Linux должно работать с теми же бинарниками в PATH, Windows не проверялся.

### For agents

- `.claude-plugin/plugin.json`: `name` → `jadlis-search`, `version` → 2.0.0. MAJOR bump: the plugin id is part of the public interface.
- MCP tool namespace changed with the plugin name: `mcp__plugin_search_*` → `mcp__plugin_jadlis-search_*`. The `PreToolUse` matcher in `hooks/hooks.json` and every tool name in `skills/` and `scripts/` were updated; server names in `.mcp.json` are unchanged (the prefix is derived from the plugin name at runtime).
- `scripts/secret.sh`: `PLUGIN_ID_DEFAULT` → `jadlis-search@jadlis`, `PLUGIN_ID_PREFIX` → `jadlis-search@`. Keys already written to the Keychain under `service jadlis` are unaffected; class-A secrets stored by Claude Code under the old plugin id `search@<marketplace>` will no longer resolve — re-enter them once.
- Skill frontmatter `name:` stays bare (`search`, `keys`), skill folders are not renamed. Release tag prefix is now `jadlis-search--vX.Y.Z`.
- CI already calls `beCyborg/jadlis-hub/.github/workflows/plugin-ci.yml@main`.

## [1.0.1] — 2026-09-07

### Для человека

- Из `/search:keys` убран шаг, разворачивавший homes верификаторов: он копировал шаблоны из `assets/verif-homes`, которого в этом репозитории нет — каталог принадлежит плагину `verif`, и шаг падал на `cp`. Свои homes `verif` разворачивает сам при первом запуске. Оставшиеся шаги перенумерованы: smoke-проверка теперь шестая, финал — седьмой.

### For agents

- Removed step 6 of `skills/keys/SKILL.md` and the `HOMES`/`TEMPLATES` constants. Beyond the missing `assets/`, `${CLAUDE_PLUGIN_DATA}` is per-plugin, so anything written there by `search` would never be read by `verif`. Leftover from the 1.0.0 split of `jadlis-research` 1.3.0.

## [1.0.0] — 2026-09-07

### Для человека

- Первый релиз под именем `search`: выделен из `jadlis-research` 1.3.0 (репо на плагин, команда `/search`).

### For agents

- Split of `jadlis-research` 1.3.0 by `tools/split-research.py` (hub). Namespaces: MCP tools `mcp__plugin_search_*`, agents `—:*`, commands `/search`, `/search:keys`, `/research`, `/science-research`, `/verif`.
