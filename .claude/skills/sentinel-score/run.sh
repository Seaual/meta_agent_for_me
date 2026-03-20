#!/usr/bin/env bash
# ============================================================
# sentinel-score/run.sh — Parallel Sentinel Scoring Engine
# ============================================================
# Launches 6 dimension checks in parallel, collects results.
# Integrates agentic-eval patterns: convergence detection, problem classification.
#
# Usage:
#   ./run.sh [target_dir]
#   target_dir: directory containing .claude/, defaults to .
#
# Exit codes:
#   0 — all dimensions ≥ 8, passed
#   1 — some dimension < 8, failed
#   2 — fatal error (directory missing, files unreadable)
#
# Output:
#   stdout — human-readable scoring report
#   .claude/workspace/sentinel-report.json — machine-readable
#   .claude/workspace/sentinel-last-issues.md — Toolsmith fix instructions
#   .claude/workspace/sentinel-score-history.txt — score history for convergence detection
# ============================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="3.0.0-agentic-eval"
readonly PASS_THRESHOLD=8
readonly TARGET_DIR="${1:-.}"
readonly AGENT_DIR="$TARGET_DIR/.claude/agents"
readonly SKILL_DIR="$TARGET_DIR/.claude/skills"
readonly WORKSPACE="$TARGET_DIR/.claude/workspace"
readonly CLAUDE_MD="$TARGET_DIR/CLAUDE.md"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Temp directory for parallel results
RESULT_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t sentinel)
trap "rm -rf $RESULT_DIR" EXIT

# ── Preflight Check ──────────────────────────────────────────

preflight_check() {
  echo -e "\n${BOLD}═══ Preflight Check ═══${NC}"

  if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${RED}Fatal: target directory does not exist: $TARGET_DIR${NC}"
    exit 2
  fi

  if [[ ! -d "$AGENT_DIR" ]] && [[ ! -d "$SKILL_DIR" ]]; then
    echo -e "${RED}Fatal: no .claude/agents/ or .claude/skills/ found${NC}"
    exit 2
  fi

  mkdir -p "$WORKSPACE"

  local agent_count skill_count
  agent_count=$(find "$AGENT_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  skill_count=$(find "$SKILL_DIR" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')

  echo -e "  ${CYAN}ℹ️ ${NC} Target: $TARGET_DIR"
  echo -e "  ${CYAN}ℹ️ ${NC} Agents: ${agent_count}"
  echo -e "  ${CYAN}ℹ️ ${NC} Skills: ${skill_count}"
  echo -e "  ${CYAN}ℹ️ ${NC} CLAUDE.md: $([ -f "$CLAUDE_MD" ] && echo 'found' || echo 'missing')"
}

# ── Retry Counter ────────────────────────────────────────────

manage_retry_counter() {
  local retry_file="$WORKSPACE/sentinel-retry-count.txt"
  local count=0

  [[ -f "$retry_file" ]] && count=$(cat "$retry_file")

  if [[ "$count" -ge 3 ]]; then
    echo -e "${RED}${BOLD}🛑 Max retries reached (3). Manual intervention required.${NC}"
    echo "See: $WORKSPACE/sentinel-last-issues.md"
    [[ -f "$WORKSPACE/sentinel-last-issues.md" ]] && cat "$WORKSPACE/sentinel-last-issues.md"
    exit 1
  fi

  echo $(( count + 1 )) > "$retry_file"
  RETRY_COUNT=$(( count + 1 ))
}

# ── Parallel Execution ───────────────────────────────────────

run_dimensions_parallel() {
  echo -e "\n${BOLD}═══ Running 6 dimensions in parallel... ═══${NC}"

  local pids=()
  local dim_scripts=(
    "dim-1-format.sh"
    "dim-2-conflicts.sh"
    "dim-3-logic.sh"
    "dim-4-security.sh"
    "dim-5-quality.sh"
    "dim-6-exec.sh"
  )

  for i in {0..5}; do
    local dim=$(( i + 1 ))
    local script="$SCRIPT_DIR/${dim_scripts[$i]}"
    local result_file="$RESULT_DIR/dim-${dim}.txt"
    local log_file="$RESULT_DIR/dim-${dim}.log"

    if [[ -f "$script" ]]; then
      bash "$script" "$TARGET_DIR" "$result_file" > "$log_file" 2>&1 &
      pids+=($!)
    else
      echo -e "  ${RED}❌${NC} Missing: $script"
      echo "10" > "$result_file"  # Default pass if script missing
    fi
  done

  # Wait for all with timeout (120s)
  local timeout=120
  local elapsed=0
  local all_done=false

  while ! $all_done && [[ $elapsed -lt $timeout ]]; do
    all_done=true
    for pid in "${pids[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then
        all_done=false
        break
      fi
    done
    $all_done || { sleep 1; elapsed=$(( elapsed + 1 )); }
  done

  # Kill any remaining processes
  for pid in "${pids[@]}"; do
    kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null && echo "  ⚠️  Killed timed-out dimension process $pid"
  done
  wait 2>/dev/null || true

  echo -e "  ${GREEN}✅${NC} All dimensions complete (${elapsed}s)"
}

# ── Collect Results ──────────────────────────────────────────

collect_results() {
  SCORE_1=10; SCORE_2=10; SCORE_3=10; SCORE_4=10; SCORE_5=10; SCORE_6=10
  TOOLSMITH_FIXES=()

  for dim in {1..6}; do
    local result_file="$RESULT_DIR/dim-${dim}.txt"
    local log_file="$RESULT_DIR/dim-${dim}.log"

    # Print dimension output (captured logs)
    [[ -f "$log_file" ]] && cat "$log_file"

    # Read score from result file
    if [[ -f "$result_file" ]]; then
      local score
      score=$(head -1 "$result_file")
      eval "SCORE_${dim}=$score"

      # Read fixes
      while IFS= read -r line; do
        [[ "$line" == FIX:* ]] && TOOLSMITH_FIXES+=("${line#FIX:}")
      done < "$result_file"
    else
      echo -e "  ${RED}❌${NC} No result for dimension $dim (defaulting to 10)"
    fi
  done
}

# ── Convergence Detection (agentic-eval) ─────────────────────

check_convergence() {
  local total_score=$(( SCORE_1 + SCORE_2 + SCORE_3 + SCORE_4 + SCORE_5 + SCORE_6 ))
  local history_file="$WORKSPACE/sentinel-score-history.txt"
  local prev_score=0

  # Read previous total score
  if [[ -f "$history_file" ]]; then
    prev_score=$(tail -1 "$history_file" 2>/dev/null || echo "0")
  fi

  # Record current score
  echo "$total_score" >> "$history_file"

  # Check convergence
  if [[ "$total_score" -le "$prev_score" ]] && [[ "$RETRY_COUNT" -gt 1 ]]; then
    echo -e "\n${YELLOW}${BOLD}⚠️  Convergence Warning${NC}"
    echo -e "  Score did not improve: ${prev_score}/60 → ${total_score}/60"
    echo -e "  This may indicate:"
    echo -e "    - Fix instructions are not specific enough"
    echo -e "    - Issues are architectural (need redesign)"
    echo -e "    - Multiple issues are interdependent"
    return 1  # Not converging
  fi

  return 0  # Converging or first run
}

# ── Problem Classification (agentic-eval) ────────────────────

classify_issues() {
  local issues_file="$WORKSPACE/sentinel-last-issues.md"
  [[ ! -f "$issues_file" ]] && return

  local simple_fixes=()
  local refactor_fixes=()
  local arch_fixes=()

  # Classify based on keywords and scores
  [[ $SCORE_1 -lt $PASS_THRESHOLD ]] && simple_fixes+=("Format issues (missing fields, naming)")
  [[ $SCORE_2 -lt $PASS_THRESHOLD ]] && refactor_fixes+=("Agent conflicts (trigger overlap, workspace conflicts)")
  [[ $SCORE_3 -lt $PASS_THRESHOLD ]] && arch_fixes+=("Logic issues (missing workflow, dependency gaps)")
  [[ $SCORE_4 -lt $PASS_THRESHOLD ]] && simple_fixes+=("Security issues (unsafe patterns)")
  [[ $SCORE_5 -lt $PASS_THRESHOLD ]] && simple_fixes+=("Quality issues (placeholders, missing content)")
  [[ $SCORE_6 -lt $PASS_THRESHOLD ]] && refactor_fixes+=("Executability issues (missing commands, hooks)")

  # Prepend classification to issues file
  local classification="# Issue Classification (agentic-eval Evaluator-Optimizer)

## Summary
- Total Score: $(( SCORE_1 + SCORE_2 + SCORE_3 + SCORE_4 + SCORE_5 + SCORE_6 ))/60
- Round: ${RETRY_COUNT}/3
- Convergence: $( [[ -f "$WORKSPACE/sentinel-score-history.txt" ]] && tail -2 "$WORKSPACE/sentinel-score-history.txt" | head -1 || echo "N/A" ) → $(( SCORE_1 + SCORE_2 + SCORE_3 + SCORE_4 + SCORE_5 + SCORE_6 ))

## Problem Categories

### 🔧 Simple Fixes (Direct execution)
$( [[ ${#simple_fixes[@]} -gt 0 ]] && printf '%s\n' "${simple_fixes[@]}" || echo "- None" )

### 🔄 Needs Refactoring (May need design adjustment)
$( [[ ${#refactor_fixes[@]} -gt 0 ]] && printf '%s\n' "${refactor_fixes[@]}" || echo "- None" )

### 🏗️ Architectural Issues (May require rollback)
$( [[ ${#arch_fixes[@]} -gt 0 ]] && printf '%s\n' "${arch_fixes[@]}" || echo "- None" )

---

"

  # Prepend to existing file
  local temp_file=$(mktemp)
  echo "$classification" > "$temp_file"
  cat "$issues_file" >> "$temp_file"
  mv "$temp_file" "$issues_file"
}

# ── Generate Report ──────────────────────────────────────────

generate_report() {
  local retry_count
  retry_count=$(cat "$WORKSPACE/sentinel-retry-count.txt" 2>/dev/null || echo 0)

  local overall_pass=true
  for score in $SCORE_1 $SCORE_2 $SCORE_3 $SCORE_4 $SCORE_5 $SCORE_6; do
    [[ "$score" -lt "$PASS_THRESHOLD" ]] && overall_pass=false && break
  done

  local dim_labels=("Format compliance" "Agent conflicts" "Logic feasibility" "Code security" "Content quality" "Executability")
  local total_score=$(( SCORE_1 + SCORE_2 + SCORE_3 + SCORE_4 + SCORE_5 + SCORE_6 ))

  echo -e "\n${BOLD}════════════════════════════════════════${NC}"
  echo -e "${BOLD} Sentinel Scoring Report v${SCRIPT_VERSION}${NC}"
  echo -e "${BOLD} Round ${retry_count}/3 | Total: ${total_score}/60${NC}"
  echo -e "${BOLD}════════════════════════════════════════${NC}"

  for i in {0..5}; do
    local dim=$(( i + 1 ))
    local score
    eval "score=\$SCORE_${dim}"
    local color=$( [[ $score -ge $PASS_THRESHOLD ]] && echo "$GREEN" || echo "$RED" )
    printf " %-24s: ${color}${BOLD}%s/10${NC}\n" "${dim_labels[$i]}" "$score"
  done

  echo -e "${BOLD}────────────────────────────────────────${NC}"
  echo -e " Pass condition: all dimensions ≥ ${PASS_THRESHOLD}"

  if $overall_pass; then
    echo -e " Result: ${GREEN}${BOLD}✅ PASSED${NC}"
    echo "0" > "$WORKSPACE/sentinel-retry-count.txt"
    echo "" > "$WORKSPACE/sentinel-score-history.txt"
  else
    echo -e " Result: ${RED}${BOLD}🔄 FAILED${NC}"
  fi
  echo -e "${BOLD}════════════════════════════════════════${NC}\n"

  # Write JSON report
  cat > "$WORKSPACE/sentinel-report.json" << EOF
{
  "version": "${SCRIPT_VERSION}",
  "round": ${retry_count},
  "pass_threshold": ${PASS_THRESHOLD},
  "total_score": ${total_score},
  "scores": {
    "format_compliance": ${SCORE_1},
    "agent_conflicts": ${SCORE_2},
    "logic_feasibility": ${SCORE_3},
    "code_security": ${SCORE_4},
    "content_quality": ${SCORE_5},
    "executability": ${SCORE_6}
  },
  "overall_pass": ${overall_pass},
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

  # Write Toolsmith fix instructions
  if ! $overall_pass && [[ ${#TOOLSMITH_FIXES[@]} -gt 0 ]]; then
    {
      echo "## Sentinel Fix Instructions (round ${retry_count})"
      echo ""
      echo "The following issues need to be fixed before re-submission:"
      echo ""
      local idx=1
      for fix in "${TOOLSMITH_FIXES[@]}"; do
        local issue="${fix%%||*}"
        local solution="${fix##*||}"
        echo "### Issue ${idx}"
        echo "- **Issue**: ${issue}"
        echo "- **Fix**: ${solution}"
        echo ""
        (( idx++ )) || true
      done
    } > "$WORKSPACE/sentinel-last-issues.md"

    # Apply agentic-eval classification
    classify_issues

    echo -e "${CYAN}Fix instructions: $WORKSPACE/sentinel-last-issues.md${NC}"
  fi

  $overall_pass && exit 0 || exit 1
}

# ── Main ─────────────────────────────────────────────────────

main() {
  echo -e "${BOLD}Sentinel Scoring Engine v${SCRIPT_VERSION}${NC}"
  echo "Target: $TARGET_DIR"

  manage_retry_counter
  preflight_check
  run_dimensions_parallel
  collect_results
  check_convergence || true  # Don't fail on non-convergence
  generate_report
}

main "$@"