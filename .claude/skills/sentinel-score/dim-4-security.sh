#!/usr/bin/env bash
# dim-4-security.sh — Sentinel Dimension 4: Code Security
# Runs independently, outputs results to $RESULT_FILE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

TARGET_DIR="${1:-.}"
RESULT_FILE="${2:-/tmp/sentinel-dim-4.txt}"
AGENT_DIR="$TARGET_DIR/.claude/agents"
SKILL_DIR="$TARGET_DIR/.claude/skills"
WORKSPACE="$TARGET_DIR/.claude/workspace"
CLAUDE_MD="$TARGET_DIR/CLAUDE.md"

echo -e "\n${BOLD}═══ Dimension 4: Code Security (max 10) ═══${NC}"

  echo -e "\n${BOLD}═══ 维度四：代码安全（满分 10）═══${NC}"

  local sh_files=()
  local py_files=()
  while IFS= read -r -d '' f; do sh_files+=("$f"); done \
    < <(find "$SKILL_DIR" -name "*.sh" -print0 2>/dev/null)
  while IFS= read -r -d '' f; do py_files+=("$f"); done \
    < <(find "$SKILL_DIR" -name "*.py" -print0 2>/dev/null)

  if [[ ${#sh_files[@]} -eq 0 ]] && [[ ${#py_files[@]} -eq 0 ]]; then
    log_info "无辅助脚本文件，跳过代码安全检查（满分保留）"
    return
  fi

  # 4A. Bash 脚本检查
  for f in "${sh_files[@]}"; do
    local fname
    fname=$(basename "$f")

    # set -euo pipefail
    if ! grep -q "set -euo pipefail" "$f"; then
      if grep -q "set -e" "$f"; then
        log_warn "[$fname] 有 set -e 但建议改为 set -euo pipefail"
      else
        deduct 2 "[$fname] 缺少 set -euo pipefail（Bash 安全最佳实践）" \
          "在 shebang 行后添加：set -euo pipefail"
        log_fail "[$fname] 缺少 set -euo pipefail (-2)"
      fi
    else
      log_pass "[$fname] 有 set -euo pipefail"
    fi

    # 硬编码凭证检测
    if grep -iE "(PASSWORD|SECRET|API_KEY|TOKEN|PRIVATE_KEY)\s*=\s*['\"][^'\"\$]{8,}" \
        "$f" 2>/dev/null | grep -v "^#" | grep -q .; then
      deduct 4 "[$fname] 疑似硬编码凭证（PASSWORD/SECRET/API_KEY/TOKEN）" \
        "改用环境变量：\${MY_SECRET:?请设置 MY_SECRET 环境变量}"
      log_fail "[$fname] 疑似硬编码凭证 (-4)"
    else
      log_pass "[$fname] 无硬编码凭证"
    fi

    # eval + 变量（代码注入风险）
    if grep -E "eval\s+[\"\$]" "$f" 2>/dev/null | grep -v "^#" | grep -q .; then
      deduct 4 "[$fname] eval + 变量（代码注入风险）" \
        "避免使用 eval，改用数组或 case 语句"
      log_fail "[$fname] eval 注入风险 (-4)"
    else
      log_pass "[$fname] 无 eval 注入风险"
    fi

    # rm -rf + 变量
    if grep -E "rm\s+-[rf]+\s+[\$\"]" "$f" 2>/dev/null | grep -v "^#" | grep -q .; then
      deduct 3 "[$fname] rm -rf + 变量路径（误删风险）" \
        "先验证路径非空且为预期目录，或改用 trash-cli"
      log_fail "[$fname] rm -rf 变量路径 (-3)"
    else
      log_pass "[$fname] rm -rf 安全"
    fi

    # 未引用变量（word splitting）
    # 简单检测：$VAR 后面没有引号包裹
    local unquoted_vars
    unquoted_vars=$(grep -oE '\$[A-Z_][A-Z0-9_]*' "$f" \
      | grep -v '^\$\(.*\)$' \
      | head -5 || true)
    if [[ -n "$unquoted_vars" ]]; then
      log_warn "[$fname] 可能有未引用变量（word splitting 风险），建议审查：$unquoted_vars"
      # 不扣分，仅警告
    fi

    # 可执行权限
    if [[ ! -x "$f" ]]; then
      log_warn "[$fname] 不可执行（建议：chmod +x $f）"
    else
      log_pass "[$fname] 可执行权限正常"
    fi
  done

  # 4B. Python 脚本检查
  for f in "${py_files[@]}"; do
    local fname
    fname=$(basename "$f")

    # try/except
    if ! grep -q "try:" "$f"; then
      deduct 1 "[$fname] 缺少 try/except 错误处理" \
        "在主逻辑外包裹 try/except Exception as e 并记录错误"
      log_fail "[$fname] 缺少 try/except (-1)"
    else
      log_pass "[$fname] 有错误处理"
    fi

    # 危险函数
    if grep -n "^[^#]*\(eval(\|exec(\|__import__(\)" "$f" | grep -q .; then
      deduct 3 "[$fname] 使用了高风险函数（eval/exec/__import__）" \
        "评估是否可以用更安全的替代方案"
      log_fail "[$fname] 高风险函数 (-3)"
    else
      log_pass "[$fname] 无高风险函数"
    fi

    # 硬编码凭证
    if grep -iE "(password|secret|api_key|token)\s*=\s*['\"][^'\"\$]{8,}" \
        "$f" 2>/dev/null | grep -v "^#" | grep -q .; then
      deduct 4 "[$fname] 疑似硬编码凭证" \
        "改用 os.environ.get('MY_SECRET') 或 python-dotenv"
      log_fail "[$fname] 疑似硬编码凭证 (-4)"
    else
      log_pass "[$fname] 无硬编码凭证"
    fi
  done

echo -e "\n  ${BOLD}Dimension 4 score: $DIM_SCORE/10${NC}"
write_results "$RESULT_FILE"
