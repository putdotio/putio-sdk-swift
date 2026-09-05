import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
lines = path.read_text().splitlines()
# `self.` member access, or a bare `config`/`delegate` identifier that is not an
# argument label (`config:`), a member (`.config`), or a metatype (`Foo.self`).
forbidden = re.compile(r"(?<![.\w])self\.|(?<![.\w])(config|delegate)\b(?!\s*:)")
failures = []
concurrent_bodies = 0


def strip_comment(line):
    return line.split("//", 1)[0]


index = 0
while index < len(lines):
    if lines[index].strip() != "@concurrent":
        index += 1
        continue

    header_start = index + 1
    cursor = header_start
    while "{" not in lines[cursor]:
        cursor += 1
    header = " ".join(l.strip() for l in lines[header_start : cursor + 1])
    if re.search(r"\bfunc request\b", header):
        failures.append(f"line {header_start + 1}: `request` must stay caller-isolated, not @concurrent")

    depth = 0
    body_start = cursor
    while True:
        code = strip_comment(lines[cursor])
        depth += code.count("{") - code.count("}")
        if cursor > body_start:
            for match in forbidden.finditer(code):
                failures.append(
                    f"line {cursor + 1}: `{match.group(0).rstrip('.')}` read inside @concurrent body: {lines[cursor].strip()}"
                )
        if depth == 0:
            break
        cursor += 1
    concurrent_bodies += 1
    index = cursor + 1

if not any(re.search(r"\bfunc request<", l) for l in lines):
    failures.append("could not find `func request<` declaration")

print(f"Transport isolation audit: {concurrent_bodies} @concurrent body(ies) checked in {path}.")
if concurrent_bodies == 0:
    failures.append("expected at least one @concurrent transport body")

if failures:
    for failure in failures:
        print(f"  - {failure}")
    sys.exit(1)
