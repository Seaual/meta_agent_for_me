#!/usr/bin/env bash
# dim-5-quality.sh — Sentinel Dimension 5: Content Quality
# Runs independently, outputs results to $RESULT_FILE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

TARGET_DIR="${1:-.}"
RESULT_FILE="${2:-/tmp/sentinel-dim-5.txt}"
AGENT_DIR="$TARGET_DIR/.claude/agents"
SKILL_DIR="$TARGET_DIR/.claude/skills"
WORKSPACE="$TARGET_DIR/.claude/workspace"
CLAUDE_MD="$TARGET_DIR/CLAUDE.md"

echo -e "\n${BOLD}═══ Dimension 5: Content Quality (max 10) ═══${NC}"

  echo -e "\n${BOLD}═══ 维度五：内容质量（满分 10）═══${NC}"

  # 5A. Agent 提示词占位符检测
  echo -e "\n  检查占位符残留..."
  local placeholder_found=false
  while IFS= read -r -d '' f; do
    local fname body
    fname=$(basename "$f")
    body=$(awk '/^---$/{c++;next} c>=2{print}' "$f")

    # 检测常见占位符模式
    local placeholders
    placeholders=$(echo "$body" | grep -nE \
      '\[待填写\]|\[从规格提取\]|\[来自.*规格\]|TODO|PLACEHOLDER|\[name\]|\[职责\]|\[触发场景\]|\[列出' \
      | head -5 || true)

    if [[ -n "$placeholders" ]]; then
      deduct 2 "[$fname] 含未替换占位符：$(echo "$placeholders" | head -1)" \
        "替换所有 [] 占位符为实际内容"
      log_fail "[$fname] 占位符残留 (-2)"
      placeholder_found=true
    fi
  done < <(find "$AGENT_DIR" -name "*.md" -print0 2>/dev/null)
  $placeholder_found || log_pass "所有 agent 无占位符"

  # 5B. Prompt 具体性检查（Layer 3 是否有实际步骤）
  echo -e "\n  检查执行框架具体性..."
  while IFS= read -r -d '' f; do
    local fname body
    fname=$(basename "$f")
    body=$(awk '/^---$/{c++;next} c>=2{print}' "$f")

    # Layer 3 区域
    local layer3_content
    layer3_content=$(echo "$body" | awk '/Layer 3|执行框架|Step 1|## 执行/,/Layer 4|输出规范|## 输出/' | head -20)

    if [[ -z "$layer3_content" ]]; then
      deduct 2 "[$fname] 未找到执行框架（Layer 3）内容" \
        "添加包含具体步骤的 Layer 3 执行框架"
      log_fail "[$fname] 缺少执行框架 (-2)"
    else
      # 检查是否有实际步骤（Step N 或数字列表）
      local step_count
      step_count=$(echo "$layer3_content" | grep -cE "^Step [0-9]|^[0-9]+\." || true)
      if [[ "$step_count" -lt 2 ]]; then
        deduct 1 "[$fname] 执行框架步骤过少（${step_count} 步，建议 ≥2）" \
          "补充具体执行步骤"
        log_warn "[$fname] 执行步骤不足 (-1)"
      else
        log_pass "[$fname] 执行框架：${step_count} 步"
      fi
    fi
  done < <(find "$AGENT_DIR" -name "*.md" -print0 2>/dev/null)

  # 5C. 降级行为定义
  echo -e "\n  检查降级行为..."
  while IFS= read -r -d '' f; do
    local fname body
    fname=$(basename "$f")
    body=$(awk '/^---$/{c++;next} c>=2{print}' "$f")

    if ! echo "$body" | grep -qi "降级\|fallback\|失败\|error.md\|部分完成"; then
      deduct 1 "[$fname] 未定义降级行为（失败时怎么办）" \
        "添加「降级行为」章节：完全失败写 error.md，部分完成顶部标注"
      log_warn "[$fname] 缺少降级行为定义 (-1)"
    else
      log_pass "[$fname] 有降级行为"
    fi
  done < <(find "$AGENT_DIR" -name "*.md" -print0 2>/dev/null)

  # 5D. Skill 执行指令完整性
  echo -e "\n  检查 Skill 执行指令..."
  while IFS= read -r -d '' f; do
    local fname body
    fname=$(dirname "$f" | xargs basename)
    body=$(awk '/^---$/{c++;next} c>=2{print}' "$f")

    local line_count
    line_count=$(echo "$body" | grep -c "." || true)

    if [[ "$line_count" -lt 10 ]]; then
      deduct 2 "[skill:$fname] SKILL.md 内容过少（${line_count} 行，建议 ≥10 行）" \
        "补充执行步骤、输出格式和示例"
      log_fail "[skill:$fname] 内容不足 (-2)"
    else
      # 检查是否有实际可执行内容（bash 代码块或步骤）
      if ! echo "$body" | grep -q '```bash\|## 执行\|Step 1\|### Step'; then
        deduct 1 "[skill:$fname] SKILL.md 缺少可执行内容（bash 代码块或步骤说明）" \
          "添加 \`\`\`bash 代码块或明确的执行步骤"
        log_warn "[skill:$fname] 缺可执行内容 (-1)"
      else
        log_pass "[skill:$fname] 内容完整（${line_count} 行）"
      fi
    fi
  done < <(find "$SKILL_DIR" -name "SKILL.md" -print0 2>/dev/null)

  # 5C. 错误处理完整性检查（v7 新增）
  echo -e "\n  检查 agent 错误处理..."
  while IFS= read -r -d '' f; do
    local fname
    fname=$(basename "$f")
    local body
    body=$(awk '/^---$/{c++;next} c>=2{print}' "$f")

    # 检查是否有降级行为/错误处理章节
    local has_error_handling=false
    echo "$body" | grep -qiE "降级|degradation|error|失败|fallback|边界处理|edge case" && has_error_handling=true

    if ! $has_error_handling; then
      deduct 1 "[$fname] 未定义错误处理或降级行为" \
        "添加「降级行为」章节：完全失败写 error.md，部分完成顶部标注"
      log_fail "[$fname] 缺少错误处理 (-1)"
    else
      log_pass "[$fname] 有错误处理"
    fi

    # 检查是否有输入缺失处理
    local has_input_check=false
    echo "$body" | grep -qiE "不存在|缺失|missing|not exist|如果.*文件.*不" && has_input_check=true
    if ! $has_input_check; then
      deduct 1 "[$fname] 未定义输入缺失处理（依赖文件不存在时怎么办）" \
        "添加输入检查：「检查 X 文件是否存在，如果不存在则…」"
      log_warn "[$fname] 缺少输入检查 (-1)"
    fi
  done < <(find "$AGENT_DIR" -name "*.md" -print0 2>/dev/null)

  # 5D. 权限一致性检查（v7 新增）
  echo -e "\n  检查 agent 权限一致性..."
  while IFS= read -r -d '' f; do
    local fname
    fname=$(basename "$f")
    local tools_val
    tools_val=$(get_field "$f" "allowed-tools")
    local body
    body=$(awk '/^---$/{c++;next} c>=2{print}' "$f")

    # 检查：需要写文件但没有 Write 权限
    local needs_write=false
    echo "$body" | grep -qiE "写入|write.*to|输出.*文件|创建.*文件|output.*file|生成.*报告" && needs_write=true
    echo "$body" | grep -qiE "workspace/.*\.md\|workspace/.*\.txt\|workspace/.*\.json" \
      | grep -qiE "写入\|write\|output\|生成" 2>/dev/null && needs_write=true

    if $needs_write && ! echo "$tools_val" | grep -q "Write"; then
      deduct 2 "[$fname] 需要写文件但 allowed-tools 缺少 Write" \
        "在 frontmatter 中添加 Write 到 allowed-tools"
      log_fail "[$fname] 权限不一致：需 Write (-2)"
    fi

    # 检查：需要执行命令但没有 Bash 权限
    local needs_bash=false
    echo "$body" | grep -qiE "执行.*命令\|运行.*pytest\|运行.*npm\|pip-audit\|cargo audit\|git diff\|bash.*命令" && needs_bash=true

    if $needs_bash && ! echo "$tools_val" | grep -q "Bash"; then
      deduct 2 "[$fname] 需要执行命令但 allowed-tools 缺少 Bash" \
        "在 frontmatter 中添加 Bash 到 allowed-tools"
      log_fail "[$fname] 权限不一致：需 Bash (-2)"
    fi

    # 如果都一致
    if ! $needs_write || echo "$tools_val" | grep -q "Write"; then
      if ! $needs_bash || echo "$tools_val" | grep -q "Bash"; then
        log_pass "[$fname] 权限一致"
      fi
    fi
  done < <(find "$AGENT_DIR" -name "*.md" -print0 2>/dev/null)

echo -e "\n  ${BOLD}Dimension 5 score: $DIM_SCORE/10${NC}"
write_results "$RESULT_FILE"
