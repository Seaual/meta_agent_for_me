#!/usr/bin/env bash
# self-improving-setup.sh — 安装并配置 self-improving-agent skill
# 用法：bash .claude/scripts/self-improving-setup.sh <output_dir>
# 支持：Windows (Git Bash) + Linux + macOS
set -euo pipefail

OUTPUT_DIR="${1:?需要传入 OUTPUT_DIR 参数}"
SELF_IMPROVING=$(cat .claude/workspace/self-improving.txt 2>/dev/null || echo "no")

if [[ "$SELF_IMPROVING" != "yes" ]]; then
  echo "ℹ️  self-improving-agent 未启用，跳过"
  exit 0
fi

echo "=== 配置 self-improving-agent ==="

# ── 步骤 1：查找已安装的 self-improving-agent skill ──

SKILL_SRC=""

# Windows 常见路径
for candidate in \
  "$HOME/.claude/skills/self-improving-agent" \
  "${USERPROFILE:-}/.claude/skills/self-improving-agent" \
  "${APPDATA:-}/../.claude/skills/self-improving-agent" \
  "${LOCALAPPDATA:-}/Claude/skills/self-improving-agent"; do
  if [[ -d "$candidate" ]] && [[ -f "$candidate/SKILL.md" ]]; then
    SKILL_SRC="$candidate"
    echo "✅ 在已知路径找到：$SKILL_SRC"
    break
  fi
done

# 通用搜索（如果上面都没找到）
if [[ -z "$SKILL_SRC" ]]; then
  echo "  在常见路径未找到，尝试搜索..."
  FOUND=$(find "$HOME" -maxdepth 5 -path "*/.claude/skills/self-improving-agent/SKILL.md" \
    -type f 2>/dev/null | head -1)
  if [[ -n "$FOUND" ]]; then
    SKILL_SRC=$(dirname "$FOUND")
    echo "✅ 搜索找到：$SKILL_SRC"
  fi
fi

# ── 步骤 2：如果未找到，尝试安装 ──

if [[ -z "$SKILL_SRC" ]]; then
  echo "⚠️  未找到已安装的 self-improving-agent，尝试安装..."

  # 修复 npx PATH（Windows 优先）
  if ! command -v npx &>/dev/null; then
    for win_path in \
      "${APPDATA:-}/npm" \
      "${LOCALAPPDATA:-}/Programs/nodejs" \
      "${ProgramFiles:-}/nodejs" \
      "C:/Program Files/nodejs" \
      "${HOME}/AppData/Roaming/npm"; do
      [[ -d "$win_path" ]] && export PATH="$PATH:$win_path"
    done
    [[ -n "${NVM_HOME:-}" ]] && export PATH="$PATH:$NVM_HOME"
    [[ -n "${NVM_SYMLINK:-}" ]] && export PATH="$PATH:$NVM_SYMLINK"
    export PATH="$PATH:/usr/local/bin"
    [[ -s "$HOME/.nvm/nvm.sh" ]] && source "$HOME/.nvm/nvm.sh"
  fi

  if command -v npx &>/dev/null; then
    echo "  执行：npx skills add openclaw/skills@self-improving-agent -a claude-code -g -y"
    npx skills add openclaw/skills@self-improving-agent -a claude-code -g -y 2>/dev/null || true

    # 安装后重新查找
    for candidate in \
      "$HOME/.claude/skills/self-improving-agent" \
      "${USERPROFILE:-}/.claude/skills/self-improving-agent"; do
      if [[ -d "$candidate" ]] && [[ -f "$candidate/SKILL.md" ]]; then
        SKILL_SRC="$candidate"
        echo "✅ 安装成功：$SKILL_SRC"
        break
      fi
    done
  else
    echo "⚠️  npx 不可用，无法自动安装"
  fi
fi

# ── 步骤 3：复制到项目或输出降级提示 ──

if [[ -n "$SKILL_SRC" ]]; then
  mkdir -p "$OUTPUT_DIR/.claude/skills"
  cp -r "$SKILL_SRC" "$OUTPUT_DIR/.claude/skills/self-improving-agent"
  echo "✅ self-improving-agent 已复制到 team"

  # 确保 CLAUDE.md 包含引用
  if [[ -f "$OUTPUT_DIR/CLAUDE.md" ]]; then
    if ! grep -q "@.claude/skills/self-improving-agent" "$OUTPUT_DIR/CLAUDE.md"; then
      sed -i '/@CONVENTIONS.md/a @.claude/skills/self-improving-agent/SKILL.md' "$OUTPUT_DIR/CLAUDE.md"
      echo "✅ CLAUDE.md 已添加 @self-improving-agent 引用"
    fi
  fi
else
  echo "🟡 self-improving-agent 未能安装，在 README 中补充手动安装说明"
  echo "SELF_IMPROVING_MISSING=true" >> .claude/workspace/toolsmith-warnings.txt
fi

# ── 步骤 4：初始化 .learnings/ ──

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
echo "=== self-improving-agent 配置完成 ==="
