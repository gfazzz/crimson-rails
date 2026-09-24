#!/usr/bin/env bash
# CRIMSON RAILS — относительные ссылки между документами.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
bad=0
while IFS= read -r file; do
  dir="$(dirname "$file")"
  grep -o '](\([^)]*\))' "$file" 2>/dev/null | sed 's/^](//; s/)$//' | while read -r link; do
    case "$link" in http*|mailto:*|'#'*) continue;; esac
    target="${link%%#*}"; [ -z "$target" ] && continue
    [ -e "$dir/$target" ] || echo "БИТАЯ  $file → $link"
  done
done < <(find . -name '*.md' \
           -not -path './_backup*' \
           -not -path './_transfer/*' \
           -not -path './_to_delete/*' \
           -not -path './.git/*' \
           -not -path '*/node_modules/*') | tee /tmp/cr_links.$$
if [ -s /tmp/cr_links.$$ ]; then bad=1; else echo "ссылки: все целы"; fi
rm -f /tmp/cr_links.$$
exit $bad
