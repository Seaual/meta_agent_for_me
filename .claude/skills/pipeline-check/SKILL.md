---
name: pipeline-check
description: |
  Dry-run validation of the Meta-Agents pipeline. Checks that all agents,
  skills, scripts, and templates are present and internally consistent.
  Does NOT generate any files or run any phase.
  Triggers on: "pipeline check", "dry run", "检查流水线", "预检",
  "verify pipeline", "流水线健康检查", "meta-agents 状态".
  Do NOT use for actual team generation — use agent-architect instead.
  Do NOT use for reviewing generated teams — use sentinel instead.
allowed-tools: Read, Bash, Glob, Grep
---

# Skill: Pipeline Check — 流水线预检

## 概述
在不运行任何 Phase 的情况下验证 Meta-Agents 系统的结构完整性和内部一致性。
发现缺失文件、孤立引用、脚本权限问题和配置矛盾。

---

## 执行步骤

### Step 1：核心文件存在性检查

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "═══ Meta-Agents v6 流水线预检 ═══"
echo ""
ERRORS=0
WARNINGS=0

# 根目录文件
for f in CLAUDE.md CONVENTIONS.md; do
  [ -f "$f" ] \
    && echo "✅ $f" \
    || { echo "🔴 缺失: $f"; ((ERRORS++)); }
done
```

### Step 2：Agent 文件检查

```bash
EXPECTED_AGENTS=(
  director-council director-strategic director-critical director-technical
  visionary-arch visionary-ux visionary-tech
  library-scout toolsmith-infra toolsmith-agents toolsmith-skills
  toolsmith-assembler sentinel
)

echo ""
echo "── Agents（预期 ${#EXPECTED_AGENTS[@]} 个）──"
for a in "${EXPECTED_AGENTS[@]}"; do
  if [ -f ".claude/agents/$a.md" ]; then
    # 检查 frontmatter 基础完整性
    head -1 ".claude/agents/$a.md" | grep -q "^---$" \
      && echo "✅ $a" \
      || { echo "🟡 $a（frontmatter 缺失）"; ((WARNINGS++)); }
  else
    echo "🔴 缺失: $a.md"; ((ERRORS++))
  fi
done

# 检查 v5 遗留文件
if [ -f ".claude/agents/visionary-b.md" ]; then
  echo "🟡 发现 v5 遗留文件 visionary-b.md，建议移至 .claude/archived/"
  ((WARNINGS++))
fi
```

### Step 3：Skill 文件检查

```bash
EXPECTED_SKILLS=(
  agent-architect-build agency-agents-search find-skill create-skill
  tool-forge workspace-init output-validator sentinel-score pipeline-check
)

echo ""
echo "── Skills（预期 ${#EXPECTED_SKILLS[@]} 个）──"
for s in "${EXPECTED_SKILLS[@]}"; do
  if [ -f ".claude/skills/$s/SKILL.md" ]; then
    echo "✅ $s"
  else
    echo "🔴 缺失: $s/SKILL.md"; ((ERRORS++))
  fi
done

# sentinel-score 需要 run.sh
if [ -f ".claude/skills/sentinel-score/run.sh" ]; then
  [ -x ".claude/skills/sentinel-score/run.sh" ] \
    && echo "✅ sentinel-score/run.sh（可执行）" \
    || { echo "🟡 sentinel-score/run.sh 不可执行"; ((WARNINGS++)); }
else
  echo "🔴 缺失: sentinel-score/run.sh"; ((ERRORS++))
fi
```

### Step 4：脚本和模板检查

```bash
echo ""
echo "── Scripts ──"
for script in version-manager.sh conventions-gen.sh \
              self-improving-setup.sh improvements-gen.sh; do
  [ -f ".claude/scripts/$script" ] \
    && echo "✅ $script" \
    || { echo "🔴 缺失: $script"; ((ERRORS++)); }
done

echo ""
echo "── Templates ──"
[ -f ".claude/templates/readme-template.md" ] \
  && echo "✅ readme-template.md" \
  || { echo "🔴 缺失: readme-template.md"; ((ERRORS++)); }
```

### Step 5：交叉引用一致性

```bash
echo ""
echo "── 交叉引用 ──"

# CLAUDE.md 中引用的 agent 全部存在
for a in "${EXPECTED_AGENTS[@]}"; do
  grep -q "$a" CLAUDE.md 2>/dev/null \
    && echo "✅ CLAUDE.md → $a" \
    || { echo "🟡 CLAUDE.md 未引用 $a"; ((WARNINGS++)); }
done

# CLAUDE.md @CONVENTIONS.md 引用
grep -q "@CONVENTIONS.md" CLAUDE.md 2>/dev/null \
  && echo "✅ CLAUDE.md 含 @CONVENTIONS.md" \
  || { echo "🔴 CLAUDE.md 缺少 @CONVENTIONS.md 引用"; ((ERRORS++)); }
```

### Step 6：deduct() 维度覆盖检查

```bash
echo ""
echo "── Sentinel 引擎检查 ──"
if [ -f ".claude/skills/sentinel-score/run.sh" ]; then
  DIM_COUNT=$(grep -cE "^    [0-9]\)" .claude/skills/sentinel-score/run.sh || true)
  [ "$DIM_COUNT" -ge 6 ] \
    && echo "✅ deduct() 覆盖 $DIM_COUNT 个维度" \
    || { echo "🔴 deduct() 只覆盖 $DIM_COUNT 个维度（应为 6）"; ((ERRORS++)); }

  # 检查六个 check_dimension 函数都存在
  for d in 1 2 3 4 5 6; do
    grep -q "check_dimension_${d}()" .claude/skills/sentinel-score/run.sh \
      && echo "✅ check_dimension_${d}" \
      || { echo "🔴 缺失 check_dimension_${d}"; ((ERRORS++)); }
  done
fi
```

### Step 7：CONVENTIONS 规范完整性

```bash
echo ""
echo "── CONVENTIONS 规范 ──"
CONV_CHECKS=(
  "执行模型:Claude Code 执行模型规范"
  "原子写入:原子写入规范"
  "安全红线:安全规范"
  "共享资源:共享资源管理规范"
  "错误处理:错误处理模板"
  "Fork 进程:Fork 变量传递"
)
for entry in "${CONV_CHECKS[@]}"; do
  local pattern="${entry%%:*}"
  local label="${entry##*:}"
  grep -qi "$pattern" CONVENTIONS.md 2>/dev/null \
    && echo "✅ CONVENTIONS 含「$label」" \
    || { echo "🟡 CONVENTIONS 缺少「$label」"; ((WARNINGS++)); }
done
```

### Step 8：输出汇总

```bash
echo ""
echo "═══════════════════════════════════"
echo " 预检结果：🔴 $ERRORS 个错误  🟡 $WARNINGS 个警告"
echo "═══════════════════════════════════"

if [ "$ERRORS" -eq 0 ]; then
  echo "✅ 流水线就绪，可以运行 agent-architect"
else
  echo "🔴 请先修复上述 $ERRORS 个错误"
fi

exit $ERRORS
```

---

## 降级行为

| 情况 | 处理 |
|-----|------|
| 某个检查命令执行失败 | 跳过该项，记录为警告，继续检查其余项 |
| .claude 目录完全不存在 | 报告致命错误，建议重新初始化系统 |
