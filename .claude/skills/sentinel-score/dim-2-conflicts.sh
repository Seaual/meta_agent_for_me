#!/usr/bin/env bash
# dim-2-conflicts.sh — Sentinel Dimension 2: Agent Conflicts
# Runs independently, outputs results to $RESULT_FILE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

TARGET_DIR="${1:-.}"
RESULT_FILE="${2:-/tmp/sentinel-dim-2.txt}"
AGENT_DIR="$TARGET_DIR/.claude/agents"
SKILL_DIR="$TARGET_DIR/.claude/skills"
WORKSPACE="$TARGET_DIR/.claude/workspace"
CLAUDE_MD="$TARGET_DIR/CLAUDE.md"

echo -e "\n${BOLD}═══ Dimension 2: Agent Conflicts (max 10) ═══${NC}"

  echo -e "\n${BOLD}═══ 维度二：跨 Agent 协作冲突（满分 10）═══${NC}"

  # 2A. 收集所有 description 关键词，检测重叠
  declare -A agent_keywords
  local all_agents=()
  while IFS= read -r -d '' f; do
    all_agents+=("$f")
  done < <(find "$AGENT_DIR" -name "*.md" -print0 2>/dev/null)

  for f in "${all_agents[@]}"; do
    local aname
    aname=$(get_field "$f" "name")
    [[ -z "$aname" ]] && continue
    # 提取 description 中的触发词（Triggers on: 行之后的引号内容）
    local kw
    kw=$(grep -i "triggers on\|trigger on\|keywords" "$f" 2>/dev/null \
      | grep -oE '"[^"]{3,}"' \
      | tr -d '"' \
      | tr '\n' ' ' || echo "")
    agent_keywords["$aname"]="$kw"
  done

  # 两两比较关键词重叠
  local names=("${!agent_keywords[@]}")
  local conflict_found=false
  for (( i=0; i<${#names[@]}; i++ )); do
    for (( j=i+1; j<${#names[@]}; j++ )); do
      local a="${names[$i]}"
      local b="${names[$j]}"
      local kw_a="${agent_keywords[$a]:-}"
      local kw_b="${agent_keywords[$b]:-}"
      [[ -z "$kw_a" || -z "$kw_b" ]] && continue

      # 统计共同关键词数量
      local overlap_count=0
      for kw in $kw_a; do
        echo "$kw_b" | grep -qw "$kw" && (( overlap_count++ )) || true
      done

      if [[ "$overlap_count" -ge 3 ]]; then
        # 检查是否有互相指向的排除项（Do NOT use for 中提到对方名称）
        local mutual_exclusion=false
        local file_a="$AGENT_DIR/${a}.md"
        local file_b="$AGENT_DIR/${b}.md"
        if [[ -f "$file_a" ]] && [[ -f "$file_b" ]]; then
          local a_excludes_b=false
          local b_excludes_a=false
          # a 的 description 中 Do NOT use for 是否提到 b
          grep -qi "Do NOT use for\|不适用\|排除" "$file_a" 2>/dev/null \
            && grep -qi "$b\|$(echo "$b" | sed 's/-/ /g')" "$file_a" 2>/dev/null \
            && a_excludes_b=true
          # b 的 description 中 Do NOT use for 是否提到 a
          grep -qi "Do NOT use for\|不适用\|排除" "$file_b" 2>/dev/null \
            && grep -qi "$a\|$(echo "$a" | sed 's/-/ /g')" "$file_b" 2>/dev/null \
            && b_excludes_a=true
          $a_excludes_b && $b_excludes_a && mutual_exclusion=true
        fi

        if $mutual_exclusion; then
          # 有互相排除 → 同领域团队，降级为警告（-1 而非 -4）
          deduct 1 "[$a] 与 [$b] 共享 $overlap_count 个领域词，但有互相排除项（轻微警告）" \
            "当前排除项已足够区分两者，可进一步细化触发词"
          log_warn "[$a] <-> [$b] 领域词重叠 $overlap_count 个，有互相排除（-1）"
        else
          # 无互相排除 → 真正的冲突
          deduct 4 "[$a] 与 [$b] 触发词高度重叠（共 $overlap_count 个相同词），可能误触发" \
            "在重叠度更高的 agent 的 description 中增加排除项：Do NOT use for: [对方的专属场景]"
          log_fail "[$a] <-> [$b] 触发词重叠 $overlap_count 个 (-4)"
        fi
        conflict_found=true
      elif [[ "$overlap_count" -ge 1 ]]; then
        log_warn "[$a] <-> [$b] 有 $overlap_count 个共同词（可接受）"
      fi
    done
  done
  $conflict_found || log_pass "无严重触发词冲突"

  # 2B. workspace 输出文件名冲突
  echo -e "\n  检查 workspace 写入冲突..."
  declare -A workspace_writers  # file -> "agent1 agent2"
  local conflict_found_ws=false

  # 预先收集所有 agent 名称列表
  local all_agent_names=()
  while IFS= read -r -d '' f; do
    local n
    n=$(get_field "$f" "name")
    [[ -n "$n" ]] && all_agent_names+=("$n")
  done < <(find "$AGENT_DIR" -name "*.md" -print0 2>/dev/null)

  while IFS= read -r -d '' f; do
    local aname
    aname=$(get_field "$f" "name")
    [[ -z "$aname" ]] && continue

    while IFS= read -r ws_file; do
      [[ -z "$ws_file" ]] && continue
      echo "$ws_file" | grep -qE '\[|\$' && continue

      # ── 判断：这个 agent 是在读还是写这个文件？──

      local is_reader=false

      # 方法 1（最可靠）：文件名包含另一个 agent 的名字作为前缀
      # 例：minutes-drafter-output.md 被 minutes-reviewer 引用 → reviewer 是读者
      local basename_ws
      basename_ws=$(basename "$ws_file" .md)
      for other_agent in "${all_agent_names[@]}"; do
        if [[ "$other_agent" != "$aname" ]] && echo "$basename_ws" | grep -q "^${other_agent}"; then
          is_reader=true
          break
        fi
      done

      # 方法 2：agent 名称含 aggregator/reviewer/汇总/审查 → 该 agent 天然是上游输出的读者
      if ! $is_reader; then
        if echo "$aname" | grep -qiE "aggregat|reviewer|汇总|审查|summary|dashboard"; then
          # 检查该文件是否是其他 agent 的输出文件（文件名不含自己名字）
          if ! echo "$basename_ws" | grep -qi "$aname"; then
            is_reader=true
          fi
        fi
      fi

      # 方法 3：上下文关键词（兜底）
      if ! $is_reader; then
        local context_lines
        context_lines=$(grep -B3 -A3 "$ws_file" "$f" 2>/dev/null || echo "")

        local has_read_signal=false
        local has_write_signal=false

        echo "$context_lines" | grep -qiE "读取|输入|input|Read[^m]|读|汇聚|汇总|收集|aggregate|审查|review|检查|参考|对比|对照|加载|load" \
          && has_read_signal=true
        echo "$context_lines" | grep -qiE "写入|输出|output|Write|生成|创建|write.*to|done\.txt" \
          && has_write_signal=true

        # 只有读信号 → 跳过
        if $has_read_signal && ! $has_write_signal; then
          is_reader=true
        fi
        # 同时有读写信号 → 检查行距，文件名出现在「读取者」表格行中 → 读
        if $has_read_signal && $has_write_signal; then
          # 在 CLAUDE.md 的上下文传递表中检查
          if [[ -f "$CLAUDE_MD" ]]; then
            local in_reader_col=false
            # 匹配格式：| 文件名 | 写入者 | 读取者中包含当前agent |
            grep -i "$ws_file" "$CLAUDE_MD" 2>/dev/null \
              | grep -qi "$aname" \
              && in_reader_col=true
            # 如果当前 agent 在 CLAUDE.md 的读取者列中出现 → 是读取
            $in_reader_col && is_reader=true
          fi
        fi
      fi

      # 读者 → 跳过，不计入写入冲突
      $is_reader && continue

      if [[ -n "${workspace_writers[$ws_file]+x}" ]]; then
        workspace_writers["$ws_file"]="${workspace_writers[$ws_file]}, $aname"
        conflict_found_ws=true
      else
        workspace_writers["$ws_file"]="$aname"
      fi
    done < <(grep -oE 'workspace/[a-z0-9_-]+\.\(md\|txt\|json\)' "$f" 2>/dev/null | sort -u)
  done < <(find "$AGENT_DIR" -name "*.md" -print0 2>/dev/null)

  for ws_file in "${!workspace_writers[@]}"; do
    local writers="${workspace_writers[$ws_file]}"
    if echo "$writers" | grep -q ","; then
      deduct 3 "workspace 文件冲突：$ws_file 被多个 agent 写入（$writers）" \
        "为每个 agent 使用唯一的输出文件名"
      log_fail "workspace 文件冲突：$ws_file (-3)"
    fi
  done
  $conflict_found_ws || log_pass "workspace 输出文件名无冲突"

  # 2C. CLAUDE.md 与实际 agent 文件一致性
  if [[ -f "$CLAUDE_MD" ]]; then
    echo -e "\n  检查 CLAUDE.md agent 名称一致性..."
    local missing_agents=()
    # 只匹配「Team 成员」或「Agent」表格中明确列出的 agent 名称
    # 策略：提取 | agent-name | 或 **agent-name** 格式的名称
    while IFS= read -r agent_name; do
      [[ -z "$agent_name" ]] && continue
      # 跳过 skill 名（.claude/skills 目录中有对应 SKILL.md 的）
      [[ -f "$SKILL_DIR/$agent_name/SKILL.md" ]] && continue
      if [[ ! -f "$AGENT_DIR/${agent_name}.md" ]]; then
        missing_agents+=("$agent_name")
      fi
    done < <(grep -E '^\|[[:space:]]*\*{0,2}[a-z][a-z0-9-]+\*{0,2}[[:space:]]*\|' "$CLAUDE_MD" \
      | grep -oE '\b[a-z][a-z0-9-]{2,}\b' \
      | grep -v "^agent$\|^skill$\|^name$\|^role$\|^来源$\|^职责$\|^触发$\|^功能$" \
      | sort | uniq)

    if [[ ${#missing_agents[@]} -gt 0 ]]; then
      deduct 2 "CLAUDE.md 中引用了不存在的 agent：${missing_agents[*]}" \
        "创建缺失的 agent 文件，或从 CLAUDE.md 中移除引用"
      log_fail "CLAUDE.md 引用不存在的 agent：${missing_agents[*]} (-2)"
    else
      log_pass "CLAUDE.md agent 引用一致"
    fi
  fi

  # 2D. Fork 安全性检查（v7 新增）
  echo -e "\n  检查 fork agent 文件写入冲突..."
  local fork_agents=()
  local fork_outputs=()
  while IFS= read -r -d '' f; do
    if grep -q "context: fork\|context:fork" "$f" 2>/dev/null; then
      local aname
      aname=$(get_field "$f" "name")
      [[ -n "$aname" ]] && fork_agents+=("$aname")
      # 收集该 fork agent 写入的文件
      local outputs
      outputs=$(grep -oE 'workspace/[a-z0-9_-]+\.(md|txt|json)' "$f" 2>/dev/null | sort -u)
      for out in $outputs; do
        fork_outputs+=("$aname:$out")
      done
    fi
  done < <(find "$AGENT_DIR" -name "*.md" -print0 2>/dev/null)

  if [[ ${#fork_agents[@]} -gt 1 ]]; then
    # 检查 fork agent 之间是否有写入同一文件
    local fork_conflict=false
    declare -A fork_file_writers
    for entry in "${fork_outputs[@]}"; do
      local agent="${entry%%:*}"
      local file="${entry#*:}"
      if [[ -n "${fork_file_writers[$file]+x}" ]] && [[ "${fork_file_writers[$file]}" != "$agent" ]]; then
        deduct 2 "Fork 冲突：$file 被 fork agent ${fork_file_writers[$file]} 和 $agent 同时引用" \
          "确保 fork agent 只写自己独立的输出文件，或改为串行"
        log_fail "Fork 冲突：$file (-2)"
        fork_conflict=true
      else
        fork_file_writers["$file"]="$agent"
      fi
    done
    $fork_conflict || log_pass "Fork agent 无文件写入冲突"
  else
    log_info "少于 2 个 fork agent，跳过 fork 安全检查"
  fi

  # 2E. 共享资源初始化检查（v7 新增）
  echo -e "\n  检查共享资源初始化..."
  # 找出被多个 agent 读取的 workspace 文件（非 done.txt/error.txt）
  declare -A file_readers
  while IFS= read -r -d '' f; do
    local aname
    aname=$(get_field "$f" "name")
    [[ -z "$aname" ]] && continue
    while IFS= read -r ws_file; do
      [[ -z "$ws_file" ]] && continue
      echo "$ws_file" | grep -qE '\[|\$|done\.txt|error\.txt|count\.txt' && continue
      file_readers["$ws_file"]="${file_readers[$ws_file]:-} $aname"
    done < <(grep -oE 'workspace/[a-z0-9_-]+\.(md|txt|json)' "$f" 2>/dev/null | sort -u)
  done < <(find "$AGENT_DIR" -name "*.md" -print0 2>/dev/null)

  local shared_no_init=false
  for ws_file in "${!file_readers[@]}"; do
    local readers="${file_readers[$ws_file]}"
    local reader_count=$(echo "$readers" | wc -w | tr -d ' ')
    if [[ "$reader_count" -ge 3 ]]; then
      # 被 3+ agent 引用的文件 → 检查 CLAUDE.md 是否有初始化说明
      if [[ -f "$CLAUDE_MD" ]]; then
        local basename_ws
        basename_ws=$(basename "$ws_file")
        if ! grep -qi "$basename_ws\|初始化\|initialize" "$CLAUDE_MD" 2>/dev/null; then
          deduct 1 "共享资源 $ws_file 被 ${reader_count} 个 agent 引用，但 CLAUDE.md 无初始化说明" \
            "在 CLAUDE.md 的初始化 section 中添加该文件的创建步骤"
          log_warn "共享资源 $ws_file 无初始化 (-1)"
          shared_no_init=true
        fi
      fi
    fi
  done
  $shared_no_init || log_pass "共享资源初始化检查通过"

echo -e "\n  ${BOLD}Dimension 2 score: $DIM_SCORE/10${NC}"
write_results "$RESULT_FILE"
