---
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
description: A plain coding request must not trigger any plugin skill
expected_outcome: Claude answers with code and never calls the Skill tool
---

напиши функцию на Python, которая сортирует список словарей по ключу date
