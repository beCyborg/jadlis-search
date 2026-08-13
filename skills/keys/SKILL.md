---
name: keys
description: "Настройка ключей ресерч-стека: пишет научные ключи в блок env файла ~/.claude/settings.json, разворачивает рабочие homes верификаторов, ставит симлинки auth.json и гоняет smoke-проверку по каждому источнику с таблицей PASS/FAIL.\nTRIGGER when: user says \"настрой ключи\", \"ключи ресерча\", \"проверь ключи\", \"keys\", \"/jadlis-research:keys\", \"research keys\", \"почему PubMed не отвечает\", \"смоук источников\", or has just installed jadlis-research and needs configuration.\nDO NOT TRIGGER when: обычный поиск (use /jadlis-research:search), настройка Brave/Firecrawl (они спрашиваются плагином при включении, не здесь)."
allowed-tools: Read, Edit, Write, Bash, AskUserQuestion
argument-hint: "[--check — только проверка, без записи]"
---

# /jadlis-research:keys — ключи ресерч-стека и smoke-проверка

`$ARGUMENTS`

Ставит **рельсу B**: ключи, которые подставляются в `curl` внутри протоколов. Они не могут
жить в `userConfig` плагина — сенситивные значения плагина до обычных Bash-вызовов не
долетают (уезжают только в MCP/LSP-конфиги и хук-процессы). Поэтому им место в блоке `env`
файла `~/.claude/settings.json`.

**Рельса A** (`VAULT_PATH`, `BRAVE_API_KEY`, `FIRECRAWL_API_KEY`) этим скиллом не трогается —
их Claude Code спрашивает сам при включении плагина.

> [!warning] Значения ключей не печатать
> Ни в ответе пользователю, ни в эхо Bash, ни в сообщении об ошибке. Максимум — имя
> переменной и длина значения. Один вывод ключа в транскрипт = ключ скомпрометирован.

## Константы

```
SETTINGS   = ~/.claude/settings.json
HOMES      = ${CLAUDE_PLUGIN_DATA}/verif-homes
TEMPLATES  = ${CLAUDE_PLUGIN_ROOT}/assets/verif-homes
```

## Шаг 1 — что уже есть

Один Bash-вызов. Показывает **только имена и длины**, не значения:

```bash
S="$HOME/.claude/settings.json"
[ -f "$S" ] || { mkdir -p "$HOME/.claude"; echo '{}' > "$S"; echo "СОЗДАН пустой settings.json"; }
for K in PUBMED_API_KEY PUBMED_EMAIL SEMANTIC_SCHOLAR_API_KEY OPENALEX_API_KEY OPENALEX_MAILTO \
         CROSSREF_MAILTO UNPAYWALL_EMAIL CORE_API_KEY SCITE_API_KEY CONSENSUS_API_KEY \
         YC_SEARCH_API_KEY; do
  V=$(jq -r --arg k "$K" '.env[$k] // ""' "$S")
  if [ -n "$V" ]; then printf '%-26s ЕСТЬ (длина %s)\n' "$K" "${#V}"; else printf '%-26s НЕТ\n' "$K"; fi
done
```

Разделение на обязательные и опциональные:

| Обязательные | Опциональные (модули включаются, только если ключ есть) |
|---|---|
| `PUBMED_API_KEY`, `PUBMED_EMAIL`, `SEMANTIC_SCHOLAR_API_KEY`, `OPENALEX_API_KEY`, `OPENALEX_MAILTO`, `CROSSREF_MAILTO`, `UNPAYWALL_EMAIL` | `CORE_API_KEY`, `SCITE_API_KEY`, `CONSENSUS_API_KEY`, `YC_SEARCH_API_KEY` |

`YC_SEARCH_API_KEY` — только для opt-in канала `yandex` в `/jadlis-research:full-research`
(поиск по Рунету, платный ≈0,1-0,15 ₽/тема). Без него канал не предлагается и, если всё-таки
выбран, деградирует (`exit 2`, `sourceQuality=LOW`) — остальной ресерч работает как обычно.

## Шаг 2 — где взять недостающее

Покажи таблицу **только по тем, которых нет**:

| Переменная | Где завести |
|---|---|
| `PUBMED_API_KEY`, `PUBMED_EMAIL` | https://www.ncbi.nlm.nih.gov/account/settings/ → API Key Management |
| `SEMANTIC_SCHOLAR_API_KEY` | https://www.semanticscholar.org/product/api |
| `OPENALEX_API_KEY`, `OPENALEX_MAILTO` | https://openalex.org (freemium dashboard) |
| `CROSSREF_MAILTO` | регистрации нет — своя почта для polite pool |
| `UNPAYWALL_EMAIL` | регистрации нет — своя почта в параметре `email=` |
| `CORE_API_KEY` | https://core.ac.uk/services/api |
| `YC_SEARCH_API_KEY` | https://console.yandex.cloud → сервисный аккаунт с ролью `search-api.webSearch.user` → создать **Api-Key** (не IAM-токен) |

`*_MAILTO` и `*_EMAIL` — контактные почты пользователя, не ключи: по ним API узнают, кто
стучится, и пускают в вежливый пул. Одна и та же почта во всех трёх — нормально.

## Шаг 3 — приём значений

Спроси значения **по одному**, обычным сообщением (не AskUserQuestion — там значение
попадёт в лейбл кнопки). Формулировка: «Пришли значение `PUBMED_API_KEY` одной строкой».

`--check` в аргументах → шаг 3 и 4 пропустить, идти сразу на шаг 5.

## Шаг 4 — запись в `env`

**Только `jq` c временным файлом, никогда `Edit` по живому `settings.json`** — файл может
одновременно писаться самим Claude Code, и ручная правка затрёт чужие изменения:

```bash
S="$HOME/.claude/settings.json"
NAME="PUBMED_API_KEY"
read -r VALUE   # значение приходит на stdin, в командную строку не попадает
T=$(mktemp)
jq --arg k "$NAME" --arg v "$VALUE" '.env = ((.env // {}) + {($k): $v})' "$S" > "$T" && mv "$T" "$S"
echo "OK: $NAME записан (длина ${#VALUE})"
```

Остальной `settings.json` сохраняется как есть — `jq` переписывает только ключ внутри `.env`.

После каждой записи печатай ровно `OK: <ИМЯ> записан (длина N)`. Значение — никогда.

## Шаг 5 — homes верификаторов и симлинки

```bash
HOMES="${CLAUDE_PLUGIN_DATA}/verif-homes"
TEMPLATES="${CLAUDE_PLUGIN_ROOT}/assets/verif-homes"
mkdir -p "$HOMES/codex-home" "$HOMES/grok-home"
for f in AGENTS.md config.toml; do
  [ -e "$HOMES/codex-home/$f" ] || cp "$TEMPLATES/codex-home/$f" "$HOMES/codex-home/$f"
  [ -e "$HOMES/grok-home/$f" ]  || cp "$TEMPLATES/grok-home/$f"  "$HOMES/grok-home/$f"
done
# auth.json — СИМЛИНКИ на твои логины, копий не делаем и в git они не попадают
[ -e "$HOMES/codex-home/auth.json" ] || ln -s "$HOME/.codex/auth.json" "$HOMES/codex-home/auth.json"
[ -e "$HOMES/grok-home/auth.json" ]  || ln -s "$HOME/.grok/auth.json"  "$HOMES/grok-home/auth.json"
ls -l "$HOMES"/*/auth.json 2>&1
```

Битый симлинк (`ls` ругается «No such file») означает, что соответствующий CLI ещё не
логинился. Скажи об этом прямо: `codex login` / `grok` — и повтори шаг.

## Шаг 6 — smoke-проверка

Один Bash-вызов, **HTTP-код и только он** (тело ответа может содержать эхо ключа):

```bash
S="$HOME/.claude/settings.json"
g(){ jq -r --arg k "$1" '.env[$k] // ""' "$S"; }
PM=$(g PUBMED_API_KEY); PME=$(g PUBMED_EMAIL); S2=$(g SEMANTIC_SCHOLAR_API_KEY)
OA=$(g OPENALEX_API_KEY); OAM=$(g OPENALEX_MAILTO); CR=$(g CROSSREF_MAILTO); UP=$(g UNPAYWALL_EMAIL)
p(){ printf '%-18s %s (HTTP %s)\n' "$1" "$([ "$3" = 200 ] && echo PASS || echo FAIL)" "$3"; }

p PubMed "" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
  "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=aspirin&retmax=1&retmode=json&api_key=${PM}&tool=search-paper&email=${PME}")"
p "Semantic Scholar" "" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
  -H "x-api-key: ${S2}" 'https://api.semanticscholar.org/graph/v1/paper/search?query=aspirin&limit=1')"
p OpenAlex "" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
  -H "Authorization: Bearer ${OA}" "https://api.openalex.org/works?search=aspirin&per-page=1&mailto=${OAM}")"
p Crossref "" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
  "https://api.crossref.org/works/10.1136/bmj.39493.646875.AE?mailto=${CR}")"
p Unpaywall "" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
  "https://api.unpaywall.org/v2/10.1136/bmj.39493.646875.AE?email=${UP}")"
p "Europe PMC" "" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
  'https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=aspirin&format=json&pageSize=1')"

echo "---"
# Яндекс: только --dry-run (0 ₽, живого вызова нет). Ключ проверяется отдельно — по наличию в env.
YC=$(g YC_SEARCH_API_KEY)
if bash "${CLAUDE_PLUGIN_ROOT}/scripts/yandex-search.sh" "тест" --dry-run >/dev/null 2>&1; then
  [ -n "$YC" ] && echo "yandex-search PASS (скрипт ок, ключ задан)" \
               || echo "yandex-search SKIP (скрипт ок, YC_SEARCH_API_KEY не задан — канал yandex выключен)"
else
  echo "yandex-search FAIL (скрипт не отработал --dry-run)"
fi
command -v codex >/dev/null && echo "codex CLI     PASS" || echo "codex CLI     FAIL (нет в PATH)"
command -v grok  >/dev/null || [ -x "$HOME/.grok/bin/grok" ] && echo "grok CLI      PASS" || echo "grok CLI      FAIL (нет в PATH)"
command -v uv    >/dev/null && echo "uv (substack) PASS" || echo "uv (substack) FAIL — brew install uv"
command -v pdftotext >/dev/null && echo "pdftotext     PASS" || echo "pdftotext     FAIL — brew install poppler"
```

Разбор FAIL:

| Что видно | Причина | Что делать |
|---|---|---|
| HTTP 401 / 403 | ключ неверный или пустой | перезаписать значение шагом 4 |
| HTTP 429 | лимит вежливого пула | ключ рабочий; повторить через минуту |
| HTTP 000 | нет сети или таймаут | проверить соединение |
| PubMed FAIL, остальные PASS | `PUBMED_EMAIL` не совпадает с NCBI-профилем | привести почту к той, что в профиле NCBI |
| Всё FAIL после свежей записи | сессия ещё не перечитала `env` | **перезапустить Claude Code** и прогнать `--check` |

## Шаг 7 — финал

Печатай ровно это:

1. Таблицу PASS/FAIL.
2. Строку: «`env` из `settings.json` применяется на старте сессии — **перезапусти Claude Code**,
   иначе протоколы всё ещё увидят старые (или пустые) значения».
3. Что дальше: `/jadlis-research:search` любым вопросом — если ответ пришёл со ссылками,
   Brave подключён и батч 4 можно закрывать боевыми прогонами.

Значения ключей в финале не показывай — ни целиком, ни хвостом, ни первыми символами.
