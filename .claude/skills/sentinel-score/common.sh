#!/usr/bin/env bash
# common.sh — Sentinel shared functions
# Sourced by each dimension script and the coordinator

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Per-dimension state (set by each dim script)
DIM_SCORE=10
DIM_ISSUES=()
DIM_FIXES=()

# Deduct points for this dimension
deduct() {
  local points="$1"
  local message="$2"
  local fix="${3:-}"
  DIM_SCORE=$(( DIM_SCORE - points < 0 ? 0 : DIM_SCORE - points ))
  DIM_ISSUES+=("$message")
  [[ -n "$fix" ]] && DIM_FIXES+=("$message || Fix: $fix")
}

log_pass() { echo -e "  ${GREEN}✅${NC} $1"; }
log_warn() { echo -e "  ${YELLOW}⚠️ ${NC} $1"; }
log_fail() { echo -e "  ${RED}❌${NC} $1"; }
log_info() { echo -e "  ${CYAN}ℹ️ ${NC} $1"; }

# Extract YAML frontmatter field value
get_field() {
  local file="$1"
  local field="$2"
  awk "/^---$/{c++;next} c==1 && /^${field}:/{
    sub(/^${field}:[[:space:]]*/, \"\")
    gsub(/[\"']/, \"\")
    print
    exit
  } c>=2{exit}" "$file"
}

# Check if frontmatter is properly closed
has_frontmatter() {
  local file="$1"
  local count
  count=$(grep -c "^---$" "$file" 2>/dev/null || echo 0)
  [[ "$count" -ge 2 ]]
}

# Write dimension results to file (called at end of each dim script)
# Format: line 1 = score, line 2+ = issues, separator "---", line N+ = fixes
write_results() {
  local result_file="$1"
  {
    echo "$DIM_SCORE"
    for issue in "${DIM_ISSUES[@]+"${DIM_ISSUES[@]}"}"; do
      echo "ISSUE:$issue"
    done
    for fix in "${DIM_FIXES[@]+"${DIM_FIXES[@]}"}"; do
      echo "FIX:$fix"
    done
  } > "$result_file"
}
