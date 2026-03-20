---
name: infra-self-improving
description: |
  Configures self-improving-agent and Instincts for generated teams.
  Copies skill files, initializes .learnings/ directory, ensures CLAUDE.md references.
  Called by toolsmith-infra in Phase 4a when self-improving=yes.
  Triggers on: "setup self-improving", "配置自我改进".
  Do NOT use independently — invoked by toolsmith-infra.
allowed-tools: Read, Write, Bash
---

# Skill: Self-Improving 配置器

## 输入

- `.claude/workspace/self-improving.txt` — `yes` / `no`
- `.claude/workspace/instincts-enabled.txt` — `yes` / `no`
- `$OUTPUT_DIR` — 目标项目目录

## 执行条件

仅当 `self-improving.txt` = `yes` 时执行。否则跳过。

## 执行步骤

### Step 1：复制 self-improving-agent skill

从全局 `~/.claude/skills/self-improving-agent` 复制到 `$OUTPUT_DIR/.claude/skills/`。
如果全局不存在，尝试 `npx skills add openclaw/skills@self-improving-agent -a claude-code -g -y` 安装后再复制。
如果仍然失败，标注「需手动安装」，后续由 assembler 在 README 中补充说明。

### Step 2：确保 CLAUDE.md 包含 @引用

在 `@CONVENTIONS.md` 之后插入 `@.claude/skills/self-improving-agent/SKILL.md`。

### Step 3：初始化 .learnings/ 目录

读取 `instincts-enabled.txt`：

| instincts | 目录结构 |
|-----------|---------|
| yes | `.learnings/entries/` + `.learnings/instincts/` + README.md（两层） |
| no | `.learnings/` + README.md（扁平，v7 兼容） |

### Step 4：校验三件套

确认以下全部存在，缺一不可：
1. `.claude/skills/self-improving-agent/SKILL.md`
2. CLAUDE.md 中有 `@.claude/skills/self-improving-agent/SKILL.md`
3. `.learnings/README.md`
