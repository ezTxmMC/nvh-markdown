#!/usr/bin/env bash
# Golden tests of nvh-markdown: every test/<name>.nv is run with novusc and must print <name>.golden.
#
#   test/run.sh             run everything
#   test/run.sh inline      run the tests whose name contains "inline"
#   test/run.sh --update    rewrite the golden files (review the diff before committing)
#
# NOVUSC points at the compiler (default: novusc in PATH, else the checkout next to this repository).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
NOVUSC="${NOVUSC:-$(command -v novusc || echo "$HERE/../../novus/build/novusc")}"
case "$NOVUSC" in /*) ;; *) NOVUSC="$(command -v "$NOVUSC" || echo "$PWD/$NOVUSC")" ;; esac
export NOVUSC
UPDATE=0
FILTER=""
for argument in "$@"; do
    if [ "$argument" = "--update" ]; then
        UPDATE=1
        continue
    fi
    FILTER="$argument"
done
cd "$HERE"
pass=0
failed=0
for test in *.nv; do
    name="${test%.nv}"
    [ "$name" = "project" ] && continue
    case "$name" in *"$FILTER"*) ;; *) continue ;; esac
    actual="$("$NOVUSC" run "$test" 2>&1)"
    if [ "$UPDATE" = 1 ]; then
        printf '%s\n' "$actual" > "$name.golden"
        echo "updated $name"
        continue
    fi
    if [ "$actual" = "$(cat "$name.golden" 2>/dev/null)" ]; then
        echo "ok   $name"
        pass=$((pass + 1))
        continue
    fi
    echo "FAIL $name"
    diff <(printf '%s\n' "$actual") "$name.golden" | head -20
    failed=$((failed + 1))
done
[ "$UPDATE" = 1 ] && exit 0
echo "$pass passed, $failed failed"
[ "$failed" = 0 ]
