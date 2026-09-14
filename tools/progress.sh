#!/usr/bin/env bash
# CRIMSON RAILS — где я остановился.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
done_n=0; total=0; last=""
for dir in season-*/s[0-9][0-9]e[0-9][0-9]-*/; do
  [ -d "$dir" ] || continue
  total=$((total+1))
  if [ -n "$(ls -A "$dir/artifacts" 2>/dev/null | grep -v '^\.gitkeep$')" ]; then
    done_n=$((done_n+1)); last="$(basename "$dir")"
  fi
done
echo "серий в репозитории: $total"
echo "с твоим артефактом:  $done_n"
[ -n "$last" ] && echo "последняя сданная:   $last"
exit 0
