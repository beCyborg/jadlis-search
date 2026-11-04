---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill, Bash]
description: A company/pricing lookup routes to Exa with the default lite type (2026-11 audit verdict)
expected_outcome: Claude runs websearch.py exa (no --type auto / brave as the first engine) for the company query
---

найди в интернете, что известно о компании Peec AI: чем занимается и сколько стоят тарифы
