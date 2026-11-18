#!/usr/bin/env bash
# Enforces the Swift function-size limit (150 lines) for Sources/ and Tests/.
# The logic lives in check-function-size.py; see its docstring.
exec python3 "$(dirname "$0")/check-function-size.py" "$@"
