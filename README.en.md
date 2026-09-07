[Русский](README.md) · English

# search — Claude Code plugin

Command: `/search`.

## Было → стало

To be written (README contract 2026-09, phase 3).

## Как это работает

Поиск в вебе (Brave — по словам, Exa — по смыслу) и страницы через Firecrawl, плюс пять MCP-серверов и единая точка ключей (scripts/secret.sh → Связка ключей macOS). База для плагинов research и science-research.

## Установка и первый запуск

```bash
claude plugin marketplace add https://github.com/beCyborg/jadlis-start.git
claude plugin install search@jadlis --config BRAVE_API_KEY=… --config FIRECRAWL_API_KEY=…
```

## Границы, стоимость, обновление

```bash
claude plugin marketplace update jadlis
claude plugin update search@jadlis
claude plugin list
```
