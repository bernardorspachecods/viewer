#!/usr/bin/env python3
"""Enforces the Swift function-size limit for Sources/ and Tests/.

A function, method, init, deinit or computed property body is measured from
its declaration line to its closing brace, inclusive. Each function over LIMIT
lines must be pinned in scripts/function-size-baseline.json by file and name
at its current length. A pin can only go down.

  check-function-size.sh               check; exit 1 on any violation
  check-function-size.sh --init        create the baseline, pinning every
                                       function over the limit (once)
  check-function-size.sh --update      lower pins to current lengths
  check-function-size.sh --self-test   prove the measurement and the rules

Nested functions are measured on their own and also count toward the
enclosing function. Comments, string literals (including multi-line strings
and interpolations) are masked before braces are counted.
"""
import json
import os
import re
import sys

LIMIT = 150
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BASELINE = os.path.join(ROOT, "scripts", "function-size-baseline.json")
SOURCE_DIRS = ("Sources", "Tests")
FIXTURE = os.path.join(ROOT, "scripts", "function-size-fixtures", "Sample.swift")

TOKEN_RE = re.compile(r"\n|[A-Za-z_][A-Za-z0-9_]*|\S")
IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
# Keywords that end a declaration waiting for its body at the same paren depth.
ENDS_PENDING = {"func", "var", "let", "case", "class", "struct", "enum",
                "extension", "protocol", "typealias", "init", "deinit"}
# Keywords that end a pending `var`: it is a statement, not a computed property.
ENDS_PENDING_VAR = {"in", "if", "guard", "while", "for", "="}


def mask(text):
    """Return text with comments and string contents replaced by spaces.

    Newlines are kept so line numbers stay correct. Code inside a \\( ... )
    interpolation is masked too, because it is part of the string.
    """
    out = []
    stack = [["code", 0, False]]  # [mode, paren depth, is_interpolation]
    i = 0
    n = len(text)

    def blank(ch):
        return "\n" if ch == "\n" else " "

    while i < n:
        mode = stack[-1]
        ch = text[i]
        two = text[i:i + 2]
        three = text[i:i + 3]
        if mode[0] == "comment":
            if two == "/*":
                mode[1] += 1
                out.append("  ")
                i += 2
            elif two == "*/":
                mode[1] -= 1
                out.append("  ")
                i += 2
                if mode[1] == 0:
                    stack.pop()
            else:
                out.append(blank(ch))
                i += 1
        elif mode[0] == "str":
            if mode[1] and three == '"""':
                stack.pop()
                out.append("   ")
                i += 3
            elif not mode[1] and ch == '"':
                stack.pop()
                out.append(" ")
                i += 1
            elif ch == "\\" and text[i + 1:i + 2] == "(":
                stack.append(["code", 0, True])
                out.append("  ")
                i += 2
            elif ch == "\\":
                escaped = text[i + 1:i + 2]
                out.append(" " + (blank(escaped) if escaped else ""))
                i += 1 + len(escaped)
            elif ch == "\n" and not mode[1]:
                stack.pop()  # unterminated single-line string
                out.append("\n")
                i += 1
            else:
                out.append(blank(ch))
                i += 1
        else:  # code
            if two == "/*":
                stack.append(["comment", 1, False])
                out.append("  ")
                i += 2
            elif two == "//":
                end = text.find("\n", i)
                end = n if end == -1 else end
                out.append(" " * (end - i))
                i = end
            elif three == '"""':
                stack.append(["str", 1, False])
                out.append("   ")
                i += 3
            elif ch == '"':
                stack.append(["str", 0, False])
                out.append(" ")
                i += 1
            elif mode[2]:  # inside \( ... ): everything is string content
                if ch == "(":
                    mode[1] += 1
                elif ch == ")":
                    if mode[1] == 0:
                        stack.pop()
                    else:
                        mode[1] -= 1
                out.append(blank(ch))
                i += 1
            else:
                out.append(ch)
                i += 1
    return "".join(out)


def tokenize(masked):
    tokens = []
    line = 1
    for match in TOKEN_RE.finditer(masked):
        token = match.group(0)
        if token == "\n":
            tokens.append(("\n", line))
            line += 1
        else:
            tokens.append((token, line))
    return tokens


def measure(text):
    """Return a sorted list of (name, start_line, end_line) for every body."""
    tokens = tokenize(mask(text))
    results = []
    stack = []  # None for other braces, or the pending declaration that owns them
    pending = None  # {"kind", "name", "line", "paren"}
    paren = 0
    prev = None

    def cancel_if_same_depth():
        nonlocal pending
        if pending and pending["paren"] == paren:
            pending = None

    for index, (token, line) in enumerate(tokens):
        nxt = tokens[index + 1][0] if index + 1 < len(tokens) else ""
        if token == "\n":
            if pending and pending["kind"] == "var" and pending["paren"] == paren:
                pending = None
        elif token == "(":
            paren += 1
        elif token == ")":
            paren = max(0, paren - 1)
        elif token == "{":
            if pending and pending["paren"] == paren:
                stack.append(pending)
                pending = None
            else:
                stack.append(None)
        elif token == "}":
            cancel_if_same_depth()
            if stack:
                owner = stack.pop()
                if owner is not None:
                    results.append((owner["name"], owner["line"], line))
        elif token == ";":
            cancel_if_same_depth()
        elif token in ENDS_PENDING_VAR:
            if pending and pending["kind"] == "var" and pending["paren"] == paren:
                pending = None
        elif token in ("func", "var", "init", "deinit"):
            is_member = token in ("func", "var") or nxt in ("(", "?", "!")
            if token in ("init", "deinit") and (prev == "." or not is_member):
                pass
            else:
                cancel_if_same_depth()
                if token in ("func", "var"):
                    name = nxt if IDENT_RE.match(nxt) else "?"
                else:
                    name = "init"
                kind = "var" if token == "var" else "func"
                pending = {"kind": kind, "name": name, "line": line, "paren": paren}
        elif token in ENDS_PENDING:
            cancel_if_same_depth()
        prev = token
    return sorted(results, key=lambda item: (item[1], item[2]))


def measure_file(path, relpath):
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    sizes = {}
    seen = {}
    for name, start, end in measure(text):
        seen[name] = seen.get(name, 0) + 1
        key = "%s::%s" % (relpath, name if seen[name] == 1 else "%s#%d" % (name, seen[name]))
        sizes[key] = {"lines": end - start + 1, "start": start}
    return sizes


def collect_sizes(root=ROOT):
    sizes = {}
    for directory in SOURCE_DIRS:
        base = os.path.join(root, directory)
        for dirpath, _, filenames in os.walk(base):
            for filename in filenames:
                if not filename.endswith(".swift"):
                    continue
                path = os.path.join(dirpath, filename)
                relpath = os.path.relpath(path, root).replace(os.sep, "/")
                sizes.update(measure_file(path, relpath))
    return sizes


def read_baseline(path=BASELINE):
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError("the baseline root must be a JSON object")
    for key, lines in data.items():
        if not isinstance(lines, int) or lines <= LIMIT:
            raise ValueError("invalid pin for %s: %r" % (key, lines))
    return data


def evaluate(sizes, baseline, limit=LIMIT):
    """Return (hard, soft) lists of messages. Hard: new or grown. Soft: shrank or stale pin."""
    hard, soft = [], []
    for key in sorted(sizes):
        lines = sizes[key]["lines"]
        if lines <= limit:
            continue
        if key not in baseline:
            hard.append("%s: %d lines, over the %d-line limit and not pinned. Split the function." % (key, lines, limit))
        elif lines > baseline[key]:
            hard.append("%s: %d lines, grew from its pin of %d. Split the function instead of growing it." % (key, lines, baseline[key]))
        elif lines < baseline[key]:
            soft.append("%s: %d lines, below its pin of %d. Lower the pin (check-function-size.sh --update)." % (key, lines, baseline[key]))
    for key in sorted(baseline):
        if key not in sizes or sizes[key]["lines"] <= limit:
            soft.append("%s: pinned but now within the limit or gone. Remove the pin (check-function-size.sh --update)." % key)
    return hard, soft


def write_baseline(sizes, baseline, path=BASELINE):
    pins = {}
    for key in sorted(baseline):
        if key in sizes and sizes[key]["lines"] > LIMIT:
            pins[key] = min(baseline[key], sizes[key]["lines"])
    serialized = json.dumps(pins, indent=2, sort_keys=True) + "\n"
    current = None
    if os.path.exists(path):
        with open(path, encoding="utf-8") as handle:
            current = handle.read()
    if current == serialized:
        return False
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(serialized)
    return True


def self_test():
    failures = []

    def expect(label, condition):
        if not condition:
            failures.append(label)

    with open(FIXTURE, encoding="utf-8") as handle:
        measured = {name: (start, end) for name, start, end in measure(handle.read())}
    expected = {
        "computed": (7, 10),
        "init": (16, 18),
        "withBraces": (19, 22),
        "nested": (23, 28),
        "inner": (24, 26),
        "bodiless": None,
        "afterBodiless": (30, 32),
    }
    for name, span in expected.items():
        if span is None:
            expect("fixture: %s must not be measured" % name, name not in measured)
        else:
            expect("fixture: %s span %s, expected %s" % (name, measured.get(name), span), measured.get(name) == span)
    expect("fixture: commented and multi-line-string functions are ignored",
           "commentOnly" not in measured and "notAFunction" not in measured)

    def sizes(**items):
        return {key: {"lines": value, "start": 1} for key, value in items.items()}

    cases = [
        ("new over-limit function fails", sizes(**{"a.swift::f": 151}), {}, 1, 0),
        ("grown pin fails", sizes(**{"a.swift::f": 160}), {"a.swift::f": 155}, 1, 0),
        ("shrunk pin asks to lower", sizes(**{"a.swift::f": 151}), {"a.swift::f": 155}, 0, 1),
        ("pin for a function now within limit asks to remove", sizes(**{"a.swift::f": 150}), {"a.swift::f": 155}, 0, 1),
        ("pin for a deleted function asks to remove", {}, {"a.swift::f": 155}, 0, 1),
        ("pinned function at its pin passes", sizes(**{"a.swift::f": 155}), {"a.swift::f": 155}, 0, 0),
        ("function at the limit passes", sizes(**{"a.swift::f": 150}), {}, 0, 0),
    ]
    for label, current, pinned, want_hard, want_soft in cases:
        hard, soft = evaluate(current, pinned)
        expect("%s: hard=%d soft=%d, expected hard=%d soft=%d" % (label, len(hard), len(soft), want_hard, want_soft),
               len(hard) == want_hard and len(soft) == want_soft)

    if failures:
        for failure in failures:
            print("SELF-TEST FAIL: " + failure, file=sys.stderr)
        return 1
    print("Function-size self-test OK (%d measurement and %d rule cases)." % (len(expected), len(cases)))
    return 0


def main(argv):
    mode = argv[1] if len(argv) > 1 else "check"
    if mode == "--self-test":
        return self_test()
    if mode not in ("check", "--check", "--update", "--init"):
        print("usage: check-function-size.sh [--update|--init|--self-test]", file=sys.stderr)
        return 2
    sizes = collect_sizes()
    if mode == "--init":
        if os.path.exists(BASELINE):
            print("Baseline already exists; --init does not replace it.", file=sys.stderr)
            return 1
        over = {key: info["lines"] for key, info in sizes.items() if info["lines"] > LIMIT}
        with open(BASELINE, "w", encoding="utf-8") as handle:
            handle.write(json.dumps(over, indent=2, sort_keys=True) + "\n")
        print("Function-size baseline created with %d pinned functions." % len(over))
        return 0
    baseline = read_baseline()
    hard, soft = evaluate(sizes, baseline)
    if mode == "--update":
        if hard:
            for message in hard:
                print(message, file=sys.stderr)
            print("Baseline not updated: fix the violations above first.", file=sys.stderr)
            return 1
        if write_baseline(sizes, baseline):
            print("Function-size baseline updated in scripts/function-size-baseline.json.")
        else:
            print("Function-size baseline already up to date.")
        return 0
    for message in hard + soft:
        print(message, file=sys.stderr)
    if hard or soft:
        return 1
    print("Function sizes OK (limit %d lines)." % LIMIT)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
