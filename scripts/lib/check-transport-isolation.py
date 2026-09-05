"""Structural audit for the transport isolation contract in PutioSDK.swift.

Usage: check-transport-isolation.py <swift-file>

Rules (see docs/ARCHITECTURE.md, "Internal transport isolation"):
  * `request` must not be `@concurrent`; it snapshots `config`/`delegate` on the
    caller's actor.
  * `perform` and `execute` must both be `@concurrent`.
  * No `@concurrent` body may use `self.` member access or a bare `config` or
    `delegate` identifier. Argument labels (`config:`) are allowed.

Comments and string literal text (including multi-line and raw strings) are
blanked before parsing so they cannot hide or fake a match. Interpolation
expressions inside strings are executable Swift and are kept for auditing.
"""

import re
import sys
from pathlib import Path

REQUIRED_CONCURRENT = {"perform", "execute"}
FORBIDDEN_CONCURRENT = {"request"}
FORBIDDEN_READ = re.compile(r"(?<![.\w])self\s*\.|(?<![.\w])(?:config|delegate)\b(?!\s*:)")
FUNC_DECL = re.compile(r"\bfunc\s+([A-Za-z_]\w*)")


def blank(text):
    return "".join("\n" if ch == "\n" else " " for ch in text)


def scan_string(source, start, hashes, out):
    """Blank the literal text of the string opening at `start` (a quote) into `out`,
    keeping interpolation expressions verbatim, and return the index past it."""
    n = len(source)
    multiline = source.startswith('"""', start)
    closing = ('"""' if multiline else '"') + "#" * hashes
    escape = "\\" + "#" * hashes
    j = start + (3 if multiline else 1)
    out.append('"')
    while j < n:
        if source.startswith(escape, j):
            after = j + len(escape)
            if source.startswith("(", after):
                depth, k = 1, after + 1
                out.append(" (")
                while k < n and depth:
                    ch = source[k]
                    if ch == '"':
                        k = scan_string(source, k, 0, out)
                        continue
                    depth += (ch == "(") - (ch == ")")
                    out.append(ch)
                    k += 1
                j = k
            else:
                out.append("\n" if source[after : after + 1] == "\n" else " ")
                j = after + 1
            continue
        if source.startswith(closing, j):
            out.append('"')
            return j + len(closing)
        out.append("\n" if source[j] == "\n" else " ")
        j += 1
    return n


def strip_comments_and_strings(source):
    out, i, n = [], 0, len(source)
    while i < n:
        if source.startswith("//", i):
            j = source.find("\n", i)
            j = n if j == -1 else j
            out.append(blank(source[i:j]))
            i = j
            continue
        if source.startswith("/*", i):
            depth, j = 1, i + 2
            while j < n and depth:
                if source.startswith("/*", j):
                    depth, j = depth + 1, j + 2
                elif source.startswith("*/", j):
                    depth, j = depth - 1, j + 2
                else:
                    j += 1
            out.append(blank(source[i:j]))
            i = j
            continue
        if source[i] in '#"':
            k, hashes = i, 0
            while k < n and source[k] == "#":
                k, hashes = k + 1, hashes + 1
            if k < n and source[k] == '"':
                i = scan_string(source, k, hashes, out)
                continue
        out.append(source[i])
        i += 1
    return "".join(out)


def line_of(text, offset):
    return text.count("\n", 0, offset) + 1


def audit(path):
    original = path.read_text()
    text = strip_comments_and_strings(original)
    lines = original.splitlines()
    failures = []
    concurrent = {}

    for attr in re.finditer(r"@concurrent\b", text):
        decl = FUNC_DECL.search(text, attr.end())
        between = text[attr.end() : decl.start()] if decl else ""
        if not decl or re.search(r"[{};]", between):
            failures.append(f"line {line_of(text, attr.start())}: @concurrent is not attached to a func")
            continue
        name = decl.group(1)
        if name in concurrent:
            failures.append(f"line {line_of(text, decl.start())}: duplicate @concurrent func `{name}`")
        concurrent[name] = decl.start()

        depth, k = 0, decl.end()
        while k < len(text) and not (text[k] == "{" and depth == 0):
            depth += (text[k] == "(") - (text[k] == ")")
            k += 1
        if k >= len(text):
            failures.append(f"line {line_of(text, decl.start())}: could not find body of `{name}`")
            continue
        braces, end = 1, k + 1
        while end < len(text) and braces:
            braces += (text[end] == "{") - (text[end] == "}")
            end += 1
        if braces:
            failures.append(f"line {line_of(text, decl.start())}: unbalanced body for `{name}`")
            continue
        body = text[k:end]
        for match in FORBIDDEN_READ.finditer(body):
            line = line_of(text, k + match.start())
            failures.append(
                f"line {line}: `{match.group(0).rstrip(' .')}` read inside @concurrent `{name}`: {lines[line - 1].strip()}"
            )

    for name in sorted(FORBIDDEN_CONCURRENT & concurrent.keys()):
        failures.append(f"line {line_of(text, concurrent[name])}: `{name}` must stay caller-isolated, not @concurrent")
    for name in sorted(REQUIRED_CONCURRENT - concurrent.keys()):
        failures.append(f"`{name}` must be @concurrent")
    for name in sorted(REQUIRED_CONCURRENT | FORBIDDEN_CONCURRENT):
        if not re.search(r"\bfunc\s+" + name + r"\b", text):
            failures.append(f"could not find `func {name}` declaration")

    print(f"Transport isolation audit: {len(concurrent)} @concurrent body(ies) checked in {path}.")
    for failure in failures:
        print(f"  - {failure}")
    return not failures


if __name__ == "__main__":
    sys.exit(0 if audit(Path(sys.argv[1])) else 1)
