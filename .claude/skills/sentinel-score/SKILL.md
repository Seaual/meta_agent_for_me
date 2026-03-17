---
name: sentinel-score
description: |
  Single-process Bash scoring engine for Meta-Agents configuration files.
  Evaluates all 4 dimensions in one shell execution to prevent variable loss.
  This skill provides the run.sh script called by the sentinel agent.
  Triggers on: "run scoring script", "install sentinel score", "生成评分脚本",
  "sentinel-score", "setup sentinel script".
  Do NOT activate directly for reviews — use the sentinel agent instead.
allowed-tools: Read, Write, Bash
---

# Skill: Sentinel Score — 评分引擎脚本

## 概述
这个 skill 提供 `run.sh` 评分脚本，供 sentinel agent 调用。脚本在**单一 bash 进程**内完成所有四个维度的评分，解决了跨 tool-call 变量丢失的问题。

---

## 安装方式

ToolSmith 在生成配置文件时自动将此 skill 复制到目标项目：

```bash
mkdir -p .claude/skills/sentinel-score
cp ~/.claude/skills/sentinel-score/run.sh .claude/skills/sentinel-score/
chmod +x .claude/skills/sentinel-score/run.sh
echo "✅ sentinel-score 已安装"
```

---

## 脚本架构

```
run.sh
├── 全局变量区（SCORE_1-4，ISSUES 数组，TOOLSMITH_FIXES 数组）
│   └── 所有变量在同一进程内持久化，不会跨 shell 调用丢失
├── 工具函数（deduct / log_pass / log_fail / get_field）
├── preflight_check()  — 目录结构验证
├── check_dimension_1() — 格式合规
├── check_dimension_2() — 协作冲突
├── check_dimension_3() — 逻辑可行性
├── check_dimension_4() — 代码安全
├── generate_report()  — 输出 JSON + Markdown 报告
└── main()            — 调用所有函数，最后 exit 0/1/2
```

**关键设计**：`deduct()` 函数直接修改全局变量 `$SCORE_1` 至 `$SCORE_4`，保证扣分在同一进程内累积。

---

## 退出码

| 代码 | 含义 |
|-----|------|
| `0` | 所有维度 ≥ 8，审查通过 |
| `1` | 有维度 < 8，未通过（修复指令见 sentinel-last-issues.md） |
| `2` | 致命错误（目录不存在、无法读取文件） |

---

## 自定义扩展

如需添加新的检查项，在对应的 `check_dimension_N()` 函数中加入：

```bash
# 示例：添加新的格式检查
if ! grep -q "my-required-field" "$f"; then
  deduct 1 2 "[$fname] 缺少 my-required-field" \
    "添加 my-required-field: [值]"
  log_fail "[$fname] 缺少 my-required-field (-2)"
fi
```

如需修改通过阈值（默认 8）：
```bash
# 在脚本顶部修改
readonly PASS_THRESHOLD=9  # 提高到 9 分
```
