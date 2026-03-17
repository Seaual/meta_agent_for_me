#!/usr/bin/env bash
# dim-1-format.sh — Sentinel Dimension 1: Format Compliance
# Runs independently, outputs results to $RESULT_FILE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

TARGET_DIR="${1:-.}"
RESULT_FILE="${2:-/tmp/sentinel-dim-1.txt}"
AGENT_DIR="$TARGET_DIR/.claude/agents"
SKILL_DIR="$TARGET_DIR/.claude/skills"
WORKSPACE="$TARGET_DIR/.claude/workspace"
CLAUDE_MD="$TARGET_DIR/CLAUDE.md"

echo -e "\n${BOLD}═══ Dimension 1: Format Compliance (max 10) ═══${NC}"

  echo -e "\n${BOLD}═══ 维度一：格式合规（满分 10）═══${NC}"

  local all_md_files=()
  while IFS= read -r -d '' f; do
    all_md_files+=("$f")
  done < <(find "$AGENT_DIR" "$SKILL_DIR" -name "*.md" -print0 2>/dev/null)

  if [[ ${#all_md_files[@]} -eq 0 ]]; then
    deduct 5 "未找到任何 .md 文件" "请确认 .claude/agents/ 和 .claude/skills/ 目录存在且非空"
    log_fail "未找到任何配置文件"
    return
  fi

  for f in "${all_md_files[@]}"; do
    local fname
    fname=$(basename "$f")

    # 1A. frontmatter 存在且闭合
    if ! has_frontmatter "$f"; then
      deduct 3 "[$fname] 缺少完整 YAML frontmatter（需要开头和结尾的 ---）" \
        "在文件第1行添加 ---，在字段结束后添加 ---"
      log_fail "[$fname] 缺少 frontmatter (-3)"
      continue  # frontmatter 不存在，后续字段检查无意义
    fi

    # 1B. name 字段
    local name_val
    name_val=$(get_field "$f" "name")
    if [[ -z "$name_val" ]]; then
      deduct 2 "[$fname] 缺少 name 字段" "添加 name: kebab-case-name"
      log_fail "[$fname] 缺少 name (-2)"
    elif ! echo "$name_val" | grep -qE "^[a-z][a-z0-9-]+$"; then
      deduct 2 "[$fname] name '$name_val' 不是 kebab-case（应为小写字母、数字、连字符）" \
        "将 name 改为 kebab-case 格式，如：${name_val,,}"
      log_warn "[$fname] name '$name_val' 不是 kebab-case (-2)"
    else
      # 1C. 文件名与 name 字段一致性
      local expected_fname="${name_val}.md"
      # 对 SKILL.md 跳过文件名检查（目录名代替文件名）
      if [[ "$fname" != "SKILL.md" ]] && [[ "$fname" != "$expected_fname" ]]; then
        deduct 1 "[$fname] 文件名与 name 字段不一致（name: $name_val，应为 $expected_fname）" \
          "将文件重命名为 $expected_fname，或修改 name 字段"
        log_warn "[$fname] 文件名与 name 不一致 (-1)"
      else
        log_pass "[$fname] name: $name_val"
      fi
    fi

    # 1D. description 字段
    local desc_content
    desc_content=$(awk '/^---$/{c++;next} c==1 && found && /^  /{print; next}
                        c==1 && /^description:/{found=1; next}
                        c==1 && /^[a-z]/ && found{exit}
                        c>=2{exit}' "$f")
    if ! grep -q "^description:" "$f"; then
      deduct 3 "[$fname] 缺少 description 字段" "添加 description: | 并按触发条件公式填写"
      log_fail "[$fname] 缺少 description (-3)"
    else
      local desc_lines
      desc_lines=$(echo "$desc_content" | grep -c "." || true)
      if [[ "$desc_lines" -lt 3 ]]; then
        deduct 1 "[$fname] description 过短（${desc_lines} 行，建议 ≥3 行）" \
          "补充触发场景、关键词和排除项"
        log_warn "[$fname] description 过短 (-1)"
      elif ! echo "$desc_content" | grep -qi "Do NOT\|不适用\|not use for\|排除"; then
        deduct 1 "[$fname] description 缺少排除项（Do NOT use for...）" \
          "添加：Do NOT use for: [排除场景]"
        log_warn "[$fname] description 无排除项 (-1)"
      else
        log_pass "[$fname] description 完整"
      fi
    fi

    # 1E. allowed-tools 字段
    local tools_val
    tools_val=$(get_field "$f" "allowed-tools")
    if [[ -z "$tools_val" ]]; then
      deduct 2 "[$fname] 缺少 allowed-tools 字段" "添加 allowed-tools: Read"
      log_fail "[$fname] 缺少 allowed-tools (-2)"
    else
      local valid_tools="Read Write Edit Bash Grep Glob WebFetch WebSearch"
      local invalid_found=false
      IFS=', ' read -ra tool_list <<< "$tools_val"
      for t in "${tool_list[@]}"; do
        t=$(echo "$t" | tr -d '[:space:]')
        [[ -z "$t" ]] && continue
        if ! echo "$valid_tools" | grep -qw "$t"; then
          deduct 2 "[$fname] 无效工具名：'$t'（有效：$valid_tools）" \
            "将 '$t' 替换为有效工具名"
          log_fail "[$fname] 无效工具 '$t' (-2)"
          invalid_found=true
        fi
      done
      $invalid_found || log_pass "[$fname] allowed-tools: $tools_val"
    fi

    # 1F. Agent 提示词结构层次（仅 agents/）
    if [[ "$f" == *"/agents/"* ]]; then
      local body_content
      body_content=$(awk '/^---$/{c++;next} c>=2{print}' "$f")
      local layer_count=0
      echo "$body_content" | grep -qi "身份\|你是.*的\|你是.*组的\|Layer 1\|你的.*使命\|you are" && (( layer_count++ )) || true
      echo "$body_content" | grep -qi "执行\|步骤\|Step\|Framework\|流程\|Layer 3" && (( layer_count++ )) || true
      echo "$body_content" | grep -qi "输出\|Output\|Format\|格式\|Layer 4\|写入" && (( layer_count++ )) || true

      if [[ "$layer_count" -lt 2 ]]; then
        deduct 2 "[$fname] Agent 提示词结构层次不足（找到 $layer_count/3 个关键层）" \
          "确保包含：身份定义、执行步骤、输出规范"
        log_warn "[$fname] 提示词结构不足 (-2)"
      else
        log_pass "[$fname] 提示词结构层次：$layer_count/3"
      fi

      # 1G. 执行模型合规检查（v7）
      local has_bash_polling=false
      # 检查 bash 轮询
      grep -qE "wait_for_file|while.*\!.*-f.*sleep|while.*sleep.*done" "$f" && has_bash_polling=true
      # 检查 exit 1 作为流程控制（排除注释和检查规则引用）
      grep -v "^#\|🔴\|禁止" "$f" | grep -q "exit 1" && has_bash_polling=true

      if $has_bash_polling; then
        deduct 2 "[$fname] 包含 bash 轮询或 exit 1 流程控制，违反 v7 执行模型" \
          "将依赖检查改为自然语言：「检查 X 文件是否存在，如果不存在则停止」"
        log_fail "[$fname] 违反执行模型 (-2)"
      else
        log_pass "[$fname] 执行模型合规"
      fi
    fi

  done

echo -e "\n  ${BOLD}Dimension 1 score: $DIM_SCORE/10${NC}"
write_results "$RESULT_FILE"
