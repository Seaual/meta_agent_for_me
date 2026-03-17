## Sentinel 修复指令（第 1 轮）

以下问题需要修复后重新提交审查：

### 问题 1
- **问题**：[trend-scraper.md] 无效工具名：'WebFetch'（有效：Read Write Edit Bash Grep Glob） 
- **修复**： 修复：将 'WebFetch' 替换为有效工具名

### 问题 2
- **问题**：[SKILL.md] 缺少 name 字段 
- **修复**： 修复：添加 name: kebab-case-name

### 问题 3
- **问题**：[SKILL.md] 缺少 description 字段 
- **修复**： 修复：添加 description: | 并按触发条件公式填写

### 问题 4
- **问题**：[SKILL.md] 缺少 allowed-tools 字段 
- **修复**： 修复：添加 allowed-tools: Read

### 问题 5
- **问题**：[SKILL.md] 缺少 name 字段 
- **修复**： 修复：添加 name: kebab-case-name

### 问题 6
- **问题**：[SKILL.md] 缺少 description 字段 
- **修复**： 修复：添加 description: | 并按触发条件公式填写

### 问题 7
- **问题**：[SKILL.md] 缺少 allowed-tools 字段 
- **修复**： 修复：添加 allowed-tools: Read

### 问题 8
- **问题**：[SKILL.md] 缺少 name 字段 
- **修复**： 修复：添加 name: kebab-case-name

### 问题 9
- **问题**：[SKILL.md] 缺少 description 字段 
- **修复**： 修复：添加 description: | 并按触发条件公式填写

### 问题 10
- **问题**：[SKILL.md] 缺少 allowed-tools 字段 
- **修复**： 修复：添加 allowed-tools: Read

### 问题 11
- **问题**：[trend-processor.md] 描述了写文件操作，但 allowed-tools 无 Write/Edit 
- **修复**： 修复：添加 Edit（推荐）或 Write 到 allowed-tools

### 问题 12
- **问题**：[trend-scraper.md] 描述了写文件操作，但 allowed-tools 无 Write/Edit 
- **修复**： 修复：添加 Edit（推荐）或 Write 到 allowed-tools

### 问题 13
- **问题**：README.md 缺少「Team 成员」章节 
- **修复**： 修复：在 README.md 中添加 ## Team 成员 章节

### 问题 14
- **问题**：README.md 缺少「文件树」章节 
- **修复**： 修复：在 README.md 中添加 ## 文件树 章节

### 问题 15
- **问题**：README.md 缺少 teardown 说明（用完后如何清理） 
- **修复**： 修复：在 README.md 中添加「清理与卸载」章节，说明：workspace 清理命令、MCP 卸载步骤、全局 skill 移除方式

### 问题 16
- **问题**：有 MCP 集成但 README.md 缺少 MCP 卸载说明 
- **修复**： 修复：在 README.md 的「清理与卸载」章节中说明如何从 settings.json 移除 mcpServers 配置

### 问题 17
- **问题**：未找到任何 workspace 清理机制（workspace-init skill 或 README teardown 说明） 
- **修复**： 修复：添加 workspace-init skill 或在 README 中提供清理命令：rm -f .claude/workspace/phase-*.md

