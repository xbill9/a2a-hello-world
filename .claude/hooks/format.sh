#!/usr/bin/env bash
# PostToolUse(Write|Edit): format the edited file with the formatter its subproject's `make format` uses.
# Formatters that aren't installed are skipped silently.
f=$(jq -r '.tool_response.filePath // .tool_input.file_path // empty')
[ -f "$f" ] || exit 0

case "$f" in
  */node_modules/*|*/target/*) exit 0 ;;
esac

case "$f" in
  *.rs)
    command -v rustfmt >/dev/null && rustfmt --edition 2024 "$f" ;;
  *.go)
    gofmt=$(command -v gofmt || echo "$(go env GOROOT 2>/dev/null)/bin/gofmt")
    [ -x "$gofmt" ] && "$gofmt" -w "$f" ;;
  *.py)
    if command -v black >/dev/null; then black -q "$f"
    elif python3 -m black --version >/dev/null 2>&1; then python3 -m black -q "$f"
    fi ;;
  */poly-node/*.ts)
    bin="${f%%/poly-node/*}/poly-node/node_modules/.bin/prettier"
    if [ -x "$bin" ]; then "$bin" --write "$f"
    elif command -v prettier >/dev/null; then prettier --write "$f"
    fi ;;
esac
exit 0
