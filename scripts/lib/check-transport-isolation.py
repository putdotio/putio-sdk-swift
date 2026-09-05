"""Structural audit for the transport isolation contract in PutioSDK.swift.

Usage: check-transport-isolation.py <swift-file>

Rules (see docs/ARCHITECTURE.md, "Internal transport isolation"):
  * `request` must not be `@concurrent`; it snapshots `config`/`delegate` on the
    caller's actor.
  * `perform` and `execute` must both be `@concurrent`.
  * No `@concurrent` body may use `self.` member access or read `config` or
    `delegate`. Only argument-label positions (`f(config: x)`, `f(config y: x)`)
    are exempt; ternary operands and other expressions are not.

Comments, string literal text (including multi-line and raw strings), and
extended regex literals (`#/.../#`) are blanked before parsing so they cannot
hide or fake a match. Interpolation expressions are executable Swift and are
lexed with the same rules, including comments and nested strings inside them.
Bare `/regex/` literals are not handled: the library target compiles in Swift 5
mode without `BareSlashRegexLiterals`, so they cannot appear in this file.
"""

import re
import sys
from pathlib import Path

REQUIRED_CONCURRENT = {"perform", "execute"}
FORBIDDEN_CONCURRENT = {"request"}
SELF_MEMBER = re.compile(r"(?<![.\w])self\s*[?!]?\s*\.")
STATE_IDENT = re.compile(r"(?<![.\w])(config|delegate)\b")
LABEL_AFTER = re.compile(r"\s*(?:[A-Za-z_]\w*\s*)?:(?!:)")
FUNC_DECL = re.compile(r"\bfunc\s+([A-Za-z_]\w*)")


def blank(ch):
    return "\n" if ch == "\n" else " "


def lex(source, i, out, until_close_paren=False):
    """Copy code from `source[i:]` into `out` with comments and string text blanked.

    With `until_close_paren`, stop after the `)` that closes paren depth 0 and
    return the index past it; otherwise consume to the end.
    """
    n, depth = len(source), 0
    while i < n:
        if source.startswith("//", i):
            while i < n and source[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if source.startswith("/*", i):
            nested, j = 1, i + 2
            while j < n and nested:
                if source.startswith("/*", j):
                    nested, j = nested + 1, j + 2
                elif source.startswith("*/", j):
                    nested, j = nested - 1, j + 2
                else:
                    j += 1
            out.extend(blank(ch) for ch in source[i:j])
            i = j
            continue
        if source[i] in '#"':
            k, hashes = i, 0
            while k < n and source[k] == "#":
                k, hashes = k + 1, hashes + 1
            if k < n and source[k] == '"':
                i = scan_string(source, k, hashes, out)
                continue
            if hashes and k < n and source[k] == "/":
                i = scan_regex(source, k, hashes, out)
                continue
        ch = source[i]
        out.append(ch)
        i += 1
        if until_close_paren:
            if ch == "(":
                depth += 1
            elif ch == ")":
                if depth == 0:
                    return i
                depth -= 1
    return n


def scan_string(source, start, hashes, out):
    """Blank the literal text of the string opening at `start` (a quote), lexing
    interpolation expressions as code, and return the index past the string."""
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
                out.append(" (")
                j = lex(source, after + 1, out, until_close_paren=True)
            else:
                out.append(blank(source[after]) if after < n else " ")
                j = after + 1
            continue
        if source.startswith(closing, j):
            out.append('"')
            return j + len(closing)
        out.append(blank(source[j]))
        j += 1
    return n


def scan_regex(source, start, hashes, out):
    """Blank an extended regex literal opening at `start` (the slash) and return the
    index past its `/` + hashes terminator."""
    n = len(source)
    closing = "/" + "#" * hashes
    out.append("/")
    j = start + 1
    while j < n and not source.startswith(closing, j):
        out.append(blank(source[j]))
        j += 1
    out.append("/")
    return min(n, j + len(closing))


def strip_comments_and_strings(source):
    out = []
    lex(source, 0, out)
    return "".join(out)


def line_of(text, offset):
    return text.count("\n", 0, offset) + 1


def is_argument_label(text, match):
    before = text[: match.start()].rstrip()
    if not before or before[-1] not in "(,":
        return False
    return LABEL_AFTER.match(text, match.end()) is not None


def forbidden_reads(body):
    for match in SELF_MEMBER.finditer(body):
        yield match.start(), "self"
    for match in STATE_IDENT.finditer(body):
        if not is_argument_label(body, match):
            yield match.start(), match.group(1)


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
        for offset, what in sorted(forbidden_reads(body)):
            line = line_of(text, k + offset)
            failures.append(
                f"line {line}: `{what}` read inside @concurrent `{name}`: {lines[line - 1].strip()}"
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
