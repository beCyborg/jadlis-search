# Changelog — jadlis-search

Формат: [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), версии — [SemVer](https://semver.org/lang/ru/).
История до 1.0.0 — плагин `jadlis-research` 1.0.0–1.3.0 в репо [jadlis-hub](https://github.com/beCyborg/jadlis-hub) (`plugins/jadlis-research/CHANGELOG.md` до split).

## [Unreleased]

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
