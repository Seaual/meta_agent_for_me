#!/usr/bin/env bash
# improvements-gen.sh — 生成 v2+ 的改进点.md
# 用法：bash .claude/scripts/improvements-gen.sh <output_dir> <next_version>
# 说明：v1 时自动跳过，无需外部判断
set -euo pipefail

OUTPUT_DIR="${1:?需要传入 OUTPUT_DIR 参数}"
NEXT_VERSION="${2:?需要传入 NEXT_VERSION 参数}"

TEAM_NAME=$(cat .claude/workspace/team-name.txt 2>/dev/null || echo "my_team")
TEAMS_DIR="${TEAM_NAME}_teams"
VERSION="v${NEXT_VERSION}"
PREV_VERSION="v$((NEXT_VERSION - 1))"
PREV_DIR="${TEAMS_DIR}/${TEAM_NAME}_teams_${PREV_VERSION}"

if [ "$NEXT_VERSION" -le 1 ]; then
  echo "ℹ️  v1 首版，无需生成改进点.md"
  exit 0
fi

if [ ! -d "$PREV_DIR" ]; then
  echo "⚠️  上一版本目录不存在：$PREV_DIR，跳过改进点.md 生成"
  exit 0
fi

CHANGE_REQUESTS=$(cat .claude/workspace/change-requests.md \
  2>/dev/null || echo "（未记录变更说明）")

cat > "$OUTPUT_DIR/改进点.md" << EOF
# ${TEAM_NAME}_teams_${VERSION} 改进说明

**基于版本**：${PREV_VERSION}
**生成时间**：$(date +%Y-%m-%d\ %H:%M)

## 用户提出的改进需求

${CHANGE_REQUESTS}

## 相比 ${PREV_VERSION} 的具体变更

### 新增
[列出本版本新增的 agent / skill / MCP]

### 修改
[列出修改的 agent 职责、权限或提示词变化]

### 删除
[列出移除的 agent / skill，及移除原因]

### 架构调整
[如协作拓扑有变化，在此说明]
EOF

echo "✅ 改进点.md 已生成：$OUTPUT_DIR/改进点.md"
