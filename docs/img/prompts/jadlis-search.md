# jadlis-search

Мысль: один вопрос уходит в тот движок, который умеет этот тип вопроса — по словам или по смыслу, — а текст страницы снимается отдельной лестницей, где платный способ стоит последним.

## hero

- Картинка: `docs/img/hero-jadlis-search.webp`
- Заголовок: «По словам, по смыслу — и страница целиком»
- Слева: вопрос обычными словами; подпись «Вопрос»
- Справа: две ветки — «По словам» и «По смыслу»
- Отдельно: лестница снятия страницы целиком, последняя ступень оранжевая с подписью «платный способ — последним»
- Названия движков в картинку не идут: только категории

```
Style: clean flat infographic on a light off-white background (#fdfbf7), two accent colors — deep teal (#1a7174) and warm orange (#f37d2c), thin dark-gray (#2f3333) line art, generous whitespace, geometric shapes, a modern geometric sans-serif look. Short Russian labels rendered as crisp, correctly spelled Cyrillic text. No robots, no glowing AI sparkles or glitter, no stock-photo people, no watermark. Wide 2:1 composition, 1280x640.

Hero illustration for a GitHub README about a web-search layer. Bold Russian headline across the top «По словам, по смыслу — и страница целиком». On the left, a teal card holding three plain gray text lines that stand for a question written in ordinary words, labeled «Вопрос». From that card two thick orange arrows fork to the right into two teal blocks placed one above the other: a magnifying glass over letter tiles labeled «По словам», and a magnifying glass over soft overlapping shapes labeled «По смыслу». Separately, in the lower right area and not connected to the fork, a flat outlined staircase of exactly four steps rising left to right, drawn as thin line art with no 3D depth and no solid fill — it must read as a sequence of routes tried in order, never as a bar chart. Each step carries a small numeral 1, 2, 3, 4 on its tread. The three lower steps are teal outlines and the topmost step is an orange outline; a small Russian caption beside the top step reads «платный способ — последним», and the whole staircase is labeled «Страница целиком». No logos, no brand names, no service names. Text must be spelled exactly.
```

## scheme

- Картинка: `docs/img/how-jadlis-search.webp`
- Блоки: «Вопрос» → «Выбор движка по интенту» → «Выдача» → «Снятие страницы по лестнице» → «Ответ со ссылками и запись в лог»
- Стрелка в четвёртый блок помечена «при необходимости»
- У лестницы: хук отсекает PDF до платной ступени, подпись «мимо платной ступени»
- Примечание под последним блоком: «каждый вызов пишет строку расхода»

```
Style: clean flat infographic on a light off-white background (#fdfbf7), two accent colors — deep teal (#1a7174) and warm orange (#f37d2c), thin dark-gray (#2f3333) line art, generous whitespace, geometric shapes, a modern geometric sans-serif look. Short Russian labels rendered as crisp, correctly spelled Cyrillic text. No robots, no glowing AI sparkles or glitter, no stock-photo people, no watermark. Wide 2:1 composition, 1280x640.

Cause-and-effect diagram with five rounded boxes in a row connected left to right by arrows, alternating teal and orange label plates, a simple geometric icon on top of each box: a text field with a cursor; a fork in a path splitting into two branches with a small switch plate at the split; a list of result links; an ascending ladder of four steps whose top step is orange; a document with link lines beside a single ledger row. Russian labels under the icons: «Вопрос» → «Выбор движка по интенту» → «Выдача» → «Снятие страницы по лестнице» → «Ответ со ссылками и запись в лог». The arrow entering the fourth box is dashed and carries a small Russian label «при необходимости». Beside the ladder box a small hook shape pulls a sheet marked «PDF» away before the orange top step, with a small Russian caption «мимо платной ступени». Under the last box a small Russian caption «каждый вызов пишет строку расхода». No logos, no brand names, no service names. Text must be spelled exactly.
```

## alt

- hero (`docs/img/hero-jadlis-search.webp`): Один вопрос уходит в два движка — по словам и по смыслу, — а текст страницы снимается отдельной лестницей.
  Текстом: слева вопрос обычными словами, справа две ветки — поиск по словам и поиск по смыслу, — и отдельная лестница снятия страницы целиком, у которой Firecrawl последняя ступень.
- scheme (`docs/img/how-jadlis-search.webp`): Вопрос уходит в движок по интенту, страница снимается по лестнице, хук отсекает PDF и x.com до Firecrawl.
  Текстом: вопрос → выбор движка по интенту → выдача → при необходимости снятие страницы по лестнице → ответ со ссылками и запись в лог стоимости.
