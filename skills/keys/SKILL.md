---
name: keys
description: "Ключи ресерч-стека по единому стандарту: всё живёт в Связке ключей macOS, а не в файлах. Показывает, что уже заведено (имена и длины, без значений), принимает недостающие значения по одному и пишет их через scripts/secret.sh, переносит legacy-ключи из settings.json в Связку и гоняет smoke-проверку по каждому источнику с таблицей PASS/FAIL.\nTRIGGER when: user says \"настрой ключи\", \"ключи ресерча\", \"проверь ключи\", \"keys\", \"/search:keys\", \"research keys\", \"куда положить ключ\", \"почему PubMed не отвечает\", \"смоук источников\", or has just installed search and needs configuration.\nDO NOT TRIGGER when: обычный поиск (use /search), верификация плана (use /verif)."
allowed-tools: Read, Edit, Write, Bash, AskUserQuestion
argument-hint: "[--check — только проверка, без записи]"
---

# /search:keys — ключи ресерч-стека и smoke-проверка

`$ARGUMENTS`

Один принцип: **ключ вводится один раз и живёт в Связке ключей macOS (Keychain), не в файлах.**
Читает их единая точка — `${CLAUDE_PLUGIN_ROOT}/scripts/secret.sh`.

| Класс | Что за ключи | Кто пишет | Как читает |
|---|---|---|---|
| **A** — ключи MCP-серверов плагина | `BRAVE_API_KEY`, `FIRECRAWL_API_KEY`, `REDDITAPIS_KEY`, `YOUTUBE_API_KEY` | сам Claude Code: `/plugin configure search@jadlis`, диалог при включении плагина или `claude plugin install … --config KEY=…` | MCP — через `${user_config.KEY}`; Bash — через `secret.sh` |
| **B** — ключи скриптов и `curl`-блоков | научные источники, Exa, Yandex, Places, контактные почты | этот скилл: `secret.sh --set KEY` (значение приходит на stdin) | `secret.sh KEY` или прелюд `eval "$(… --export …)"` |

Порядок разрешения в `secret.sh`: (1) переменная окружения, (2) Keychain `jadlis`/`KEY` (fallback `jadlis-research`),
(3) `pluginSecrets` из блоба `Claude Code-credentials` (затем `Claude Code-credentials-*`),
(4) `.credentials.json`, (5) `settings.json → env` — legacy-рельса, которую этот скилл предлагает
свернуть (шаг 5).

Как это лежит в Связке (стандарт B′, 06.09.2026):
- **Класс A** — Claude Code кладёт значения в Keychain-запись `Claude Code-credentials` (для профилей
  с `CLAUDE_CONFIG_DIR` — `Claude Code-credentials-<hash>`) как JSON `pluginSecrets["<plugin>@<marketplace>"].KEY`.
  Посмотреть из Bash (структуру, не значения): `security find-generic-password -s "Claude Code-credentials" -w | jq`.
- **Класс B** — generic password: service `jadlis`, account = имя ключа; пишет этот скилл
  (`secret.sh --set`, значение на stdin, под капотом `security add-generic-password -U -T /usr/bin/security`).

**Почему Связка, а не файлы:** `settings.json → env` — открытый текст с правами 644, уезжает в бэкапы;
`~/.zshenv` не виден MCP-серверам десктопного приложения; 1Password есть не у всех. Доки Claude Code
пишут «~2 КБ на блоб Keychain» — на живом профиле блоб 10 КБ читается штатно.

> [!warning] Значения ключей не печатать
> Ни в ответе пользователю, ни в эхо Bash, ни в сообщении об ошибке. Максимум — имя
> переменной и длина значения. Один вывод ключа в транскрипт = ключ скомпрометирован.
> Значение всегда идёт на stdin, **никогда в командную строку** (командная строка видна
> в `ps` и попадает в транскрипт).

## Константы

```
SECRET     = ${CLAUDE_PLUGIN_ROOT}/scripts/secret.sh
```

## Шаг 1 — что уже есть

Один Bash-вызов. Печатает **имена, длины и источник**, не значения:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/secret.sh" --list
```

Прочитай таблицу и раздели ключи на три кучки:
- **есть, источник `keychain generic` или `pluginSecrets`** — по стандарту, трогать не надо;
- **есть, источник `settings.json env`** — legacy, предложить перенос на шаге 5;
- **НЕТ** — недостающие, шаги 2–4.

> [!warning] «Ключа нет» — проверять по всем рельсам, иначе ложный негатив
> Legacy-рельса владельца жива, и env имеет приоритет. Наблюдение 22.07.2026: проверка по одному
> `~/.zshenv` дала ложный негатив — часть ключей живёт в env-блоке `~/.claude/settings.json`
> (пример: `TRUSTMRR_API_KEY`, ключ «Claude» с 26.05.2026; план считал сервис незарегистрированным).
> Env-блок инжектится в каждую сессию, но grep по dotfiles его не покрывает, и ключ мог быть создан
> в другой сессии. Полный чек = `env | grep NAME` (живое окружение) + `jq '.env | keys' ~/.claude/settings.json`
> + `grep ~/.zshenv` + Связка (generic `jadlis` и `pluginSecrets`) — это и делает `secret.sh --list`.
> Плюс сверить «1/N keys» в кабинете сервиса: существующий ключ там часто нельзя показать повторно.

Разделение на обязательные и опциональные:

| Обязательные | Опциональные (модули включаются, только если ключ есть) |
|---|---|
| `BRAVE_API_KEY`, `FIRECRAWL_API_KEY` (класс A) · `PUBMED_API_KEY`, `PUBMED_EMAIL`, `SEMANTIC_SCHOLAR_API_KEY`, `OPENALEX_API_KEY`, `OPENALEX_MAILTO`, `CROSSREF_MAILTO`, `UNPAYWALL_EMAIL` (класс B) | `REDDITAPIS_KEY`, `YOUTUBE_API_KEY`, `EXA_API_KEY`, `CORE_API_KEY`, `SCITE_API_KEY`, `CONSENSUS_API_KEY`, `YC_SEARCH_API_KEY`, `GOOGLE_PLACES_API_KEY`, `TAVILY_API_KEY`, `SERPER_API_KEY`, `WYKOP_API_KEY`, `TWITTERAPI_IO_KEY` |

Нужен только `/verif` — хватит `BRAVE_API_KEY` и `FIRECRAWL_API_KEY`; научные ключи
можно пропустить и вернуться к ним перед первым `search-paper`.

`YC_SEARCH_API_KEY` — только для opt-in канала `yandex` в `/research`
(поиск по Рунету, платный ≈0,1–0,15 ₽/тема). Без него канал не предлагается и, если всё-таки
выбран, деградирует (`exit 2`, `sourceQuality=LOW`) — остальной ресерч работает как обычно.

`GOOGLE_PLACES_API_KEY` — только для place-слоя канала `web` (локальные/бытовые темы: выбор
заведения, клиники, секции). Без него `places-fetch.sh` возвращает `exit 3 PLACES_KEY_MISSING`
= SKIP, и слой сам деградирует в `brave_place_search` — это штатно.

> [!danger] Бюджет-кап ДО первого вызова
> У Places API нет hard cap by design: перерасход останавливается только budget alert →
> отключение billing. Прежде чем звать `places-fetch.sh` хоть раз, поставь бюджет-кап
> в Google Cloud Console. Дефолтная маска полей попадает в SKU Enterprise
> ($35/1000 запросов, free tier 1000 событий/мес — при research-объёмах бесплатно);
> `reviews` в маску не добавлять (+$5/1000).

**Внешние бинарники** (не ключи, но без них каналы деградируют): `jq` (обязателен для
`secret.sh`, `hn-fetch.sh` и `places-fetch.sh`), `uv` (шебанг `substack-fetch.py` и
`yt-transcript.py`), `pdftotext` (poppler, для `pdf-fetch.sh`), опц. `yt-dlp` (фоллбэк
транскриптов), опц. `codex`/`grok` CLI (каналы `codexweb`/`grokweb` и верификаторы
`/verif`).

## Шаг 2 — где взять недостающее

Покажи таблицу **только по тем, которых нет**:

| Переменная | Класс | Где завести |
|---|---|---|
| `BRAVE_API_KEY` | A | https://api-dashboard.search.brave.com → подписка на тариф **Search** → Subscriptions → API keys |
| `FIRECRAWL_API_KEY` | A | https://firecrawl.dev/app/api-keys (формат `fc-…`) |
| `REDDITAPIS_KEY` | A | https://redditapis.com (резервный Reddit-MCP, ~$0.002 за вызов) |
| `YOUTUBE_API_KEY` | A | https://console.cloud.google.com → включить **YouTube Data API v3** → Credentials → API key |
| `EXA_API_KEY` | B | https://dashboard.exa.ai → API Keys (семантический слой `/search`, $0.007/поиск) |
| `TWITTERAPI_IO_KEY` | B | https://twitterapi.io → Dashboard → API key (слой реплаев/био/трендов Twitter-канала и keyword-фолбэк при мёртвом Grok; $0.15 за 1K твитов, минимальное пополнение снимает лимит 1 запрос/5 с) |
| `PUBMED_API_KEY`, `PUBMED_EMAIL` | B | https://www.ncbi.nlm.nih.gov/account/settings/ → API Key Management |
| `SEMANTIC_SCHOLAR_API_KEY` | B | https://www.semanticscholar.org/product/api |
| `OPENALEX_API_KEY`, `OPENALEX_MAILTO` | B | https://openalex.org (freemium dashboard) |
| `CROSSREF_MAILTO` | B | регистрации нет — своя почта для polite pool |
| `UNPAYWALL_EMAIL` | B | регистрации нет — своя почта в параметре `email=` |
| `CORE_API_KEY` | B | https://core.ac.uk/services/api |
| `GOOGLE_PLACES_API_KEY` | B | https://console.cloud.google.com → включить **Places API (New)** → Credentials → API key. **Сначала бюджет-кап**, потом ключ |
| `YC_SEARCH_API_KEY` | B | https://console.yandex.cloud → сервисный аккаунт с ролью `search-api.webSearch.user` → создать **Api-Key** (не IAM-токен) |

`*_MAILTO` и `*_EMAIL` — контактные почты пользователя, не ключи: по ним API узнают, кто
стучится, и пускают в вежливый пул. Одна и та же почта во всех трёх — нормально.

## Шаг 3 — класс A: ключи MCP-серверов

Эти ключи **пишет Claude Code, не ты**: они уезжают в `pluginSecrets` записи Keychain
`Claude Code-credentials`, откуда их берут и MCP-серверы (`${user_config.KEY}` в `.mcp.json`),
и `secret.sh`.

Проверь, что каждый резолвится:

```bash
for K in BRAVE_API_KEY FIRECRAWL_API_KEY REDDITAPIS_KEY YOUTUBE_API_KEY; do
  bash "${CLAUDE_PLUGIN_ROOT}/scripts/secret.sh" --which "$K"
done
```

Источник `pluginSecrets (Claude Code-credentials…)` — всё по стандарту. `не найден` или
источник `settings.json env` — скажи пользователю ввести ключ самому, **одним из трёх способов**
(значение вводит он, не ты):

1. **`/plugin configure search@jadlis`** прямо в чате Claude Code — основной путь:
   диалог со всеми полями `userConfig`, sensitive-значения маскируются при вводе и уезжают
   в Связку ключей. Работает и на уже установленном плагине, и для смены ключа.
2. Выключить и снова включить плагин (`claude plugin disable/enable search`) — при
   включении Claude Code спросит недостающие поля тем же диалогом.
3. Из своего терминала: `claude plugin install search@jadlis --config BRAVE_API_KEY=…`
   — годится для первой установки; значение видно в истории shell, потому это запасной путь.

`--check` в аргументах → шаги 4 и 5 пропустить, идти сразу на шаг 6.

> [!note] Окно «security хочет получить доступ»
> При первом чтении блоба `Claude Code-credentials` утилитой `security` macOS может показать
> запрос доступа — нажать **«Разрешить всегда»**, иначе `secret.sh` будет видеть класс A как
> «не найден». Записи класса B создаются с `-T /usr/bin/security` и окна не вызывают.

## Шаг 4 — класс B: приём значений и запись в Связку

Спроси значения **по одному**, обычным сообщением (не AskUserQuestion — там значение
попадёт в лейбл кнопки). Формулировка: «Пришли значение `PUBMED_API_KEY` одной строкой».

Записывай сразу, значение — **на stdin**, никогда аргументом:

```bash
printf '%s' "$VALUE_FROM_USER" | bash "${CLAUDE_PLUGIN_ROOT}/scripts/secret.sh" --set PUBMED_API_KEY
```

Скрипт печатает ровно `OK: PUBMED_API_KEY записан в Keychain (длина N)`. Ничего сверх этого
не добавляй: ни хвоста значения, ни первых символов.

Под капотом это `security add-generic-password -U -s jadlis -a <KEY> -T /usr/bin/security -w`:
`-U` перезаписывает существующую запись, `-T /usr/bin/security` даёт доступ без диалога.

Ключи класса B читаются **без перезапуска** Claude Code — `secret.sh` ходит в Связку в момент
вызова. Перезапуск нужен только классу A (MCP-серверы поднимаются на старте сессии).

## Шаг 5 — перенос legacy-значений из `settings.json`

Если на шаге 1 у какого-то ключа источник — `settings.json env`, предложи перенос:
«`PUBMED_API_KEY` лежит открытым текстом в `~/.claude/settings.json` (права 644, попадает
в бэкапы). Перенести в Связку ключей и удалить из файла?»

Без подтверждения **не трогать файл**. После «да» — по одному ключу:

```bash
S="$HOME/.claude/settings.json"
NAME="PUBMED_API_KEY"
# 1) прочитать значение из файла и записать в Связку (значение не печатается)
jq -r --arg k "$NAME" '.env[$k] // ""' "$S" \
  | bash "${CLAUDE_PLUGIN_ROOT}/scripts/secret.sh" --set "$NAME"
# 2) убедиться, что Связка отдаёт его, и только тогда чистить файл
if bash "${CLAUDE_PLUGIN_ROOT}/scripts/secret.sh" --which "$NAME" | grep -q 'keychain generic'; then
  T=$(mktemp)
  jq --arg k "$NAME" 'if .env then .env |= del(.[$k]) else . end' "$S" > "$T" && mv "$T" "$S"
  echo "MOVED: $NAME → Связка ключей, из settings.json удалён"
else
  echo "SKIP: $NAME не подтвердился в Связке — settings.json НЕ тронут"
fi
```

**Только `jq` с временным файлом, никогда `Edit` по живому `settings.json`** — файл может
одновременно писаться самим Claude Code, и ручная правка затрёт чужие изменения. Порядок
«сначала записать в Связку, проверить, потом удалить из файла» обязателен: иначе сбой записи
оставит пользователя без ключа.

Ключи класса A из `settings.json → env` переносить **не нужно и нечем**: их пишет Claude Code,
путь — шаг 3.

## Шаг 6 — smoke-проверка

Один Bash-вызов, **HTTP-код и только он** (тело ответа может содержать эхо ключа). Ключи
приходят прелюдом из Связки — в командной строке `curl` подставляется уже переменная:

```bash
SECRET="${CLAUDE_PLUGIN_ROOT}/scripts/secret.sh"
eval "$(bash "$SECRET" --export PUBMED_API_KEY PUBMED_EMAIL SEMANTIC_SCHOLAR_API_KEY \
        OPENALEX_API_KEY OPENALEX_MAILTO CROSSREF_MAILTO UNPAYWALL_EMAIL \
        YC_SEARCH_API_KEY GOOGLE_PLACES_API_KEY 2>/dev/null)"
p(){ printf '%-18s %s (HTTP %s)\n' "$1" "$([ "$3" = 200 ] && echo PASS || echo FAIL)" "$3"; }

p PubMed "" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
  "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=aspirin&retmax=1&retmode=json&api_key=${PUBMED_API_KEY:-}&tool=search-paper&email=${PUBMED_EMAIL:-}")"
p "Semantic Scholar" "" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
  -H "x-api-key: ${SEMANTIC_SCHOLAR_API_KEY:-}" 'https://api.semanticscholar.org/graph/v1/paper/search?query=aspirin&limit=1')"
p OpenAlex "" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
  -H "Authorization: Bearer ${OPENALEX_API_KEY:-}" "https://api.openalex.org/works?search=aspirin&per-page=1&mailto=${OPENALEX_MAILTO:-}")"
p Crossref "" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
  "https://api.crossref.org/works/10.1136/bmj.39493.646875.AE?mailto=${CROSSREF_MAILTO:-}")"
p Unpaywall "" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
  "https://api.unpaywall.org/v2/10.1136/bmj.39493.646875.AE?email=${UNPAYWALL_EMAIL:-}")"
p "Europe PMC" "" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
  'https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=aspirin&format=json&pageSize=1')"

echo "---"
# Brave: живой вызов через websearch.py — он сам резолвит ключ по стандарту (env → Связка).
if python3 "${CLAUDE_PLUGIN_ROOT}/scripts/websearch.py" brave "canary" --tag other -n 1 --out urls >/dev/null 2>&1; then
  echo "Brave (websearch) PASS"
else
  echo "Brave (websearch) FAIL — проверь BRAVE_API_KEY шагом 3 (402/403 = биллинг тарифа Search)"
fi

# Яндекс: только --dry-run (0 ₽, живого вызова нет). Ключ проверяется отдельно — по резолву.
if bash "${CLAUDE_PLUGIN_ROOT}/scripts/yandex-search.sh" "тест" --dry-run >/dev/null 2>&1; then
  [ -n "${YC_SEARCH_API_KEY:-}" ] && echo "yandex-search PASS (скрипт ок, ключ найден)" \
                                  || echo "yandex-search SKIP (скрипт ок, YC_SEARCH_API_KEY нет — канал yandex выключен)"
else
  echo "yandex-search FAIL (скрипт не отработал --dry-run)"
fi
command -v codex >/dev/null && echo "codex CLI     PASS" || echo "codex CLI     FAIL (нет в PATH)"
command -v grok  >/dev/null || [ -x "$HOME/.grok/bin/grok" ] && echo "grok CLI      PASS" || echo "grok CLI      FAIL (нет в PATH)"
command -v uv    >/dev/null && echo "uv (substack/yt) PASS" || echo "uv (substack/yt) FAIL — brew install uv"
command -v jq    >/dev/null && echo "jq (secret/hn/places) PASS" || echo "jq (secret/hn/places) FAIL — brew install jq"
command -v pdftotext >/dev/null && echo "pdftotext     PASS" || echo "pdftotext     FAIL — brew install poppler"
command -v yt-dlp >/dev/null && echo "yt-dlp (опц.) PASS" || echo "yt-dlp (опц.) SKIP — фоллбэк транскриптов недоступен"

# Places: живой вызов НЕ делаем (платный) — только гейт по ключу.
[ -n "${GOOGLE_PLACES_API_KEY:-}" ] && echo "places-fetch  PASS (ключ найден; бюджет-кап поставлен?)" \
                                    || echo "places-fetch  SKIP (ключа нет — place-слой идёт через Brave Place)"

# Свои фетчеры каналов hackernews / substack / telegram / youtube (сеть, 0 ₽).
R="${CLAUDE_PLUGIN_ROOT}/scripts"
bash "$R/hn-fetch.sh" canary >/dev/null 2>&1 && echo "hn-fetch      PASS" || echo "hn-fetch      FAIL (нет jq или сеть)"
bash "$R/tg-preview.sh" durov >/dev/null 2>&1 && echo "tg-preview    PASS" || echo "tg-preview    FAIL (сеть или t.me недоступен)"
"$R/substack-fetch.py" search-pub "ai agents" >/dev/null 2>&1 && echo "substack-fetch PASS" || echo "substack-fetch FAIL (нет uv или сеть)"
"$R/yt-transcript.py" jNQXAC9IVRw >/dev/null 2>&1 && echo "yt-transcript PASS" \
  || echo "yt-transcript SKIP (IpBlocked/нет сабов — канал youtube живёт на Brave + описаниях)"
```

Разбор FAIL:

| Что видно | Причина | Что делать |
|---|---|---|
| HTTP 401 / 403 | ключ неверный или пустой | перезаписать значение шагом 4 (класс B) или шагом 3 (класс A) |
| HTTP 429 | лимит вежливого пула | ключ рабочий; повторить через минуту |
| HTTP 000 | нет сети или таймаут | проверить соединение |
| PubMed FAIL, остальные PASS | `PUBMED_EMAIL` не совпадает с NCBI-профилем | привести почту к той, что в профиле NCBI |
| Всё FAIL, а `--list` показывает ключи | прелюд `--export` не отработал | проверить `jq` в PATH и `bash "$SECRET" --which <KEY>` |
| Класс A «не найден», хотя вводился | окно доступа к Связке отклонено | повторить и нажать «Разрешить всегда» |
| MCP-серверы красные в `/mcp` после ввода | сессия ещё не подняла серверы | **перезапустить Claude Code** |

## Шаг 7 — финал

Печатай ровно это:

1. Таблицу PASS/FAIL.
2. Строку: «Класс B (научные ключи, Exa, Yandex, Places) читается сразу. Класс A
   (`BRAVE_API_KEY`, `FIRECRAWL_API_KEY`, `REDDITAPIS_KEY`, `YOUTUBE_API_KEY`) поднимает
   MCP-серверы на старте сессии — **перезапусти Claude Code**, если только что их вводил».
3. Что дальше: `/search` любым вопросом — если ответ пришёл со ссылками,
   Brave подключён; `/verif --file <свой план>` — первый боевой прогон.

Значения ключей в финале не показывай — ни целиком, ни хвостом, ни первыми символами.
