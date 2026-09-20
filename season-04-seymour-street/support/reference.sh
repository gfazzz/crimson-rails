#!/usr/bin/env bash
# CRIMSON RAILS — прогон эталона сезона 4.
#
# Артефакт сезона — слой приложения, а не файл, поэтому эталон проверяется на
# копии приложения: solution серий по указанную включительно ложатся в копию,
# миграции прогоняются там, работа проходящего курс не трогается.
#
#   support/reference.sh            все серии
#   support/reference.sh s04e03     серии по третью включительно
set -uo pipefail
season="$(cd "$(dirname "$0")/.." && pwd)"
upto="${1:-}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/app"
tar cf - -C "$season/app" --exclude=tmp --exclude=log --exclude=storage --exclude=.git --exclude=db/schema.rb . \
  | tar xf - -C "$work/app"
mkdir -p "$work/app/tmp" "$work/app/log" "$work/app/storage"

series=()
for dir in "$season"/s04e*/; do
  name="$(basename "$dir")"
  [ -d "$dir/solution" ] && cp -R "$dir/solution/." "$work/app/"
  series+=("$dir")
  [ -n "$upto" ] && [[ "$name" == "$upto"* ]] && break
done

( cd "$work/app" && bin/rails db:migrate >/dev/null 2>&1 ) || { echo "миграции эталона не прогнались"; exit 2; }

pass=0; fail=0; failed=()
for dir in "${series[@]}"; do
  name="$(basename "$dir")"
  for test in "$dir"tests/*_test.rb; do
    [ -f "$test" ] || continue
    if LEDGER_APP="$work/app" ruby "$test"; then pass=$((pass+1)); else fail=$((fail+1)); failed+=("$name"); fi
  done
done

echo "──────────────────────────────────────────"
printf "эталон: зелёных %d, красных %d\n" "$pass" "$fail"
[ "$fail" -gt 0 ] && { printf "упали: %s\n" "${failed[*]}"; exit 1; }
exit 0
