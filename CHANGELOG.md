# Changelog — jadlis-search

Формат: [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), версии — [SemVer](https://semver.org/lang/ru/).
История до 1.0.0 — плагин `jadlis-research` 1.0.0–1.3.0 в репо [jadlis-hub](https://github.com/beCyborg/jadlis-hub) (`plugins/jadlis-research/CHANGELOG.md` до split).

## [Unreleased]

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
