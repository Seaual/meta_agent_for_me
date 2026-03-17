#!/usr/bin/env bash
# version-manager.sh — 计算下一个版本号并设置 OUTPUT_DIR
# 用法：source .claude/scripts/version-manager.sh
# 输出：$VERSION $NEXT_VERSION $OUTPUT_DIR $TEAMS_DIR（供调用方使用）
set -euo pipefail

TEAM_NAME=$(cat .claude/workspace/team-name.txt 2>/dev/null || echo "my_team")
TEAMS_DIR="${TEAM_NAME}_teams"

if [ -d "$TEAMS_DIR" ]; then
  LAST_VERSION=$(ls -d "${TEAMS_DIR}/${TEAM_NAME}_teams_v"* 2>/dev/null \
    | grep -oE 'v[0-9]+$' \
    | grep -oE '[0-9]+' \
    | sort -n \
    | tail -1)
  NEXT_VERSION=$(( ${LAST_VERSION:-0} + 1 ))
else
  NEXT_VERSION=1
fi

VERSION="v${NEXT_VERSION}"
OUTPUT_DIR="${TEAMS_DIR}/${TEAM_NAME}_teams_${VERSION}"

echo "$VERSION" > .claude/workspace/team-version.txt
echo "本次生成版本：$VERSION → $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR/.claude/agents"
mkdir -p "$OUTPUT_DIR/.claude/skills"
mkdir -p "$OUTPUT_DIR/.claude/workspace"
