## Sentinel 修复指令（第 1 轮）

以下问题需要修复后重新提交审查：

### 问题 1
- **问题**：CLAUDE.md 中引用了不存在的 agent：pre-commit review 
- **修复**： 修复：创建缺失的 agent 文件，或从 CLAUDE.md 中移除引用

### 问题 2
- **问题**：CLAUDE.md 缺少「上下文传递协议」章节 
- **修复**： 修复：添加 ## 上下文传递协议 章节，参考 Meta-Agents 模板

### 问题 3
- **问题**：CLAUDE.md 缺少「降级规则」章节 
- **修复**： 修复：添加 ## 降级规则 章节，参考 Meta-Agents 模板

### 问题 4
- **问题**：CLAUDE.md 缺少「工作流程」章节 
- **修复**： 修复：添加 ## 工作流程 章节，参考 Meta-Agents 模板

### 问题 5
- **问题**：README.md 缺少「Team 成员」章节 
- **修复**： 修复：在 README.md 中添加 ## Team 成员 章节

### 问题 6
- **问题**：README.md 缺少「文件树」章节 
- **修复**： 修复：在 README.md 中添加 ## 文件树 章节

### 问题 7
- **问题**：README.md 缺少「协作流程」章节 
- **修复**： 修复：在 README.md 中添加 ## 协作流程 章节

### 问题 8
- **问题**：README.md 缺少「快速启动」章节 
- **修复**： 修复：在 README.md 中添加 ## 快速启动 章节

### 问题 9
- **问题**：[code-reviewer.md] 执行框架步骤过少（0 步，建议 ≥2） 
- **修复**： 修复：补充具体执行步骤

### 问题 10
- **问题**：.claude/skills/ 目录为空或不存在 
- **修复**： 修复：运行 toolsmith-skills 生成 skill 文件，或在 CLAUDE.md 中声明无需 Skill

### 问题 11
- **问题**：未找到任何 workspace 清理机制（workspace-init skill 或 README teardown 说明） 
- **修复**： 修复：添加 workspace-init skill 或在 README 中提供清理命令：rm -f .claude/workspace/phase-*.md

