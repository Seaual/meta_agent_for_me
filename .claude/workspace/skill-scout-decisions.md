# Skill Scout 决策表

## 1. web-research

| 候选 | 来源 | 安装量 | 评分明细 | 总分 | 决策 |
|-----|------|-------|---------|------|------|
| `langchain-ai/deepagents@web-research` | skills.sh | 942 | 匹配38 + 安装15 + 兼容18 + 改造18 | **89/100** | ✅ 安装 |
| `yonatangross/orchestkit@web-research-workflow` | skills.sh | 79 | 匹配32 + 安装10 + 兼容15 + 改造15 | 72/100 | 备选 |
| `pollinations/pollinations@web-research` | skills.sh | 60 | 匹配30 + 安装10 + 兼容14 + 改造14 | 68/100 | 备选 |

**最终决策**：✅ 安装 `langchain-ai/deepagents@web-research`

**评分理由**：
- 功能匹配度 38/40：LangChain 是知名框架，web-research 流程完善，支持系统性网络调研
- 安装量/可信度 15/20：942 installs 接近 1K 阈值，社区验证充分
- 接口兼容性 18/20：输出 Markdown 格式，与 domain-researcher 的需求一致
- 定制改造成本 18/20：无需修改，直接集成

---

## 2. academic-researcher

| 候选 | 来源 | 安装量 | 评分明细 | 总分 | 决策 |
|-----|------|-------|---------|------|------|
| `shubhamsaboo/awesome-llm-apps@academic-researcher` | skills.sh | 2.1K | 匹配39 + 安装20 + 兼容18 + 改造16 | **93/100** | ✅ 安装 |
| `silupanda/academic-researcher@academic-researcher` | skills.sh | 80 | 匹配35 + 安装10 + 兼容15 + 改造14 | 74/100 | 备选 |
| `smithery.ai@academic-researcher` | skills.sh | 24 | 匹配32 + 安装10 + 兼容12 + 改造12 | 66/100 | 备选 |

**最终决策**：✅ 安装 `shubhamsaboo/awesome-llm-apps@academic-researcher`

**评分理由**：
- 功能匹配度 39/40：awesome-llm-apps 是知名 LLM 应用集合，学术研究方法论成熟
- 安装量/可信度 20/20：2.1K installs，高信任度
- 接口兼容性 18/20：支持文献综述、知识图谱输出
- 定制改造成本 16/20：可能需要小幅调整输出格式以适配 domain-knowledge.md

---

## 3. github-search

| 候选 | 来源 | 安装量 | 评分明细 | 总分 | 决策 |
|-----|------|-------|---------|------|------|
| `parcadei/continuous-claude-v3@github-search` | skills.sh | 316 | 匹配36 + 安装15 + 兼容17 + 改造15 | **83/100** | ✅ 安装 |
| `samhvw8/dotfiles@github-search` | skills.sh | 18 | 匹配28 + 安装10 + 兼容12 + 改造12 | 62/100 | 备选 |

**最终决策**：✅ 安装 `parcadei/continuous-claude-v3@github-search`（可选，GitHub MCP 替代方案）

**评分理由**：
- 功能匹配度 36/40：GitHub 搜索是标准功能，支持代码仓库检索
- 安装量/可信度 15/20：316 installs，中等信任度
- 接口兼容性 17/20：输出格式可被 learning-roadmap-planner 使用
- 定制改造成本 15/20：需与 WebSearch 配合使用

**备注**：此 Skill 为 GitHub MCP 的降级替代方案。若用户配置了 GitHub MCP，可跳过安装。

---

## 4. learning-path-builder

| 候选 | 来源 | 安装量 | 评分明细 | 总分 | 决策 |
|-----|------|-------|---------|------|------|
| `rysweet/amplihack@learning-path-builder` | skills.sh | 134 | 匹配37 + 安装15 + 兼容18 + 改造17 | **87/100** | ✅ 安装 |
| `jorgealves/agent_skills@module-learning-path-generator` | skills.sh | 64 | 匹配34 + 安装10 + 兼容15 + 改造14 | 73/100 | 备选 |
| `eddiebe147/claude-settings@learning-path-creator` | skills.sh | 53 | 匹配33 + 安装10 + 兼容14 + 改造14 | 71/100 | 备选 |

**最终决策**：✅ 安装 `rysweet/amplihack@learning-path-builder`

**评分理由**：
- 功能匹配度 37/40：amplihack 提供结构化学习路径设计方法论
- 安装量/可信度 15/20：134 installs，足够社区验证
- 接口兼容性 18/20：输出 Markdown 格式学习路线，符合需求
- 定制改造成本 17/20：可能需要调整时间规划部分

---

## 需要提前执行的安装命令

```bash
# 必装（domain-researcher 使用）
npx skills add langchain-ai/deepagents@web-research -a claude-code -g -y
npx skills add shubhamsaboo/awesome-llm-apps@academic-researcher -a claude-code -g -y

# 必装（learning-roadmap-planner 使用）
npx skills add rysweet/amplihack@learning-path-builder -a claude-code -g -y

# 可选（GitHub MCP 替代方案，用户未配置 GitHub MCP 时安装）
npx skills add parcadei/continuous-claude-v3@github-search -a claude-code -g -y
```

---

## 改编参考信息

| Skill | 参考路径 | 参考的设计点 | 是否需要改编 |
|-------|---------|------------|------------|
| web-research | `~/.claude/skills/langchain-ai/deepagents/web-research/` | 系统性网络调研流程 | 否 |
| academic-researcher | `~/.claude/skills/shubhamsaboo/awesome-llm-apps/academic-researcher/` | 文献综述方法论、知识图谱构建 | 小幅调整输出格式 |
| github-search | `~/.claude/skills/parcadei/continuous-claude-v3/github-search/` | GitHub 搜索增强 | 否 |
| learning-path-builder | `~/.claude/skills/rysweet/amplihack/learning-path-builder/` | 学习路径结构化设计 | 小幅调整时间规划 |

---

## 汇总

| Skill 名称 | 决策 | 来源 | 得分 | 安装说明 |
|-----------|------|------|------|---------|
| web-research | ✅ 安装 | skills.sh | 89/100 | 必装 |
| academic-researcher | ✅ 安装 | skills.sh | 93/100 | 必装 |
| github-search | ✅ 安装 | skills.sh | 83/100 | 可选（GitHub MCP 替代） |
| learning-path-builder | ✅ 安装 | skills.sh | 87/100 | 必装 |

**无需原创 Skill**：所有需求均有成熟方案可直接安装。