#!/usr/bin/env bash
# self-improving-setup.sh — 安装并配置 self-improving-agent skill
# 用法：bash .claude/scripts/self-improving-setup.sh <output_dir>
set -euo pipefail

OUTPUT_DIR="${1:?需要传入 OUTPUT_DIR 参数}"
SELF_IMPROVING=$(cat .claude/workspace/self-improving.txt 2>/dev/null || echo "no")

if [[ "$SELF_IMPROVING" != "yes" ]]; then
  echo "ℹ️  self-improving-agent 未启用，跳过"
  exit 0
fi

echo "=== 配置 self-improving-agent ==="
SKILL_SRC="$HOME/.claude/skills/self-improving-agent"

# 检查并安装
if [[ ! -d "$SKILL_SRC" ]]; then
  echo "⚠️  未安装，正在安装..."
  npx skills add openclaw/skills@self-improving-agent -a claude-code -g -y
fi

if [[ ! -d "$SKILL_SRC" ]]; then
  echo "🔴 安装失败，跳过（不影响其他文件生成）"
  echo "   手动安装：npx skills add openclaw/skills@self-improving-agent -a claude-code -g -y" \
    >> .claude/workspace/toolsmith-warnings.txt
  exit 0
fi

# 复制到 team
mkdir -p "$OUTPUT_DIR/.claude/skills"
cp -r "$SKILL_SRC" "$OUTPUT_DIR/.claude/skills/self-improving-agent"
echo "✅ self-improving-agent 已复制到 team"

# 初始化 .learnings/
mkdir -p "$OUTPUT_DIR/.learnings"
cat > "$OUTPUT_DIR/.learnings/README.md" << 'EOF'
# .learnings/ — 自我改进记录

此目录由 `self-improving-agent` skill 自动管理，请勿手动删除。

## 条目类型

| 前缀 | 含义 |
|-----|------|
| `LRN` | 经验教训——某类需求的最佳处理方式 |
| `ERR` | 错误记录——导致失败的操作模式 |
| `FEAT` | 功能需求——用户提出但当前不支持的能力 |

## 状态流转

`pending` → `reviewed` → `promoted`（融入 CLAUDE.md 或 CONVENTIONS.md）

## 注意

- `promoted` 条目已整合到配置文件，可归档但不要删除
- 建议将此目录加入版本控制以追踪学习历史
EOF

echo "✅ .learnings/ 已初始化"
