---
name: tool-forge
description: |
  Activate when a specific tool, script, or helper needs to be created for an agent or skill.
  Handles generating Bash scripts, Python utilities, API call templates, and MCP server stubs.
  Triggers on: "create tool for agent", "write helper script", "为agent写工具", "生成脚本",
  "tool for skill", "API调用模板", "bash tool", "python helper".
  Do NOT use for creating agent .md files or CLAUDE.md (use agent-architect skill instead).
allowed-tools: Read, Write, Bash, Edit
---

# Skill: Tool Forge — 工具生成器

## 概述
专门为 Agent Team 中的 agent 和 skill 生成可运行的辅助工具。涵盖 Bash 脚本、Python 工具、API 调用模板和 MCP Server 存根。

---

## 前置检查

```bash
# 确认当前技术环境
echo "Python: $(python3 --version 2>/dev/null || echo '未安装')"
echo "Node:   $(node --version 2>/dev/null || echo '未安装')"
echo "Bash:   $BASH_VERSION"
echo "OS:     $(uname -s)"
```

---

## 工具类型模板

### 类型 1：Bash 工具脚本

```bash
#!/bin/bash
# ============================================================
# [工具名称] — [一句话描述]
# ============================================================
# 用法:    ./tool-name.sh [options] <argument>
# 依赖:    [list dependencies, e.g. jq, curl, git]
# 作者:    Meta-Agents ToolSmith
# ============================================================

set -euo pipefail

# ── 配置 ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/tool.log"
MAX_RETRIES=3

# ── 颜色输出 ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# ── 参数解析 ────────────────────────────────────────────────
usage() {
  echo "用法: $(basename "$0") [options] <argument>"
  echo ""
  echo "选项:"
  echo "  -h, --help     显示此帮助"
  echo "  -v, --verbose  详细输出"
  echo "  -d, --dry-run  模拟运行（不实际执行）"
  # 停止执行，告知用户相关前置条件
}

VERBOSE=false
DRY_RUN=false
ARGUMENT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)    usage ;;
    -v|--verbose) VERBOSE=true; shift ;;
    -d|--dry-run) DRY_RUN=true; shift ;;
    *)            ARGUMENT="$1"; shift ;;
  esac
done

[[ -z "$ARGUMENT" ]] && { log_error "缺少必要参数"; usage; }

# ── 主逻辑 ────────────────────────────────────────────────
main() {
  log_info "开始处理: $ARGUMENT"
  
  if $DRY_RUN; then
    log_warn "模拟运行模式，不实际执行"
    return 0
  fi

  # [在此实现具体逻辑]
  
  log_info "✅ 完成"
}

main "$@"
```

---

### 类型 2：Python 工具脚本

```python
#!/usr/bin/env python3
"""
[工具名称] — [一句话描述]

用法:
    python tool_name.py [options] <argument>

依赖:
    pip install requests pyyaml  # [实际依赖]

作者: Meta-Agents ToolSmith
"""

import sys
import argparse
import logging
from pathlib import Path
from typing import Optional

# ── 日志配置 ──────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger(__name__)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="[工具描述]",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("argument", help="[参数描述]")
    parser.add_argument("-v", "--verbose", action="store_true", help="详细输出")
    parser.add_argument("-d", "--dry-run", action="store_true", help="模拟运行")
    parser.add_argument("-o", "--output", type=Path, help="输出路径")
    return parser.parse_args()


def process(argument: str, dry_run: bool = False, output: Optional[Path] = None) -> dict:
    """
    核心处理函数
    
    Args:
        argument: [描述]
        dry_run: 是否模拟运行
        output: 输出路径（可选）
    
    Returns:
        处理结果字典
    
    Raises:
        ValueError: 当输入无效时
        FileNotFoundError: 当文件不存在时
    """
    logger.info(f"处理: {argument}")
    
    if dry_run:
        logger.warning("模拟运行模式")
        return {"status": "dry_run", "argument": argument}
    
    # [在此实现具体逻辑]
    result = {}
    
    if output:
        import json
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2))
        logger.info(f"结果已保存到: {output}")
    
    return result


def main() -> int:
    args = parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        result = process(
            argument=args.argument,
            dry_run=args.dry_run,
            output=args.output
        )
        logger.info(f"✅ 完成: {result}")
        return 0
    except Exception as e:
        logger.error(f"❌ 失败: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
```

---

### 类型 3：API 调用模板（Bash + curl）

```bash
#!/bin/bash
# API 调用工具 — [API名称]
set -euo pipefail

API_BASE_URL="${API_BASE_URL:-https://api.example.com}"
API_KEY="${API_KEY:?请设置 API_KEY 环境变量}"
TIMEOUT=30

# ── 通用 API 调用函数 ──────────────────────────────────────
api_call() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"
  
  local args=(
    --silent
    --fail
    --timeout "$TIMEOUT"
    --header "Content-Type: application/json"
    --header "Authorization: Bearer $API_KEY"
    --request "$method"
    "${API_BASE_URL}${endpoint}"
  )
  
  if [[ -n "$data" ]]; then
    args+=(--data "$data")
  fi
  
  curl "${args[@]}" | jq '.'
}

# 使用示例
# api_call GET  "/v1/items"
# api_call POST "/v1/items" '{"name": "test"}'
# api_call PUT  "/v1/items/123" '{"name": "updated"}'
```

---

### 类型 4：YAML 验证器（用于 Agent 配置验证）

```bash
#!/bin/bash
# validate-agent-config.sh — 验证 Agent Team 配置文件格式
set -euo pipefail

CONFIG_DIR="${1:-.claude}"
ERRORS=0
WARNINGS=0

check_file() {
  local file="$1"
  local filename=$(basename "$file")
  
  # 检查 frontmatter 存在
  if ! grep -q "^---$" "$file"; then
    echo "🔴 [$filename] 缺少 YAML frontmatter (---)"
    ((ERRORS++))
    return
  fi
  
  # 提取 frontmatter 内容
  local frontmatter
  frontmatter=$(awk '/^---$/{if(c++){exit};c=1;next}/^---$/{exit}1' "$file" 2>/dev/null || true)
  
  # 检查必填字段
  for field in "name" "description" "allowed-tools"; do
    if ! echo "$frontmatter" | grep -q "^${field}:"; then
      echo "🔴 [$filename] 缺少必填字段: $field"
      ((ERRORS++))
    fi
  done
  
  # 检查 name 格式（kebab-case）
  local name
  name=$(echo "$frontmatter" | grep "^name:" | sed 's/name: *//' | tr -d '"' | tr -d "'")
  if [[ "$name" =~ [A-Z_\ ] ]]; then
    echo "🟡 [$filename] name '$name' 应使用 kebab-case（小写字母和连字符）"
    ((WARNINGS++))
  fi
  
  # 检查 allowed-tools 的工具名称
  local tools
  tools=$(echo "$frontmatter" | grep "^allowed-tools:" | sed 's/allowed-tools: *//')
  local valid_tools="Read Write Edit Bash Grep Glob"
  IFS=', ' read -ra tool_list <<< "$tools"
  for tool in "${tool_list[@]}"; do
    if ! echo "$valid_tools" | grep -qw "$tool"; then
      echo "🟡 [$filename] 未知工具: '$tool'（有效工具: $valid_tools）"
      ((WARNINGS++))
    fi
  done
  
  echo "✅ [$filename] 基础格式检查通过"
}

echo "═══════════════════════════════════════"
echo " Agent Config 验证器"
echo " 目录: $CONFIG_DIR"
echo "═══════════════════════════════════════"

# 检查 agents
if [ -d "$CONFIG_DIR/agents" ]; then
  echo ""
  echo "📂 Agents:"
  for f in "$CONFIG_DIR/agents"/*.md; do
    [ -f "$f" ] && check_file "$f"
  done
fi

# 检查 skills
if [ -d "$CONFIG_DIR/skills" ]; then
  echo ""
  echo "📂 Skills:"
  for f in "$CONFIG_DIR/skills"/*/SKILL.md; do
    [ -f "$f" ] && check_file "$f"
  done
fi

echo ""
echo "═══════════════════════════════════════"
echo " 结果: 🔴 $ERRORS 个错误  🟡 $WARNINGS 个警告"
echo "═══════════════════════════════════════"

exit $ERRORS
```

---

## 工具选择指南

根据任务类型选择最合适的工具模板：

| 任务 | 推荐类型 |
|-----|---------|
| 文件处理、命令编排 | Bash 脚本 |
| 数据解析、复杂逻辑 | Python 脚本 |
| 外部 API 集成 | API 调用模板（Bash+curl 或 Python+requests） |
| 配置文件验证 | YAML 验证器（Bash） |
| MCP 服务器 | Node.js（需额外模板） |

---

## 输出规范

生成的工具脚本必须：
1. 有完整的文件头注释（用法、依赖、作者）
2. 有参数解析和 `-h/--help` 支持
3. 有错误处理（`set -euo pipefail` 或 try/except）
4. 有 dry-run 模式（适用于有副作用的操作）
5. 有清晰的成功/失败输出（✅/❌ 标记）
6. 文件权限设置为可执行（`chmod +x`）
