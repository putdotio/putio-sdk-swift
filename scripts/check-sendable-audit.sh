#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

source_root="PutioSDK/Classes"
strict_test_file="Tests/PutioSDKStrictConcurrencyTests/PutioSDKStrictConcurrencyTests.swift"

if [ ! -f "$strict_test_file" ]; then
    echo "Missing $strict_test_file. Run this from the repo root."
    exit 1
fi

python3 - "$repo_root" "$source_root" "$strict_test_file" <<'PY'
import pathlib
import re
import sys

repo_root = pathlib.Path(sys.argv[1]).resolve()
source_root = repo_root / sys.argv[2]
strict_test_file = repo_root / sys.argv[3]

declaration_pattern = re.compile(r"^public (?:struct|enum)\s+([A-Za-z0-9_]+)")
sendable_pattern = re.compile(r"\bSendable\b")

# `public struct|enum` declarations under PutioSDK/Classes that explicitly conform
# to `Sendable`. Conformances can span multiple lines before the opening `{`
# (see PutioSDKError), so accumulate the header text until `{` shows up.
sendable_types = []
for path in sorted(source_root.rglob("*.swift")):
    lines = path.read_text().splitlines()
    index = 0
    while index < len(lines):
        line = lines[index]
        match = declaration_pattern.match(line)
        if not match:
            index += 1
            continue

        header_lines = [line]
        cursor = index
        while "{" not in header_lines[-1] and cursor + 1 < len(lines):
            cursor += 1
            header_lines.append(lines[cursor])

        header = "\n".join(header_lines)
        header_before_body = header.split("{", 1)[0]
        if sendable_pattern.search(header_before_body):
            sendable_types.append(match.group(1))

        index = cursor + 1

test_source = strict_test_file.read_text()
audited_types = set(re.findall(r"requireSendable\(([A-Za-z0-9_]+)\.self\)", test_source))

missing = sorted(set(sendable_types) - audited_types)

print(
    f"Sendable audit: {len(audited_types)} type(s) audited, "
    f"{len(sendable_types)} public Sendable type(s) found under {source_root.relative_to(repo_root)}."
)

if missing:
    print("Missing from requireSendable(...) in " f"{strict_test_file.relative_to(repo_root)}:")
    for name in missing:
        print(f"  - {name}")
    sys.exit(1)
PY
