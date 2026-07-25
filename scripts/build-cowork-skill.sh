#!/usr/bin/env bash
# Build a skill ZIP for direct upload into Claude Cowork.
#
# Cowork can install this plugin two ways:
#   1. As a marketplace plugin (skill + command + subagent) — see README.
#   2. As a standalone *skill* uploaded via Customize → Skills → "+ Create skill".
#      That uploader wants a ZIP whose top-level entry is the skill folder
#      (the folder containing SKILL.md). This script builds exactly that.
#
# Usage:  ./scripts/build-cowork-skill.sh
# Output: dist/autoresearch-skill.zip
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_DIR="$ROOT/plugins/autoresearch-mlx/skills/autoresearch"
OUT_DIR="$ROOT/dist"
OUT_ZIP="$OUT_DIR/autoresearch-skill.zip"

if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
  echo "error: $SKILL_DIR/SKILL.md not found" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
rm -f "$OUT_ZIP"

# Zip with the skill folder ("autoresearch/…") at the ZIP root.
( cd "$(dirname "$SKILL_DIR")" && zip -r -q "$OUT_ZIP" "$(basename "$SKILL_DIR")" -x '*.DS_Store' )

echo "built $OUT_ZIP"
unzip -l "$OUT_ZIP"
