# Sentinel 审查问题清单 — 第 2 轮

> 生成时间：2026-05-01
> 目标目录：xiaohongshu-content-creator_teams_v2
> 总分：48/60（未通过，executability < 8）

---

## 第 1 轮修复验证

| 问题 | 状态 | 备注 |
|------|------|------|
| settings.json bypassPermissions → acceptEdits | ✅ 已修复 | |
| xiaohongshu-style-writer 删除占位声明 | ✅ 已修复 | |
| image-processor curl 改用 jq -n | ✅ 已修复 | |
| CONVENTIONS.md 路径描述 | ✅ 已修复 | |
| 创建 profile.txt / instincts-enabled.txt | ✅ 已修复 | |
| command 文件添加对应 Agent 章节 | ✅ 已修复 | |
| instinct-engine 添加 frontmatter | ⚠️ 部分修复 | 有 frontmatter 但格式不标准 |

---

## 本轮问题清单

### 🔴 P0 — 必须修复（影响通过）

#### 1. 缺少 task-board.md
**位置**：`.claude/workspace/`
**问题**：v8 规范要求集中式进度看板，但 workspace 中不存在
**修复**：创建 `.claude/workspace/task-board.md`，按 v8 规范初始化各 Phase 状态

#### 2. 缺少 event-log.jsonl
**位置**：`.claude/workspace/`
**问题**：v8 规范要求审计日志，用于 Sentinel 追溯
**修复**：创建 `.claude/workspace/event-log.jsonl`，初始写入一行 `{"ts":"2026-05-01T...","event":"init"}`

#### 3. 缺少 output-dir.txt
**位置**：`.claude/workspace/`
**问题**：fork 进程读取路径的唯一来源，toolsmith-infra 完成后应写入
**修复**：创建 `.claude/workspace/output-dir.txt`，内容为 `D:/agentset/xiaohongshu-content-creator_teams/xiaohongshu-content-creator_teams_v2`

#### 4. instinct-engine SKILL.md frontmatter 不标准
**位置**：`.claude/skills/instinct-engine/SKILL.md`
**问题**：文件以 `# Instinct Engine` 标题开头，无 YAML frontmatter（name、description、allowed-tools）
**修复**：在文件开头添加标准 skill frontmatter：
```yaml
---
name: instinct-engine
description: |
  Activate when refining raw learning entries into actionable instincts.
  Handles: learning clustering, pattern extraction, instinct promotion, decay management.
  Keywords: instinct, learning, pattern, refinement, decay.
  Do NOT use for: general skill execution (use the target skill directly).
allowed-tools: Read, Write, Bash, Grep
---
```

---

### 🟡 P1 — 建议修复

#### 5. self-improving-agent SKILL.md 内容完全通用
**位置**：`.claude/skills/self-improving-agent/SKILL.md`
**问题**：包含大量与小红书场景无关的示例（PRD、React、API design），未针对本 Team 裁剪
**修复**：在 "Evolution Priority Matrix" 后添加「小红书 Team 专属改进目标」章节，列出：
- article-analyzer: 风格特征提取准确率
- style-synthesizer: skill 生成可执行性
- content-creator: 推文互动率、合规率
- keyword-guard: 敏感词召回率
- xiaohongshu-policy-guard: 平台规则覆盖率
- image-processor: 图片生成成功率

#### 6. pre-write-xhs-compliance.js RegExp 构造未验证
**位置**：`scripts/hooks/pre-write-xhs-compliance.js` 第 53 行
**问题**：`new RegExp(pattern, "i")` 若 pattern 非法会抛异常，被 catch 后静默放行
**修复**：在构造 RegExp 前加 try-catch，非法 pattern 应记录并跳过，而非通过 catch 静默放行：
```javascript
let regex;
try {
  regex = new RegExp(pattern, "i");
} catch (e) {
  console.log(JSON.stringify({ decision: "allow", note: `invalid regex pattern: ${pattern}` }));
  continue;
}
if (regex.test(content)) { ... }
```

#### 7. README.md 缺少 MCP 卸载说明
**位置**：`README.md`
**问题**：规范要求有 MCP 时必须写卸载说明，无 MCP 时应标注
**修复**：在「清理说明」章节添加：
```markdown
## MCP 说明

本 Team 未使用 MCP（Model Context Protocol），无需额外卸载步骤。
```

---

### 🟢 P2 — 优化项

#### 8. xiaohongshu-style-writer SKILL.md 缺少执行步骤
**位置**：`.claude/skills/xiaohongshu-style-writer/SKILL.md`
**问题**：Skill 规范要求 3-7 个执行步骤，但此文件只有风格规则和模板，无操作流程
**修复**：添加「执行步骤」章节，例如：
```markdown
## 执行步骤

### Step 1: 理解主题
阅读用户提供的主题关键词和补充需求。

### Step 2: 选择模板
根据主题类型（种草/教程/分享）选择对应模板。

### Step 3: 撰写正文
按风格规则填充模板，控制段落长度和 emoji 密度。

### Step 4: 添加标签
在文末添加 3-5 个相关话题标签。

### Step 5: 生成图片提示词
为推文配图撰写英文结构化提示词。
```

#### 9. settings.json acceptEdits 仍过于宽松
**位置**：`.claude/settings.json`
**问题**：`defaultMode: acceptEdits` 会自动接受所有编辑操作，与最小权限原则有冲突
**修复**：改为 `defaultMode: ask`，或在 README 中明确说明「本 Team 使用 acceptEdits 以提升交互流畅度」

---

## 修复优先级

| 优先级 | 问题编号 | 影响维度 |
|--------|---------|---------|
| P0 | 1, 2, 3, 4 | 可执行性、格式规范 |
| P1 | 5, 6, 7 | 内容质量、安全性、文档完整性 |
| P2 | 8, 9 | 内容质量、安全性 |
