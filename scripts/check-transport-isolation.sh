#!/usr/bin/env bash
# Guards the #52 contract in PutioSDK/Classes/PutioSDK.swift: `request` stays
# caller-isolated and snapshots `config`/`delegate` on the caller's actor, and no
# `@concurrent` body reads `self`, `config`, or `delegate`. The library target
# compiles in Swift 5 mode, so the compiler would not catch an off-actor read.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

python3 scripts/lib/check-transport-isolation.py PutioSDK/Classes/PutioSDK.swift
