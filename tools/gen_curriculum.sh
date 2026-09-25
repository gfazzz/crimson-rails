#!/usr/bin/env bash
# CRIMSON RAILS — пересобрать указатель серий из шапок.
set -euo pipefail
cd "$(dirname "$0")/.."
{
  echo "# Указатель серий"
  echo
  echo "Генерируется из шапок самих серий: \`make docs\`. Руками не правят."
  echo
  echo "## Season 1 — Йокогама · Ruby"
  echo
  tools/season_table.py 01 --stats
  echo
  tools/season_table.py 01 --prefix=../season-01-yokohama/
  echo
  echo "---"
  echo
  echo "## Season 2 — Лондон, Сент-Панкрас · HTML и CSS"
  echo
  tools/season_table.py 02 --stats
  echo
  tools/season_table.py 02 --prefix=../season-02-st-pancras/
  echo
  echo "---"
  echo
  echo "## Season 3 — Нью-Йорк · JavaScript"
  echo
  tools/season_table.py 03 --stats
  echo
  tools/season_table.py 03 --prefix=../season-03-manhattan/
  echo
  echo "---"
  echo
  echo "## Season 4 — Лондон, Сеймур-стрит · схема и Active Record"
  echo
  tools/season_table.py 04 --stats
  echo
  tools/season_table.py 04 --prefix=../season-04-seymour-street/
  echo
  echo "---"
  echo
  echo "## Season 5 — Дерби · маршруты, контроллеры, Hotwire"
  echo
  tools/season_table.py 05 --stats
  echo
  tools/season_table.py 05 --prefix=../season-05-derby/
  echo
  echo "---"
  echo
  echo "## Season 6 — Владивосток · фон, кеш, каналы, интеграции"
  echo
  tools/season_table.py 06 --stats
  echo
  tools/season_table.py 06 --prefix=../season-06-vladivostok/
  echo
  echo "---"
  echo
  echo "## Season 7–8 — Rails 8"
  echo
  echo "Не написаны. Артефакты: \`keyring\`, \`crimson\`."
} > docs/CURRICULUM.md
