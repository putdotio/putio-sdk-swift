#!/usr/bin/env bash

set -euo pipefail

minimum_percent="${1:-90}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"

cd "$repo_root"

# SwiftPM owns the build layout (it moved under .build/out in Xcode 27), so ask
# it for the llvm-cov JSON export path instead of searching .build.
coverage_json="$(swift test --show-codecov-path --enable-code-coverage)"

if [ ! -f "$coverage_json" ]; then
    echo "Coverage report is missing. Run 'swift test --enable-code-coverage --filter PutioSDKTests' first."
    exit 1
fi

python3 - "$coverage_json" "$repo_root" "$minimum_percent" <<'PY'
import json
import pathlib
import sys

coverage_path = pathlib.Path(sys.argv[1])
repo_root = pathlib.Path(sys.argv[2]).resolve()
minimum_ratio = float(sys.argv[3]) / 100.0
source_root = repo_root / "PutioSDK" / "Classes"

payload = json.loads(coverage_path.read_text())

covered = 0
total = 0

for item in payload["data"][0]["files"]:
    filename = pathlib.Path(item["filename"]).resolve()
    try:
        filename.relative_to(source_root)
    except ValueError:
        continue

    summary = item["summary"]["lines"]
    covered += int(summary["covered"])
    total += int(summary["count"])

if total == 0:
    print("No PutioSDK source files were found in the coverage report.")
    sys.exit(1)

ratio = covered / total
print(f"PutioSDK source line coverage: {covered}/{total} ({ratio:.2%})")

if ratio + 1e-12 < minimum_ratio:
    print(f"Expected at least {minimum_ratio:.2%} source line coverage.")
    sys.exit(1)
PY
