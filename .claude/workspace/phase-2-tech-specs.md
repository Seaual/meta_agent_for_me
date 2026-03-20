# Visionary-Tech 规格

**基于**：phase-1-architecture.md
**负责范围**：工具权限 + Skill/MCP + Workspace 协议

---

## 工具权限分配

| Agent | allowed-tools | Bash 使用场景 |
|-------|--------------|---------------|
| **domain-researcher** | Read, WebSearch, WebFetch | — |
| **learning-roadmap-planner** | Read, Write, WebSearch, WebFetch | — |

### 工具权限说明

| 工具 | domain-researcher | learning-roadmap-planner | 使用场景说明 |
|-----|------------------|-------------------------|-------------|
| `Read` | 读取需求文件、上游输出 | 读取需求文件、领域知识 | 基础只读操作 |
| `WebSearch` | 搜索低空经济政策、TSP 文献 | 搜索课程资源、GitHub 仓库 | 网络信息检索 |
| `WebFetch` | 抓取行业报告全文 | 抓取课程详情、论文摘要 | 深入获取网页内容 |
| `Write` | — | 输出最终学习路线文档 | 创建最终交付物 |

**Bash 不需要**：本 Team 所有操作均可通过内置工具完成，无需执行外部命令。

---

## Skill 需求 + 搜索提示

### 可复用 Skill 清单

| 需求描述 | 搜索关键词 | 使用的 Agent | 候选 Skill | 安装量 | 推荐度 |
|---------|-----------|-------------|-----------|--------|-------|
| 系统性网络研究 | web research | domain-researcher | `langchain-ai/deepagents@web-research` | 941 | ★★★★★ |
| 学术文献研究 | academic research | domain-researcher | `shubhamsaboo/awesome-llm-apps@academic-researcher` | 2.1K | ★★★★★ |
| GitHub 代码搜索 | github search | learning-roadmap-planner | `parcadei/continuous-claude-v3@github-search` | 316 | ★★★★☆ |
| 学习路径设计 | learning path | learning-roadmap-planner | `rysweet/amplihack@learning-path-builder` | 134 | ★★★★☆ |

### Skill 决策建议

**domain-researcher** 建议安装：
- `langchain-ai/deepagents@web-research` — 系统性网络研究流程
- `shubhamsaboo/awesome-llm-apps@academic-researcher` — 学术研究方法论

**learning-roadmap-planner** 建议安装：
- `rysweet/amplihack@learning-path-builder` — 学习路径结构化设计

**可选**（GitHub MCP 未配置时）：
- `parcadei/continuous-claude-v3@github-search` — 通过 WebSearch 增强 GitHub 搜索能力

### Agent 搜索提示（供 Library Scout 使用）

| 目标 Agent | 搜索关键词 | 期望的核心能力 |
|-----------|-----------|--------------|
| domain-researcher | academic researcher, domain expert, knowledge graph | 领域知识调研、文献综述、知识图谱构建 |
| learning-roadmap-planner | learning path, curriculum designer, education planner | 学习路径设计、资源整合、时间规划 |

---

## 需原创的 Skill

**结论：无需原创 Skill**

理由：
1. `web-research` 和 `academic-researcher` 已有成熟方案，直接安装
2. `learning-path-builder` 可满足学习路径设计需求
3. 本 Team 核心是信息检索与整合，不涉及特殊业务逻辑

---

## MCP 集成配置

### 推荐配置（可选）

`.claude/settings.json` 配置段：

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-github"],
      "env": {
        "GITHUB_TOKEN": "请填入"
      }
    }
  }
}
```

### MCP 需求表

| MCP | 使用的 Agent | 需要的 Token | 获取方式 |
|-----|------------|-------------|---------|
| GitHub（可选） | learning-roadmap-planner | GITHUB_TOKEN | https://github.com/settings/tokens |

### 降级策略

如果 GitHub MCP 未配置：
1. `learning-roadmap-planner` 使用 `WebSearch` 搜索 `github.com` 上的相关仓库
2. 使用 `WebFetch` 获取仓库详情（README、星标数、最近更新）
3. 功能完整度约 80%，满足基本需求

---

## Hook 配置

**Profile 级别**：minimal

### 标准 Hook（minimal 级别）

| 脚本 | 事件 | Profile | 实现要点 |
|------|------|---------|---------|
| `pre-tool-safety.js` | PreToolUse(Bash) | minimal+ | 阻止 `rm -rf /`、硬编码凭证、`eval` 注入 |

**说明**：minimal 级别仅启用安全检查 hook。由于本 Team 无 Bash 权限，hook 主要作为防护层。

### settings.json hooks 配置段

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "node scripts/hooks/pre-tool-safety.js",
        "timeout": 5
      }]
    }]
  }
}
```

### 自定义 Hook

**无需自定义 Hook**

理由：
1. 本 Team 无 Bash 权限，无需额外安全限制
2. 无共享文件写入冲突风险
3. 任务性质为一次性文档生成，无需会话摘要

---

## Workspace 文件协议

### 文件清单

| 文件 | 写入者 | 读取者 | 格式说明 |
|-----|-------|-------|---------|
| `phase-0-requirements.md` | director-council | domain-researcher, learning-roadmap-planner | 需求文档（只读） |
| `domain-knowledge.md` | domain-researcher | learning-roadmap-planner | Markdown 结构化知识图谱 |
| `learning-roadmap.md` | learning-roadmap-planner | 用户（最终交付） | Markdown 学习路线文档 |

### 传递顺序

```
phase-0-requirements.md
         │
         ├──────────────────────────┐
         ▼                          ▼
  domain-researcher          learning-roadmap-planner
   (context: fork)              (等待上游)
         │                          │
         ▼                          │
   domain-knowledge.md ────────────┘
                                   │
                                   ▼
                         learning-roadmap.md → 最终交付
```

### 文件格式规范

**domain-knowledge.md** 结构：
```markdown
# 领域知识图谱

## 低空经济
- 政策框架
- 产业现状
- 研究热点

## TSP 问题
- 经典变体
- 算法演进
- 近期突破

## 路线规划（低空场景）
- 特殊约束
- 应用场景
- 研究空白

## 研究热点矩阵
| 方向 | 成熟度 | 创新空间 | 推荐度 |
|-----|-------|---------|-------|
```

**learning-roadmap.md** 结构：
```markdown
# 低空经济研究方向学习路线

## 1. 领域知识概览
## 2. 学习路径设计
### 2.1 课程轨道
### 2.2 文献轨道
### 2.3 实践轨道
## 3. 资源清单
### 3.1 GitHub 代码
### 3.2 学术论文
### 3.3 课程资源
## 4. 时间规划
## 5. 研究切入点建议

---
**生成时间**：[timestamp]
**风险提示**：半年内从新手到 SCI 一区难度极高，建议...
```

---

## 辅助脚本需求

**无需辅助脚本**

理由：
1. 无需执行外部命令（无 Bash 权限）
2. 所有数据处理由 agent 内置能力完成
3. 输出为纯 Markdown，无需格式转换

---

## 与 Visionary-UX 的注意点

### 工具权限与 Prompt 设计的配合

| Agent | 工具约束 | UX Prompt 需要说明 |
|-------|---------|------------------|
| domain-researcher | 无 Write 权限 | 在 prompt 中明确输出到 `domain-knowledge.md`，而非直接返回 |
| learning-roadmap-planner | 有 Write 权限 | 使用 `Write` 工具创建 `learning-roadmap.md`，确保原子写入 |

### Fork Agent 的 Prompt 设计

`domain-researcher` 使用 `context: fork`，UX 设计需：
1. 明确告知其独立运行，不等待其他 agent
2. 输出文件名固定为 `domain-knowledge.md`
3. Prompt 中包含「完成后立即写入，无需等待确认」的指令

### 等待逻辑的 Prompt 设计

`learning-roadmap-planner` 需等待上游，UX 设计需：
1. 启动时检查 `domain-knowledge.md` 是否存在
2. 若不存在，提示用户先运行 `domain-researcher`
3. 读取后继续执行，不阻塞

---

## Skill 安装命令（供 toolsmith-skills 使用）

```bash
# 必装（domain-researcher）
npx skills add langchain-ai/deepagents@web-research
npx skills add shubhamsaboo/awesome-llm-apps@academic-researcher

# 必装（learning-roadmap-planner）
npx skills add rysweet/amplihack@learning-path-builder

# 可选（GitHub MCP 替代方案）
npx skills add parcadei/continuous-claude-v3@github-search
```

---

## 技术风险与缓解

| 风险 | 影响 | 缓解措施 |
|-----|------|---------|
| Skill 安装失败 | 部分功能降级 | 使用内置 WebSearch + WebFetch 替代 |
| GitHub MCP 未配置 | 代码搜索能力受限 | 降级为 WebSearch 搜索 github.com |
| WebSearch API 限制 | 信息检索中断 | 分批检索，使用 WebFetch 补充详情 |

---

## 完成检查清单

- [x] 工具权限分配完成（2 个 agent）
- [x] Skill 搜索完成，找到 4 个候选
- [x] MCP 配置设计完成（GitHub 可选）
- [x] Hook 配置设计完成（minimal 级别）
- [x] Workspace 文件协议设计完成
- [x] 与 UX 的注意点标注完成