# Skill Scout 决策表 — question-generator

## 搜索结果摘要

| 需求 | 本地 skills.sh | 在线 skills.sh | 决策 |
|------|---------------|----------------|------|
| **self-improving-agent** | infra-self-improving 可用 | 可安装 | 复用本地 |
| **instinct-engine** | 无 | 无 | 原创（内置到 self-improving-agent）|
| **PDF 解析** | 不需要 | — | 使用 Claude 内置 |
| **pandoc 检测** | 无 | 无 | 原创（脚本）|
| **pre-tool-safety** | infra-hooks-gen 可用 | — | 复用本地 |

---

## 详细决策

### self-improving-agent
- **决策**：复用本地 `infra-self-improving`
- **理由**：本地已有 `infra-self-improving` skill，可配置 .learnings/ 目录和 CLAUDE.md 引用。
- **来源**：`.claude/skills/infra-self-improving/SKILL.md`
- **评分**：95/100（完全匹配）

### instinct-engine
- **决策**：原创（作为 self-improving-agent 的扩展）
- **理由**：本地和在线均无独立的 instinct-engine skill。将其作为 self-improving-agent skill 的内部逻辑实现，在 `.learnings/instincts/` 目录下提炼模式。
- **需要辅助脚本**：no
- **评分**：N/A（原创）

### PDF 解析
- **决策**：不需要独立 skill
- **理由**：Claude 内置 PDF 读取能力，agent 直接使用 Read 工具读取 PDF 文件即可。
- **评分**：N/A

### pandoc 检测脚本
- **决策**：原创
- **理由**：需要简单的 shell 脚本检测 pandoc 是否安装，供 word-exporter agent 调用。
- **脚本名**：`check-pandoc.sh`
- **需要辅助脚本**：yes
- **评分**：N/A（原创）

### pre-tool-safety.js（Hook）
- **决策**：复用本地 `infra-hooks-gen`
- **理由**：本地已有 `infra-hooks-gen` skill 可生成标准 hook 脚本，根据 Profile: minimal 只生成安全检查 hook。
- **来源**：`.claude/skills/infra-hooks-gen/SKILL.md`
- **评分**：90/100

---

## 最终统计

| 来源 | 数量 | Skill 列表 |
|------|------|-----------|
| **复用本地** | 2 | self-improving-agent（via infra-self-improving）, pre-tool-safety（via infra-hooks-gen）|
| **原创** | 2 | instinct-engine（内置）, check-pandoc.sh（脚本）|
| **不需要** | 1 | PDF 解析（Claude 内置）|

**总计**：4 个 skill/脚本（2 复用 + 2 原创）