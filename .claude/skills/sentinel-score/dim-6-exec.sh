#!/usr/bin/env bash
# dim-6-exec.sh — Sentinel Dimension 6: Executability
# Runs independently, outputs results to $RESULT_FILE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

TARGET_DIR="${1:-.}"
RESULT_FILE="${2:-/tmp/sentinel-dim-6.txt}"
AGENT_DIR="$TARGET_DIR/.claude/agents"
SKILL_DIR="$TARGET_DIR/.claude/skills"
WORKSPACE="$TARGET_DIR/.claude/workspace"
CLAUDE_MD="$TARGET_DIR/CLAUDE.md"

echo -e "\n${BOLD}═══ Dimension 6: Executability (max 10) ═══${NC}"

  echo -e "\n${BOLD}═══ 维度六：可执行性（满分 10）═══${NC}"

  # 6A. workspace 路径引用实际可写
  echo -e "\n  检查 workspace 路径有效性..."
  local ws_dir="$TARGET_DIR/.claude/workspace"
  local agent_count_d6
  agent_count_d6=$(find "$AGENT_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

  if [[ ! -d "$ws_dir" ]]; then
    # 单 agent 且声明无需 workspace 时不扣分
    local no_workspace_needed=false
    if [[ "$agent_count_d6" -le 1 ]] && [[ -f "$CLAUDE_MD" ]] && \
       grep -qi "无需.*workspace\|无.*workspace.*传递\|单.*Agent\|无并行\|简化协议" "$CLAUDE_MD"; then
      no_workspace_needed=true
    fi

    if $no_workspace_needed; then
      log_info "单 Agent 团队无需 workspace 目录（不扣分）"
    else
      deduct 2 ".claude/workspace/ 目录不存在" \
        "运行 toolsmith-infra 创建目录结构，或手动 mkdir -p .claude/workspace"
      log_fail ".claude/workspace/ 不存在 (-2)"
    fi
  else
    log_pass ".claude/workspace/ 目录存在"
  fi

  # 6B. 工具最小权限审查（有 Bash 权限但提示词没说明原因）
  echo -e "\n  检查工具权限合理性..."
  local bash_without_reason=0
  while IFS= read -r -d '' f; do
    local fname tools body
    fname=$(basename "$f")
    tools=$(get_field "$f" "allowed-tools")
    body=$(awk '/^---$/{c++;next} c>=2{print}' "$f")

    if echo "$tools" | grep -qw "Bash"; then
      # 检查提示词正文是否说明了 Bash 的使用场景
      if ! echo "$body" | grep -qi "bash\|执行命令\|run script\|\.sh\b\|shell\|脚本"; then
        deduct 1 "[$fname] 有 Bash 权限但未说明使用场景" \
          "在提示词中明确「何时/为何使用 Bash」"
        log_warn "[$fname] Bash 权限无说明 (-1)"
        (( bash_without_reason++ )) || true
      fi
    fi

    # Write 权限但没有 Edit——可能过于宽泛
    if echo "$tools" | grep -qw "Write" && ! echo "$tools" | grep -qw "Edit"; then
      if echo "$body" | grep -qi "创建新文件\|从零生成\|overwrite\|覆盖"; then
        log_pass "[$fname] Write 权限有说明（需创建新文件）"
      else
        log_warn "[$fname] 有 Write 但无 Edit，建议改用 Edit（精确修改）"
        # 仅警告，不扣分
      fi
    fi
  done < <(find "$AGENT_DIR" -name "*.md" -print0 2>/dev/null)
  [[ "$bash_without_reason" -eq 0 ]] && log_pass "所有 Bash 权限均有说明"

  # 6C. done.txt 完成标记机制
  echo -e "\n  检查完成标记机制..."
  local agents_with_done=0
  local agents_needing_done=0

  while IFS= read -r -d '' f; do
    local fname body
    fname=$(basename "$f" .md)
    body=$(awk '/^---$/{c++;next} c>=2{print}' "$f")

    # 判断是否是并行 agent（有 context: fork）
    if grep -q "^context: fork" "$f"; then
      (( agents_needing_done++ )) || true
      if echo "$body" | grep -qE "done\.txt|done\"|完成标记|toolsmith.*done"; then
        (( agents_with_done++ )) || true
        log_pass "[$fname] 有 done.txt 完成标记"
      else
        deduct 2 "[$fname] 并行 agent（context: fork）未写入完成标记" \
          "在最后一步写入：echo 'done' > .claude/workspace/${fname}-done.txt"
        log_fail "[$fname] 缺少 done.txt 标记 (-2)"
      fi
    fi
  done < <(find "$AGENT_DIR" -name "*.md" -print0 2>/dev/null)

  if [[ "$agents_needing_done" -eq 0 ]]; then
    log_info "无并行 agent，跳过 done.txt 检查"
  fi

  # 6D. 每个 skill 有入口文件（SKILL.md 存在）
  echo -e "\n  检查 Skill 入口文件..."
  local skill_dirs=()
  while IFS= read -r -d '' d; do
    skill_dirs+=("$d")
  done < <(find "$SKILL_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

  if [[ ${#skill_dirs[@]} -eq 0 ]]; then
    # 检查是否为设计上的零 skill 团队（CLAUDE.md 或 README 中明确声明无 skill）
    local intentionally_no_skills=false
    if [[ -f "$CLAUDE_MD" ]] && grep -qi "无需.*skill\|无.*skill\|0.*skill\|无独立.*Skill\|不需要.*skill\|逻辑内置\|内聚于" "$CLAUDE_MD"; then
      intentionally_no_skills=true
    fi
    if [[ -f "$TARGET_DIR/README.md" ]] && grep -qi "无需.*skill\|无.*skill\|0.*skill\|Skill.*无\|不需要.*skill" "$TARGET_DIR/README.md"; then
      intentionally_no_skills=true
    fi

    if $intentionally_no_skills; then
      log_info ".claude/skills/ 为空，但 CLAUDE.md/README 声明无需 Skill（设计意图，不扣分）"
    else
      deduct 2 ".claude/skills/ 目录为空或不存在" \
        "运行 toolsmith-skills 生成 skill 文件，或在 CLAUDE.md 中声明无需 Skill"
      log_fail "skills 目录为空 (-2)"
    fi
  else
    for d in "${skill_dirs[@]}"; do
      local skill_name
      skill_name=$(basename "$d")
      if [[ ! -f "$d/SKILL.md" ]]; then
        deduct 2 "[skill:$skill_name] 目录存在但缺少 SKILL.md" \
          "在 $d/ 创建 SKILL.md"
        log_fail "[skill:$skill_name] 缺少 SKILL.md (-2)"
      else
        log_pass "[skill:$skill_name] SKILL.md 存在"
      fi
    done
  fi

  # 6E. output-dir.txt 存在（并行 Toolsmith 的依赖）
  echo -e "\n  检查关键 workspace 文件..."
  local ws_meta_files=(
    "output-dir.txt:toolsmith-infra 写入，并行 Toolsmith 读取"
  )
  for entry in "${ws_meta_files[@]}"; do
    local wf="${entry%%:*}"
    local desc="${entry##*:}"
    if [[ -f "$WORKSPACE/$wf" ]]; then
      log_pass "workspace/$wf 存在"
    else
      # 仅在并行 agent 存在时才检查
      if find "$AGENT_DIR" -name "*.md" -exec grep -l "context: fork" {} \; 2>/dev/null | grep -q .; then
        deduct 1 "workspace/$wf 不存在（$desc）" \
          "确认 toolsmith-infra 已执行完毕"
        log_warn "workspace/$wf 缺失 (-1)"
      fi
    fi
  done

  # 6F. 执行可销性：teardown 步骤是否存在
  echo -e "\n  检查执行可销性（teardown）..."

  # 检查 README.md 是否包含清理/卸载说明
  local readme="$TARGET_DIR/README.md"
  if [[ -f "$readme" ]]; then
    if grep -qi "清理\|teardown\|卸载\|uninstall\|cleanup\|clean up\|删除\|remove" "$readme"; then
      log_pass "README.md 含 teardown/清理 说明"
    else
      deduct 2 "README.md 缺少 teardown 说明（用完后如何清理）" \
        "在 README.md 中添加「清理与卸载」章节，说明：workspace 清理命令、MCP 卸载步骤、全局 skill 移除方式"
      log_fail "README.md 无 teardown 说明 (-2)"
    fi
  fi

  # 检查 CLAUDE.md 降级规则是否包含 workspace 清理指导
  if [[ -f "$CLAUDE_MD" ]]; then
    if grep -qi "workspace.*clean\|清理.*workspace\|rm.*workspace\|workspace.*删除" "$CLAUDE_MD"; then
      log_pass "CLAUDE.md 有 workspace 清理指导"
    else
      log_warn "CLAUDE.md 未提及 workspace 清理方式（建议补充）"
      # 不扣分，仅警告
    fi
  fi

  # 检查 MCP 集成是否有对应的卸载说明
  # 先排除否定表达（"不需要 MCP"、"无 MCP"、"No MCP"），避免误报
  local has_real_mcp=false
  if [[ -f "$CLAUDE_MD" ]] && grep -qi "mcpServers\|MCP" "$CLAUDE_MD"; then
    # 检查是否仅为否定表达
    if grep -qi "不需要.*MCP\|无.*MCP\|No MCP\|不依赖.*MCP\|无需.*MCP\|without MCP" "$CLAUDE_MD"; then
      # 还需确认是否同时有真实的 mcpServers 配置
      if grep -q "mcpServers" "$CLAUDE_MD"; then
        has_real_mcp=true
      else
        log_info "CLAUDE.md 提及 MCP 但为否定表达（无需 MCP），跳过卸载检查"
      fi
    else
      has_real_mcp=true
    fi
  fi

  if $has_real_mcp; then
    if [[ -f "$readme" ]] && grep -qi "mcp.*卸载\|uninstall.*mcp\|remove.*mcp\|mcp.*remove\|mcp.*clean" "$readme"; then
      log_pass "README.md 有 MCP 卸载说明"
    else
      deduct 1 "有 MCP 集成但 README.md 缺少 MCP 卸载说明" \
        "在 README.md 的「清理与卸载」章节中说明如何从 settings.json 移除 mcpServers 配置"
      log_warn "缺少 MCP 卸载说明 (-1)"
    fi
  fi

  # 检查并行 agent 的 done.txt 是否有配套的清理逻辑（workspace-init 或 clean 步骤）
  local has_workspace_init=false
  if find "$SKILL_DIR" -name "SKILL.md" -exec grep -l "workspace.*init\|清空.*workspace\|clean.*workspace\|workspace-init" {} \; \
      2>/dev/null | grep -q .; then
    has_workspace_init=true
    log_pass "有 workspace-init 或清理 skill"
  fi

  # 如果没有任何清理机制（无 workspace-init skill 且 README 无 teardown）
  if ! $has_workspace_init && [[ -f "$readme" ]] && \
      ! grep -qi "清理\|cleanup\|teardown" "$readme"; then
    deduct 1 "未找到任何 workspace 清理机制（workspace-init skill 或 README teardown 说明）" \
      "添加 workspace-init skill 或在 README 中提供清理命令：rm -f .claude/workspace/phase-*.md"
    log_warn "无 workspace 清理机制 (-1)"
  fi

  # 6G. gitignore 建议（workspace 目录不应提交版本控制）
  echo -e "\n  检查 .gitignore 建议..."
  local gitignore="$TARGET_DIR/.gitignore"
  if [[ -f "$gitignore" ]]; then
    if grep -q "workspace\|\.claude/workspace" "$gitignore"; then
      log_pass ".gitignore 已排除 workspace 目录"
    else
      log_warn ".gitignore 未排除 .claude/workspace/（运行时数据不应提交）"
      # 不扣分，仅警告
    fi
  else
    log_warn "未找到 .gitignore（建议创建并排除 .claude/workspace/）"
    # 不扣分，仅警告
  fi

  # 6H. 团队入口 SKILL.md 检查（v7 新增）
  echo -e "\n  检查团队入口 SKILL.md..."
  local team_skill_found=false
  while IFS= read -r -d '' skill_dir; do
    local dir_name
    dir_name=$(basename "$skill_dir")
    # 跳过已知的通用 skill（self-improving-agent 等）
    if [[ "$dir_name" != "self-improving-agent" ]] && [[ -f "$skill_dir/SKILL.md" ]]; then
      local skill_name
      skill_name=$(get_field "$skill_dir/SKILL.md" "name")
      if [[ -n "$skill_name" ]]; then
        team_skill_found=true
        log_pass "团队入口 SKILL.md: $dir_name ($skill_name)"
      fi
    fi
  done < <(find "$SKILL_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

  if ! $team_skill_found; then
    deduct 1 "缺少团队入口 SKILL.md（toolsmith-assembler Step 3c 应自动生成）" \
      "在 .claude/skills/[team-name]/ 下创建入口 SKILL.md"
    log_warn "缺少团队入口 SKILL.md (-1)"
  fi

echo -e "\n  ${BOLD}Dimension 6 score: $DIM_SCORE/10${NC}"
write_results "$RESULT_FILE"
