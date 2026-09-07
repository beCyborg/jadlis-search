# Changelog — search

Формат: [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), версии — [SemVer](https://semver.org/lang/ru/).
История до 1.0.0 — плагин `jadlis-research` 1.0.0–1.3.0 в репо [jadlis-start](https://github.com/beCyborg/jadlis-start) (`plugins/jadlis-research/CHANGELOG.md` до split).

## [Unreleased]

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
