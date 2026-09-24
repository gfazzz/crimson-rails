#!/usr/bin/env bash
# CRIMSON RAILS — прогон одной серии сезона 6.
#
# Проверяется приложение сезона. Пока в нём нет ни одной своей задачи
# (app/jobs пуст, кроме ApplicationJob), проверять нечего — и тогда
# прогоняется эталон, как в сезонах 1–5.
set -uo pipefail
season="$(cd "$(dirname "$0")/.." && pwd)"
series="${1:?нужен номер серии, например s06e01}"

own="$(find "$season/app/app/jobs" -name '*_job.rb' ! -name 'application_job.rb' 2>/dev/null | head -1)"
if [ -n "$own" ]; then
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

echo "Источник: solution/ (в приложении ещё нет своих задач — проверяю эталон)"
exec "$season/support/reference.sh" "$series"
