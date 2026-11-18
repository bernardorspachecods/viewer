#!/usr/bin/env bash
# Enforces the Swift file-size limit for Sources/ and Tests/.
#
# A file over LIMIT lines must be pinned in scripts/file-size-baseline.json at
# its current line count. A pin can only go down:
#   - a new file over the limit, or a pinned file that grew, fails;
#   - a pinned file that shrank fails until its pin is lowered;
#   - a pin for a file now at or under the limit fails until it is removed.
#
#   scripts/check-file-size.sh            check; exit 1 on any violation
#   scripts/check-file-size.sh --update   lower pins to current counts
#                                         (refuses growth and new files)
set -euo pipefail

LIMIT=500
MODE="${1:-check}"
case "$MODE" in
  check|--check) MODE=check ;;
  --update) MODE=update ;;
  *) echo "usage: $0 [--update]" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASELINE="$ROOT/scripts/file-size-baseline.json"
cd "$ROOT"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
sizes="$work/sizes.txt"
pins="$work/pins.txt"
next="$work/next-baseline.json"

# "<path> <lines>" for every Swift file; awk NR matches a last line without a newline.
find Sources Tests -name '*.swift' -type f | sort | while IFS= read -r file; do
  printf '%s %s\n' "$file" "$(awk 'END { print NR }' "$file")"
done > "$sizes"

# Baseline entries are one `"path": N` pair per line (see the JSON file).
if [ -f "$BASELINE" ]; then
  sed -n 's/^[[:space:]]*"\([^"]*\)"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\),*[[:space:]]*$/\1 \2/p' "$BASELINE" > "$pins"
else
  : > "$pins"
fi

set +e
awk -v limit="$LIMIT" -v mode="$MODE" -v out="$next" -v pinsfile="$pins" '
  # Keyed by file name: an empty pins file must not make the sizes file look like pins.
  FILENAME == pinsfile { pin[$1] = $2 + 0; pinned[$1] = 1; next }
  { size[$1] = $2 + 0; order[++count] = $1 }
  END {
    hard = 0; soft = 0
    for (i = 1; i <= count; i++) {
      f = order[i]; s = size[f]
      if (s <= limit) continue
      if (!(f in pinned)) {
        print f ": " s " lines, over the " limit "-line limit and not pinned. Split the file; a new file cannot be pinned." > "/dev/stderr"
        hard++
      } else if (s > pin[f]) {
        print f ": " s " lines, grew from its pin of " pin[f] ". Split the file instead of growing it." > "/dev/stderr"
        hard++
      } else if (s < pin[f]) {
        print f ": " s " lines, below its pin of " pin[f] ". Lower the pin (scripts/check-file-size.sh --update)." > "/dev/stderr"
        soft++
      }
    }
    for (f in pinned) {
      if (!(f in size)) {
        print f ": pinned but no longer exists. Remove its pin (scripts/check-file-size.sh --update)." > "/dev/stderr"
        soft++
      } else if (size[f] <= limit) {
        print f ": " size[f] " lines, at or under the limit. Remove its pin (scripts/check-file-size.sh --update)." > "/dev/stderr"
        soft++
      }
    }
    if (mode == "update") {
      if (hard > 0) exit 1
      n = 0
      for (i = 1; i <= count; i++) {
        f = order[i]
        if (size[f] > limit && (f in pinned)) keep[++n] = f
      }
      print "{" > out
      for (j = 1; j <= n; j++) {
        f = keep[j]
        printf "  \"%s\": %d%s\n", f, size[f], (j < n ? "," : "") > out
      }
      print "}" > out
      close(out)
      exit 0
    }
    exit (hard + soft > 0) ? 1 : 0
  }
' "$pins" "$sizes"
status=$?
set -e

if [ "$MODE" = update ]; then
  if [ "$status" -ne 0 ]; then
    echo "Baseline not updated: fix the violations above first." >&2
    exit 1
  fi
  if [ -f "$BASELINE" ] && cmp -s "$next" "$BASELINE"; then
    echo "File-size baseline already up to date."
  else
    mv "$next" "$BASELINE"
    echo "File-size baseline updated in scripts/file-size-baseline.json."
  fi
  exit 0
fi

if [ "$status" -ne 0 ]; then
  exit 1
fi
echo "File sizes OK (limit $LIMIT lines)."
