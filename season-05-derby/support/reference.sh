#!/usr/bin/env bash
# CRIMSON RAILS — прогон эталона сезона 5.
#
# Артефакт сезона — слой приложения, поэтому эталон проверяется на копии
# приложения: solution серий по указанную включительно ложатся в копию, база
# собирается из схемы, работа проходящего курс не трогается.
#
#   support/reference.sh            все серии
#   support/reference.sh s05e03     серии по третью включительно
#
# Серии с файлом NEEDS_BROWSER идут только с VISUAL=1 (make test-visual).
set -uo pipefail
season="$(cd "$(dirname "$0")/.." && pwd)"
upto="${1:-}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/app"
tar cf - -C "$season/app" --exclude=tmp --exclude=log --exclude=storage --exclude=.git . \
  | tar xf - -C "$work/app"
mkdir -p "$work/app/tmp" "$work/app/log" "$work/app/storage"

series=()
for dir in "$season"/s05e*/; do
  name="$(basename "$dir")"
  [ -d "$dir/solution" ] && cp -R "$dir/solution/." "$work/app/"
  series+=("$dir")
  [ -n "$upto" ] && [[ "$name" == "$upto"* ]] && break
done

( cd "$work/app" && bin/rails db:prepare >/dev/null 2>&1 ) || { echo "база эталона не собралась"; exit 2; }

pass=0; fail=0; skip=0; failed=()
for dir in "${series[@]}"; do
  name="$(basename "$dir")"
  if [ -f "$dir/NEEDS_BROWSER" ] && [ -z "${VISUAL:-}" ]; then
    skip=$((skip+1)); continue
  fi
  for test in "$dir"tests/*_test.rb; do
    [ -f "$test" ] || continue
    echo "серия: ${name:0:6}"
    if LEDGER_APP="$work/app" ruby "$test"; then pass=$((pass+1)); else fail=$((fail+1)); failed+=("$name"); fi
  done
done

echo "──────────────────────────────────────────"
printf "эталон: зелёных %d, красных %d" "$pass" "$fail"
[ "$skip" -gt 0 ] && printf ", с браузером отложено %d (VISUAL=1)" "$skip"
echo
[ "$fail" -gt 0 ] && { printf "упали: %s\n" "${failed[*]}"; exit 1; }
exit 0
