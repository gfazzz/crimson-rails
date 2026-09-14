#!/usr/bin/env bash
# CRIMSON RAILS — прогон серий.
# SEASON=01 — один сезон, SERIES=s01e01 — одна серия, VISUAL=1 — серии с браузером.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

season="${SEASON:-}"; series="${SERIES:-}"; visual="${VISUAL:-}"
pass=0; fail=0; skip=0; failed=()

for dir in season-*/s[0-9][0-9]e[0-9][0-9]-*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  [ -n "$season" ] && [[ "$dir" != season-"$season"-* ]] && continue
  [ -n "$series" ] && [[ "$name" != "$series"-* ]] && continue

  # серии, которым нужен браузер, помечены файлом NEEDS_BROWSER
  if [ -f "$dir/NEEDS_BROWSER" ]; then
    [ -z "$visual" ] && { skip=$((skip+1)); continue; }
  else
    [ -n "$visual" ] && continue
  fi

  [ -f "$dir/Makefile" ] || { echo "·· $name — нет Makefile, пропуск"; skip=$((skip+1)); continue; }
  if make -s -C "$dir" test; then pass=$((pass+1)); else fail=$((fail+1)); failed+=("$name"); fi
  echo
done

echo "──────────────────────────────────────────"
printf "зелёных: %d   красных: %d   пропущено: %d\n" "$pass" "$fail" "$skip"
[ "$fail" -gt 0 ] && { printf "упали: %s\n" "${failed[*]}"; exit 1; }
[ "$pass" -eq 0 ] && { echo "нечего прогонять"; exit 0; }
exit 0
