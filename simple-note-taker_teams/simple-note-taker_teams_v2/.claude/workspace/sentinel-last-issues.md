## Sentinel 修复指令（第 1 轮）

以下问题需要修复后重新提交审查：

### 问题 1
- **问题**：[memory-analyst.md] 缺少完整 YAML frontmatter（需要开头和结尾的 ---） 
- **修复**： 修复：在文件第1行添加 ---，在字段结束后添加 ---

### 问题 2
- **问题**：[skill-extractor.md] name '{{skill-name}}' 不是 kebab-case（应为小写字母、数字、连字符） 
- **修复**： 修复：将 name 改为 kebab-case 格式，如：{{skill-name}}

### 问题 3
- **问题**：[skill-extractor.md] description 过短（0 行，建议 ≥3 行） 
- **修复**： 修复：补充触发场景、关键词和排除项

### 问题 4
- **问题**：[skill-extractor.md] 缺少 allowed-tools 字段 
- **修复**： 修复：添加 allowed-tools: Read

### 问题 5
- **问题**：[skill-extractor.md] Agent 提示词结构层次不足（找到 1/3 个关键层） 
- **修复**： 修复：确保包含：身份定义、执行步骤、输出规范

### 问题 6
- **问题**：[CLAUDE.md] 缺少完整 YAML frontmatter（需要开头和结尾的 ---） 
- **修复**： 修复：在文件第1行添加 ---，在字段结束后添加 ---

### 问题 7
- **问题**：[README.md] 缺少完整 YAML frontmatter（需要开头和结尾的 ---） 
- **修复**： 修复：在文件第1行添加 ---，在字段结束后添加 ---

### 问题 8
- **问题**：[memory-architecture.md] 缺少 name 字段 
- **修复**： 修复：添加 name: kebab-case-name

### 问题 9
- **问题**：[memory-architecture.md] 缺少 description 字段 
- **修复**： 修复：添加 description: | 并按触发条件公式填写

### 问题 10
- **问题**：[memory-architecture.md] 缺少 allowed-tools 字段 
- **修复**： 修复：添加 allowed-tools: Read

### 问题 11
- **问题**：[promotion-rules.md] 缺少完整 YAML frontmatter（需要开头和结尾的 ---） 
- **修复**： 修复：在文件第1行添加 ---，在字段结束后添加 ---

### 问题 12
- **问题**：[rules-directory-patterns.md] 缺少 name 字段 
- **修复**： 修复：添加 name: kebab-case-name

### 问题 13
- **问题**：[rules-directory-patterns.md] 缺少 description 字段 
- **修复**： 修复：添加 description: | 并按触发条件公式填写

### 问题 14
- **问题**：[rules-directory-patterns.md] 缺少 allowed-tools 字段 
- **修复**： 修复：添加 allowed-tools: Read

### 问题 15
- **问题**：[SKILL.md] description 过短（0 行，建议 ≥3 行） 
- **修复**： 修复：补充触发场景、关键词和排除项

### 问题 16
- **问题**：[SKILL.md] 缺少 allowed-tools 字段 
- **修复**： 修复：添加 allowed-tools: Read

### 问题 17
- **问题**：[SKILL.md] description 过短（0 行，建议 ≥3 行） 
- **修复**： 修复：补充触发场景、关键词和排除项

### 问题 18
- **问题**：[SKILL.md] 缺少 allowed-tools 字段 
- **修复**： 修复：添加 allowed-tools: Read

### 问题 19
- **问题**：[SKILL.md] description 过短（0 行，建议 ≥3 行） 
- **修复**： 修复：补充触发场景、关键词和排除项

### 问题 20
- **问题**：[SKILL.md] 缺少 allowed-tools 字段 
- **修复**： 修复：添加 allowed-tools: Read

### 问题 21
- **问题**：[SKILL.md] description 过短（0 行，建议 ≥3 行） 
- **修复**： 修复：补充触发场景、关键词和排除项

### 问题 22
- **问题**：[SKILL.md] 缺少 allowed-tools 字段 
- **修复**： 修复：添加 allowed-tools: Read

### 问题 23
- **问题**：[SKILL.md] description 过短（0 行，建议 ≥3 行） 
- **修复**： 修复：补充触发场景、关键词和排除项

### 问题 24
- **问题**：[SKILL.md] 缺少 allowed-tools 字段 
- **修复**： 修复：添加 allowed-tools: Read

### 问题 25
- **问题**：[SKILL.md] description 过短（0 行，建议 ≥3 行） 
- **修复**： 修复：补充触发场景、关键词和排除项

### 问题 26
- **问题**：[SKILL.md] 缺少 allowed-tools 字段 
- **修复**： 修复：添加 allowed-tools: Read

### 问题 27
- **问题**：[rule-template.md] 缺少 name 字段 
- **修复**： 修复：添加 name: kebab-case-name

### 问题 28
- **问题**：[rule-template.md] 缺少 description 字段 
- **修复**： 修复：添加 description: | 并按触发条件公式填写

### 问题 29
- **问题**：[rule-template.md] 缺少 allowed-tools 字段 
- **修复**： 修复：添加 allowed-tools: Read

### 问题 30
- **问题**：[skill-template.md] name '{{skill-name}}' 不是 kebab-case（应为小写字母、数字、连字符） 
- **修复**： 修复：将 name 改为 kebab-case 格式，如：{{skill-name}}

### 问题 31
- **问题**：[skill-template.md] description 过短（0 行，建议 ≥3 行） 
- **修复**： 修复：补充触发场景、关键词和排除项

### 问题 32
- **问题**：[skill-template.md] 缺少 allowed-tools 字段 
- **修复**： 修复：添加 allowed-tools: Read

### 问题 33
- **问题**：CLAUDE.md 中引用了不存在的 agent：summarize 
- **修复**： 修复：创建缺失的 agent 文件，或从 CLAUDE.md 中移除引用

### 问题 34
- **问题**：CLAUDE.md 缺少「上下文传递协议」章节 
- **修复**： 修复：添加 ## 上下文传递协议 章节，参考 Meta-Agents 模板

### 问题 35
- **问题**：CLAUDE.md 缺少「降级规则」章节 
- **修复**： 修复：添加 ## 降级规则 章节，参考 Meta-Agents 模板

### 问题 36
- **问题**：CLAUDE.md 缺少「工作流程」章节 
- **修复**： 修复：添加 ## 工作流程 章节，参考 Meta-Agents 模板

### 问题 37
- **问题**：README.md 缺少「文件树」章节 
- **修复**： 修复：在 README.md 中添加 ## 文件树 章节

### 问题 38
- **问题**：README.md 缺少「协作流程」章节 
- **修复**： 修复：在 README.md 中添加 ## 协作流程 章节

### 问题 39
- **问题**：README.md 缺少「快速启动」章节 
- **修复**： 修复：在 README.md 中添加 ## 快速启动 章节

### 问题 40
- **问题**：README.md 缺少 teardown 说明（用完后如何清理） 
- **修复**： 修复：在 README.md 中添加「清理与卸载」章节，说明：workspace 清理命令、MCP 卸载步骤、全局 skill 移除方式

### 问题 41
- **问题**：未找到任何 workspace 清理机制（workspace-init skill 或 README teardown 说明） 
- **修复**： 修复：添加 workspace-init skill 或在 README 中提供清理命令：rm -f .claude/workspace/phase-*.md

