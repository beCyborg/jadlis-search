# A/B-лог Exa vs Brave — схема, вердикты, отчёт

Файл: `~/.claude/telemetry/search-ab/events.jsonl` (append-only; одна строка = один `os.write` в `O_APPEND`, ≤4096 байт; битые строки `report` считает и пропускает). Пишет только `scripts/websearch.py`; прямые вызовы `mcp__exa__*` / `mcp__brave-search__*` в лог **не попадают** — поэтому в окне A/B сравнимые запросы идут только через скрипт.

Окно A/B: **25.08–07.09.2026**. Итог — `/search-ab` (= `websearch.py report --since 14d` + интерпретация) → решение о дефолтном движке по каждому `tag`.

## Записи

### `kind:"call"` — один вызов одного движка

| Поле | Значение |
|---|---|
| `ts` | локальное ISO-время с оффсетом (`2026-08-25T00:41:12+02:00`); день для дневного капа = `ts[:10]` |
| `pair_id` | 8 hex — общий у двух записей команды `both`; `null` у одиночных |
| `host_cmd` | команда CLI: `exa` · `brave` · `both` · `contents` · `context` |
| `engine` | `exa` · `brave` |
| `cmd` | путь API: `search` · `contents` · `context` (Exa); `web` · `context` (Brave = `web/search` · `llm/context`) |
| `mode` | Exa: реально отправленный `type` (`auto`, `keyword`…); Brave: `web` / `context` |
| `query` | текст запроса (≤300 симв.); для `contents` — первый URL + `(+N)` |
| `lang` | `ru` (доля кириллицы среди букв ≥0.3) · `en` (≤0.1) · `mixed` |
| `tag` | интент: `research` · `sources` · `news` · `code` · `people` · `company` · `product` · `other` |
| `n_req` / `n_res` | запрошено / получено результатов |
| `latency_ms` | стенка от отправки до разбора ответа |
| `cost_usd` | стоимость вызова |
| `cost_src` | `api` (Exa `costDollars.total`) · `fixed` (Brave web $0.005 — подтверждено чеком #2482-5413 «Search (per request) $0.005 each»; Exa без `costDollars` — по таблице) · `assumed` (Brave `llm/context` $0.005 — чеком не подтверждено) |
| `http` | HTTP-код (0 = сеть/таймаут) |
| `top_urls` | первые 5 URL |
| `top_domains` | первые 5 уникальных доменов (без `www.`) — по ним считается overlap |
| `err` | `null` или `HTTP 403 SUBSCRIPTION_TOKEN_DEACTIVATED: …` (≤200 симв.); `timeout` |
| `degraded` | `true` у обеих записей пары, если один из движков упал |

### `kind:"verdict"` — суждение модели по паре

| Поле | Значение |
|---|---|
| `ts`, `pair_id` | как выше |
| `winner` | `exa` · `brave` · `tie` |
| `why` | `relevance` (точнее по смыслу) · `freshness` (свежее) · `coverage` (шире/уникальные источники) · `lang` (правильный язык выдачи) · `noise` (меньше мусора) |
| `note` | свободный текст ≤300 симв. |

Несколько вердиктов на пару → `report` берёт последний. Вердикт по `degraded`-паре записывается с `[warn]`, но в сравнимые не входит.

## Правила вердикта (для модели)

1. Вердикт ставится **после синтеза ответа** — когда видно, какие результаты реально пошли в ответ.
2. `winner` — чей top-5 дал больше пользы **для этого интента**; `why` — главная причина, одна.
3. `tie` — когда оба дали одинаково полезный набор или оба мимо. Не ставить `tie` из вежливости — это шум для win-rate.
4. `lang` как `why` — когда один движок ответил не на том языке (типично: Exa `auto` на RU-запрос → английские источники).
5. Пара `degraded` (`── PAIR DEGRADED`) — вердикт не нужен.
6. Команда печатается последней строкой вывода `both`: `websearch.py verdict <pair_id> exa|brave|tie --why … [--note "…"]`.

## Дневной софт-кап

Сумма `cost_usd` за сегодня (`ts[:10]`) ≥ **$2** → `exit 1` до сетевого вызова с подсказкой `--force`. Считаются оба движка. Фан-аут >5 пар — спросить пользователя до запуска.

## Как читать `report`

```
websearch.py report [--since 14d|YYYY-MM-DD] [--out md|json]
```

- **Шапка:** период; пар всего / сравнимых (обе записи ok, не degraded) / с вердиктом (%); расход по движкам.
- **Движки:** строки `engine/mode` — calls, err %, p50/p90 latency, $ total, $/call. Один и тот же запрос в паре → латентность сравнима напрямую.
- **Win-rate по tag и по lang:** `exa W / brave W / tie`, доля Exa среди решённых (без tie) и **нижняя граница Вильсона 95 %** — на неё и смотреть: LB > 0.5 = Exa устойчиво лучше в срезе, LB < 0.5 при доле < 0.5 — Brave. Ячейка с n<10 вердиктов → «мало данных».
- **winner × why:** за что именно побеждают — `lang`/`noise` у Brave при RU означает «дефолт Exa — `keyword`», а не «Exa хуже».
- **Overlap top-5:** средняя доля общих доменов в top-5 (k/5). Низкий overlap + высокий win-rate одного движка = движки дополняют друг друга → `both` останется полезным и после окна.
- **Уникальные домены:** что видит только один движок (top-10 по частоте) — сигнал о покрытии (Exa: personal sites/publications; Brave: новости/форумы).
- **Порог решения:** сравнимых пар <20 → отчёт печатает «победителя не называем»; решение о дефолте по tag — только при n≥10 вердиктов в ячейке и LB, отличной от 0.5.

## Пример строк

```json
{"kind":"call","ts":"2026-08-25T00:41:12+02:00","pair_id":"3f9a1c2e","host_cmd":"both","engine":"exa","cmd":"search","mode":"auto","query":"exa vs brave neural search","lang":"en","tag":"research","n_req":8,"n_res":8,"latency_ms":912,"cost_usd":0.007,"cost_src":"api","http":200,"top_urls":["https://…"],"top_domains":["exa.ai","brave.com"],"err":null,"degraded":false}
{"kind":"verdict","ts":"2026-08-25T00:43:02+02:00","pair_id":"3f9a1c2e","winner":"exa","why":"relevance","note":"Brave дал маркетинг, Exa — сравнения практиков"}
```
