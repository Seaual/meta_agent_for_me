---
name: sentinel-score
description: |
  Parallel Bash scoring engine for Meta-Agents configuration files.
  Integrates agentic-eval patterns: convergence detection, problem classification.
  Evaluates all 6 dimensions in parallel (~3-4x faster than sequential).
  This skill provides the run.sh script called by the sentinel agent.
  Triggers on: "run scoring script", "install sentinel score", "生成评分脚本",
  "sentinel-score", "setup sentinel script".
  Do NOT activate directly for reviews — use the sentinel agent instead.
allowed-tools: Read, Write, Bash
---

# Skill: Sentinel Score — 评分引擎脚本

## 概述

这个 skill 提供 `run.sh` 评分脚本，供 sentinel agent 调用。脚本**并行执行 6 个维度检查**，并集成 **agentic-eval 的 Evaluator-Optimizer 模式**：

- **收敛检测**：比较分数历史，判断修复是否有效
- **问题分类**：将问题分为简单修复/重构/架构问题三类
- **总分计算**：60 分制，便于追踪改进趋势

---

## 安装方式

ToolSmith 在生成配置文件时自动将此 skill 复制到目标项目：

```bash
mkdir -p .claude/skills/sentinel-score
cp -r ~/.claude/skills/sentinel-score/* .claude/skills/sentinel-score/
chmod +x .claude/skills/sentinel-score/*.sh
echo "✅ sentinel-score 已安装"
```

---

## 脚本架构

```
run.sh (v3.0.0-agentic-eval)
├── preflight_check()      — 目录结构验证
├── manage_retry_counter() — 重试计数器（最多 3 轮）
├── run_dimensions_parallel() — 并行执行 6 个维度
│   ├── dim-1-format.sh    — 格式合规
│   ├── dim-2-conflicts.sh — 协作冲突
│   ├── dim-3-logic.sh     — 逻辑可行性
│   ├── dim-4-security.sh  — 代码安全
│   ├── dim-5-quality.sh   — 内容质量
│   └── dim-6-exec.sh      — 可执行性
├── check_convergence()    — 收敛检测（agentic-eval）
├── classify_issues()      — 问题分类（agentic-eval）
├── collect_results()      — 汇总分数和修复指令
└── generate_report()      — 输出 JSON + Markdown 报告
```

---

## 退出码

| 代码 | 含义 |
|-----|------|
| `0` | 所有维度 ≥ 8，审查通过 |
| `1` | 有维度 < 8，未通过（修复指令见 sentinel-last-issues.md） |
| `2` | 致命错误（目录不存在、无法读取文件） |

---

## 输出文件

| 文件 | 内容 |
|------|------|
| `sentinel-report.json` | 机器可读的评分结果（含各维度分数、总分、通过状态）|
| `sentinel-last-issues.md` | 问题分类 + Toolsmith 可执行的修复指令 |
| `sentinel-score-history.txt` | 分数历史（每轮总分，用于收敛检测）|
| `sentinel-retry-count.txt` | 重试计数器（0=通过重置，1-3=进行中）|

---

## agentic-eval 模式集成

### 收敛检测

每轮记录总分（60 分制），比较与上一轮的差异：

```
Round 1: 42/60
Round 2: 48/60 → ✅ Converging (+6)
Round 3: 47/60 → ⚠️ Not converging (-1)
```

### 问题分类

根据维度分数自动分类问题：

| 类别 | 维度 | 修复难度 |
|------|------|---------|
| **简单修复** | 格式合规、代码安全、内容质量 | 低 |
| **需要重构** | 协作冲突、可执行性 | 中 |
| **架构问题** | 逻辑可行性 | 高 |

---

## 使用示例

```bash
# 审查当前目录
bash .claude/skills/sentinel-score/run.sh

# 审查指定目录
bash .claude/skills/sentinel-score/run.sh /path/to/project

# 查看上次结果
cat .claude/workspace/sentinel-report.json

# 查看分数历史
cat .claude/workspace/sentinel-score-history.txt

# 查看问题分类
head -30 .claude/workspace/sentinel-last-issues.md
```

---

## 自定义扩展

如需添加新的检查项，在对应的 `dim-N-*.sh` 脚本中添加：

```bash
# 示例：在 dim-1-format.sh 中添加新检查
if ! grep -q "my-required-field" "$f"; then
  echo "  ❌ [$fname] 缺少 my-required-field (-2)"
  deduct 2
  echo "FIX: [$fname] 缺少 my-required-field||添加 my-required-field: [值]"
fi
```

---

## 版本历史

| 版本 | 变更 |
|------|------|
| 3.0.0 | 集成 agentic-eval：收敛检测、问题分类、总分计算 |
| 2.0.0 | 并行执行 6 个维度 |
| 1.0.0 | 串行执行 4 个维度 |