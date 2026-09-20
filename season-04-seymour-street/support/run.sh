#!/usr/bin/env bash
# CRIMSON RAILS — прогон одной серии сезона 4.
#
# Проверяется приложение сезона. Пока в нём нет ни одной миграции, проверять
# нечего — и тогда прогоняется эталон, ровно как в сезонах 1–3, где тест
# брал solution/, если artifacts/ пуст.
set -uo pipefail
season="$(cd "$(dirname "$0")/.." && pwd)"
series="${1:?нужен номер серии, например s04e01}"

if compgen -G "$season/app/db/migrate/*.rb" > /dev/null; then
  echo "Источник: app/"
  status=0
  for dir in "$season/$series"*/; do
    for test in "$dir"tests/*_test.rb; do
      [ -f "$test" ] || continue
      ruby "$test" || status=1
    done
  done
  exit "$status"
fi

echo "Источник: solution/ (в приложении ещё нет миграций — проверяю эталон)"
exec "$season/support/reference.sh" "$series"
