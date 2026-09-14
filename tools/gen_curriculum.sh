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
  echo "Не написан. План — в [CONCEPT.md](../CONCEPT.md), маршрут — в [ROUTE.md](ROUTE.md)."
  echo
  echo "## Season 3 — Нью-Йорк · JavaScript"
  echo
  echo "Не написан."
  echo
  echo "## Season 4–8 — Rails 8"
  echo
  echo "Не написаны. Артефакты: \`ledger\`, \`signal_box\`, \`dispatch\`, \`keyring\`, \`crimson\`."
} > docs/CURRICULUM.md
