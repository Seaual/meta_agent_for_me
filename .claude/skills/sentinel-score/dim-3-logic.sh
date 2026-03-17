#!/usr/bin/env bash
# dim-3-logic.sh — Sentinel Dimension 3: Logic Feasibility
# Runs independently, outputs results to $RESULT_FILE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

TARGET_DIR="${1:-.}"
RESULT_FILE="${2:-/tmp/sentinel-dim-3.txt}"
AGENT_DIR="$TARGET_DIR/.claude/agents"
SKILL_DIR="$TARGET_DIR/.claude/skills"
WORKSPACE="$TARGET_DIR/.claude/workspace"
CLAUDE_MD="$TARGET_DIR/CLAUDE.md"

echo -e "\n${BOLD}═══ Dimension 3: Logic Feasibility (max 10) ═══${NC}"

  echo -e "\n${BOLD}═══ 维度三：逻辑一致性 & 可行性（满分 10）═══${NC}"

  # 3A. CLAUDE.md 必要章节
  if [[ ! -f "$CLAUDE_MD" ]]; then
    deduct 5 "根目录 CLAUDE.md 不存在" "创建 CLAUDE.md，包含团队成员、工作流程、上下文传递协议"
    log_fail "CLAUDE.md 不存在 (-5)"
  else
    # 检查 @CONVENTIONS.md 引用
    if grep -q "@CONVENTIONS.md" "$CLAUDE_MD"; then
      log_pass "CLAUDE.md 含 @CONVENTIONS.md 引用"
    else
      deduct 1 "CLAUDE.md 未引用 @CONVENTIONS.md" \
        "在 CLAUDE.md 顶部添加：@CONVENTIONS.md"
      log_warn "CLAUDE.md 缺少 @CONVENTIONS.md 引用 (-1)"
    fi

    # 检查 CONVENTIONS.md 文件本身存在
    if [[ ! -f "$TARGET_DIR/CONVENTIONS.md" ]]; then
      deduct 2 "CONVENTIONS.md 文件不存在" \
        "运行 ToolSmith 重新生成，CONVENTIONS.md 应在生成顺序第一步创建"
      log_fail "CONVENTIONS.md 不存在 (-2)"
    else
      log_pass "CONVENTIONS.md 存在"
    fi
    local required_sections=(
      "上下文传递协议:context.*pass\|workspace\|传递协议\|无需.*传递\|单.*Agent.*架构\|无并行\|无需.*workspace\|简化协议"
      "降级规则:降级\|fallback\|degradation"
      "工作流程:工作流\|workflow\|流程"
    )
    for entry in "${required_sections[@]}"; do
      local section_name="${entry%%:*}"
      local section_pattern="${entry##*:}"
      if grep -qi "$section_pattern" "$CLAUDE_MD"; then
        log_pass "CLAUDE.md 含「$section_name」"
      else
        deduct 2 "CLAUDE.md 缺少「$section_name」章节" \
          "添加 ## $section_name 章节，参考 Meta-Agents 模板"
        log_fail "CLAUDE.md 缺少「$section_name」(-2)"
      fi
    done
  fi

  # 3B. 工具充分性：每个 agent 声明的能力 vs 实际 allowed-tools
  echo -e "\n  检查工具权限充分性..."
  while IFS= read -r -d '' f; do
    local fname
    fname=$(basename "$f")
    local tools
    tools=$(get_field "$f" "allowed-tools")
    local body
    body=$(awk '/^---$/{c++;next} c>=2{print}' "$f")

    # 如果 agent 声明了写文件操作，但没有 Write 或 Edit
    if echo "$body" | grep -qi "写入\|create.*file\|generate.*file\|mkdir\|tee\b" \
      && ! echo "$tools" | grep -qE "Write|Edit"; then
      deduct 2 "[$fname] 描述了写文件操作，但 allowed-tools 无 Write/Edit" \
        "添加 Edit（推荐）或 Write 到 allowed-tools"
      log_fail "[$fname] 写文件但无 Write/Edit (-2)"
    fi

    # 如果 agent 声明了执行命令，但没有 Bash
    if echo "$body" | grep -qi "执行命令\|run.*script\|bash.*script\|shell.*command\|\.sh\b" \
      && ! echo "$tools" | grep -qw "Bash"; then
      deduct 2 "[$fname] 描述了执行脚本操作，但 allowed-tools 无 Bash" \
        "添加 Bash 到 allowed-tools（需说明使用理由）"
      log_fail "[$fname] 执行脚本但无 Bash (-2)"
    fi

    # 如果 agent 有 Bash 权限但未说明理由
    if echo "$tools" | grep -qw "Bash" \
      && ! echo "$body" | grep -qi "bash\|execute\|script\|command\|执行\|run"; then
      deduct 1 "[$fname] 有 Bash 权限但提示词中未说明使用场景" \
        "在提示词中明确说明何时使用 Bash"
      log_warn "[$fname] Bash 权限无说明 (-1)"
    fi

  done < <(find "$AGENT_DIR" -name "*.md" -print0 2>/dev/null)

  # 3D. README.md 存在且包含关键章节
  echo -e "\n  检查 README.md..."
  if [[ ! -f "$TARGET_DIR/README.md" ]]; then
    deduct 3 "根目录 README.md 不存在" \
      "运行 ToolSmith 重新生成，确保生成顺序最后一步包含 README.md"
    log_fail "README.md 不存在 (-3)"
  else
    local required_readme_sections=(
      "Team 成员\|Team Members\|成员"
      "文件树\|File Tree\|目录结构"
      "协作流程\|Workflow\|工作流"
      "快速启动\|Quick Start\|启动"
    )
    for section_pattern in "${required_readme_sections[@]}"; do
      local section_label="${section_pattern%%\\|*}"
      if grep -qi "$section_pattern" "$TARGET_DIR/README.md"; then
        log_pass "README.md 含「$section_label」"
      else
        deduct 1 "README.md 缺少「$section_label」章节" \
          "在 README.md 中添加 ## $section_label 章节"
        log_warn "README.md 缺「$section_label」(-1)"
      fi
    done

    # MCP 章节：仅当 CLAUDE.md 有真实 MCP 配置时才检查（排除否定表达）
    local d3_has_mcp=false
    if grep -qi "mcpServers\|MCP" "$CLAUDE_MD" 2>/dev/null; then
      if grep -qi "不需要.*MCP\|无.*MCP\|No MCP\|不依赖.*MCP\|无需.*MCP\|without MCP" "$CLAUDE_MD"; then
        grep -q "mcpServers" "$CLAUDE_MD" && d3_has_mcp=true
      else
        d3_has_mcp=true
      fi
    fi
    if $d3_has_mcp; then
      if grep -qi "MCP\|mcp" "$TARGET_DIR/README.md"; then
        log_pass "README.md 含 MCP 配置说明"
      else
        deduct 2 "CLAUDE.md 包含 MCP 配置，但 README.md 无对应说明章节" \
          "在 README.md 中添加 ## MCP 配置 章节，说明 Token 获取方式"
        log_fail "README.md 缺 MCP 章节 (-2)"
      fi
    fi
  fi
  echo -e "\n  检查 workspace 传递协议..."
  local agents_with_workspace=0
  local total_agents=0
  while IFS= read -r -d '' f; do
    (( total_agents++ )) || true
    grep -q "workspace" "$f" 2>/dev/null && (( agents_with_workspace++ )) || true
  done < <(find "$AGENT_DIR" -name "*.md" -print0 2>/dev/null)

  if [[ "$total_agents" -le 1 ]]; then
    log_info "单 Agent 团队，跳过 workspace 传递协议覆盖率检查"
  elif [[ "$total_agents" -gt 0 ]]; then
    local coverage=$(( agents_with_workspace * 100 / total_agents ))
    if [[ "$coverage" -lt 60 ]]; then
      deduct 2 "workspace 传递协议覆盖率低（${coverage}%，${agents_with_workspace}/${total_agents} 个 agent）" \
        "在每个 agent 的 Layer 4 输出规范中添加写入 workspace 的指令"
      log_fail "workspace 协议覆盖率 ${coverage}% (-2)"
    elif [[ "$coverage" -lt 80 ]]; then
      deduct 1 "workspace 传递协议覆盖率偏低（${coverage}%）" \
        "补充缺少 workspace 指令的 agent"
      log_warn "workspace 协议覆盖率 ${coverage}% (-1)"
    else
      log_pass "workspace 协议覆盖率 ${coverage}%"
    fi
  fi

echo -e "\n  ${BOLD}Dimension 3 score: $DIM_SCORE/10${NC}"
write_results "$RESULT_FILE"
