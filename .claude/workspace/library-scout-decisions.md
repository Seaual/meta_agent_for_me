# Library Scout 决策表

生成时间：2026-03-17
Team 名称：tutorial-generator
VoltAgent 路径：./awesome-claude-code-subagents/
agency-agents 路径：./agency-agents/
skills.sh 在线搜索：已启用（npx 可用）

---

## Agent 复用决策

| Agent名称 | 决策 | 候选文件 | 评分 | 改编要点 |
|----------|------|---------|-----|---------|
| file-analyzer | ✏️ 原创 | — | — | 无完全匹配的候选，需从零创建 |
| content-writer | 🔧 改编 | agency-agents/engineering/engineering-technical-writer.md | 75/100 | 保留模板结构和教程设计，修改工具权限（移除 WebFetch/WebSearch） |
| exercise-designer | ✏️ 原创 | — | — | 无专门编程练习题设计 agent，需从零创建 |
| content-reviewer | ✏️ 原创 | — | — | 无文档审查专用 agent，需从零创建 |
| assembler | ✏️ 原创 | — | — | 无匹配 agent，需从零创建 |

---

## Agent 参考候选（供 toolsmith-agents 参考）

**即使决策为「原创」，以下候选的设计模式仍可参考：**

| 目标 Agent | Top 候选 | 来源 | 得分 | 可参考的设计点 |
|-----------|---------|------|------|------------|
| file-analyzer | context-manager | VoltAgent/categories/09-meta-orchestration/ | 35/100 | 五层结构完整（身份→执行框架→输出规范）、检查清单设计模式 |
| content-writer | engineering-technical-writer | agency-agents/engineering/ | 75/100 | README 模板、教程结构模板、Divio 文档系统、代码示例验证流程 |
| content-writer | technical-writer | VoltAgent/categories/08-business-product/ | 65/100 | 文档类型分类、写作技术、API 文档最佳实践 |
| content-writer | documentation-engineer | VoltAgent/categories/06-developer-experience/ | 60/100 | 教程创建流程、代码示例管理、文档测试检查清单 |
| exercise-designer | corporate-training-designer | agency-agents/specialized/ | 50/100 | Bloom 认知分类法、练习设计方法论、评估体系设计 |
| content-reviewer | code-reviewer | VoltAgent/categories/04-quality-security/ | 55/100 | 审查检查清单、问题分类方法、反馈框架、进度跟踪 |
| assembler | specialized-document-generator | agency-agents/specialized/ | 40/100 | 文档格式规范、输出质量控制 |

> toolsmith-agents 在原创时**必须参考以上候选的结构和设计模式**，
> 确保每个 agent 都有完整的五层结构（身份→风格→执行框架→输出规范→边界处理）。

---

## content-writer 改编详情（75分，改编复用）

**来源**：`agency-agents/engineering/engineering-technical-writer.md`

**保留部分**：
- README 模板结构
- 教程结构模板（Step-by-step 格式）
- 文档质量标准（代码示例必须可运行、版本控制等）
- Divio 文档系统分类（tutorial/how-to/reference/explanation）
- 写作风格指南（第二人称、主动语态等）

**修改部分**：
- 移除工具权限：WebFetch, WebSearch（本 team 无网络需求）
- 添加 workspace 文件协议：读取 `project-structure.md`，输出到 `tutorial-content.md`
- 添加反馈处理逻辑：读取 `review-feedback.md`，修改 `tutorial-content.md`
- 简化为单一职责：专注于教程内容编写，移除 API 文档、SDK 文档等分支

---

## Skill 复用决策

| Skill名称 | 决策 | 来源 | 安装命令 | 理由 |
|----------|------|-----|---------|------|
| self-improving-agent | ✅ 直接复用 | ~/.claude/skills/self-improving-agent/ | cp -r | 已安装，功能完全匹配 |
| document-review | 🔍 参考逻辑 | ~/.claude/skills/document-review/ | 不安装 | 供 content-reviewer 参考审查流程，不直接安装到项目 |

---

## 已安装 Skill 详情

### self-improving-agent（直接复用）

**位置**：`~/.claude/skills/self-improving-agent/`

**功能**：
- 分析 MEMORY.md 中的模式，识别可推广的候选
- 将已验证的模式提升到 CLAUDE.md 或 `.claude/rules/`
- 从重复解决方案中提取可复用 skill
- 监控记忆健康状态和容量

**安装到项目**：
```bash
cp -r ~/.claude/skills/self-improving-agent/ [OUTPUT_DIR]/.claude/skills/
```

### document-review（参考逻辑，不安装）

**位置**：`~/.claude/skills/document-review/`

**可参考的设计点**：
- 五步审查流程（获取文档→评估→评价→识别关键改进→修改）
- 评估维度：清晰度、完整性、具体性、YAGNI 原则
- 自动修复 vs 人工确认的边界

---

## 执行摘要

**Agent 统计**：
- 直接复用：0 个
- 改编复用：1 个（content-writer）
- 原创：4 个（file-analyzer, exercise-designer, content-reviewer, assembler）

**Skill 统计**：
- 直接安装：1 个（self-improving-agent）
- 参考逻辑：1 个（document-review，不安装）
- 原创：0 个

---

## 需要提前执行的安装命令

**toolsmith-skills 执行前无需额外安装**，self-improving-agent 已在本地，直接复制即可：

```bash
# 由 toolsmith-skills 执行
OUTPUT_DIR=$(cat .claude/workspace/output-dir.txt)
mkdir -p "$OUTPUT_DIR/.claude/skills/self-improving-agent"
cp -r ~/.claude/skills/self-improving-agent/* "$OUTPUT_DIR/.claude/skills/self-improving-agent/"
```

---

## 改编参考信息（供 toolsmith-agents 使用）

| Agent | 参考 agent 路径 | 参考的设计点 |
|-------|----------------|-------------|
| content-writer | D:/agentset/agency-agents/engineering/engineering-technical-writer.md | 教程结构模板、README 模板、代码示例验证流程、写作风格指南 |
| content-reviewer | D:/agentset/awesome-claude-code-subagents/categories/04-quality-security/code-reviewer.md | 审查检查清单设计模式、问题分类方法、反馈框架 |
| file-analyzer | D:/agentset/awesome-claude-code-subagents/categories/09-meta-orchestration/context-manager.md | 五层 Prompt 结构、检查清单设计模式 |
| exercise-designer | D:/agentset/agency-agents/specialized/corporate-training-designer.md | Bloom 认知分类法、练习设计方法论、评估体系 |
| assembler | D:/agentset/agency-agents/specialized/specialized-document-generator.md | 文档格式规范、输出质量控制 |

---

## 评分矩阵说明

### Agent 评分标准（100分制）

| 维度 | 满分 | 说明 |
|-----|------|------|
| 职责匹配度 | 40 | 候选 description vs 目标职责，越接近越高 |
| Prompt 质量 | 20 | 是否有完整五层结构、边界处理、降级策略 |
| 工具权限兼容 | 20 | allowed-tools 差异，完全一致=20，差一项-5 |
| 定制改造成本 | 20 | 需修改比例：<10%=20, 10-30%=15, 30-60%=8, >60%=2 |

### 评分结果

**content-writer (engineering-technical-writer)**：
- 职责匹配度：30/40（教程编写匹配，但有 API 文档等额外内容）
- Prompt 质量：18/20（结构完整，模板丰富）
- 工具权限兼容：12/20（有 WebFetch/WebSearch，需移除）
- 定制改造成本：15/20（需修改约 20% 内容）
- **总分：75/100**

**code-reviewer（content-reviewer 参考）**：
- 职责匹配度：20/40（代码审查 vs 文档审查，有差距）
- Prompt 质量：15/20（结构完整，但领域不同）
- 工具权限兼容：15/20（有 Bash 权限，需移除）
- 定制改造成本：5/20（需修改 >60% 内容）
- **总分：55/100**