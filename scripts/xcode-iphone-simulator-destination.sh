#!/bin/sh

set -eu

project=""
scheme=""
minimum_os="26.0"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project)
      project="$2"
      shift 2
      ;;
    --scheme)
      scheme="$2"
      shift 2
      ;;
    --minimum-os)
      minimum_os="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$project" ] || [ -z "$scheme" ]; then
  echo "Usage: $0 --project <project> --scheme <scheme> [--minimum-os <version>]" >&2
  exit 2
fi

xcodebuild -project "$project" -scheme "$scheme" -showdestinations 2>/dev/null | awk -v minimum_os="$minimum_os" '
function trim(value) {
  sub(/^[[:space:]]+/, "", value)
  sub(/[[:space:]]+$/, "", value)
  return value
}

function version_gte(current, minimum) {
  split(current, current_parts, ".")
  split(minimum, minimum_parts, ".")

  for (part = 1; part <= 3; part++) {
    if ((current_parts[part] + 0) > (minimum_parts[part] + 0)) {
      return 1
    }

    if ((current_parts[part] + 0) < (minimum_parts[part] + 0)) {
      return 0
    }
  }

  return 1
}

/\{ platform:iOS Simulator,/ {
  line = $0
  id = ""
  os = ""
  name = ""

  if (match(line, /id:[^,}]+/)) {
    id = trim(substr(line, RSTART + 3, RLENGTH - 3))
  }

  if (match(line, /OS:[^,}]+/)) {
    os = trim(substr(line, RSTART + 3, RLENGTH - 3))
  }

  if (match(line, /name:[^,}]+/)) {
    name = trim(substr(line, RSTART + 5, RLENGTH - 5))
  }

  if (id != "" && os != "" && name ~ /^iPhone/ && version_gte(os, minimum_os)) {
    printf "platform=iOS Simulator,id=%s\n", id
    found = 1
    exit 0
  }
}

END {
  if (!found) {
    exit 1
  }
}
'
