## Sentinel 修复指令（第 3 轮）

以下问题需要修复后重新提交审查：

### 问题 1
- **问题**：workspace 文件冲突：workspace/draft-minutes.md 被多个 agent 写入（minutes-drafter, minutes-reviewer） 
- **修复**： 修复：为每个 agent 使用唯一的输出文件名

### 问题 2
- **问题**：[minutes-drafter.md] 执行框架步骤过少（0 步，建议 ≥2） 
- **修复**： 修复：补充具体执行步骤

### 问题 3
- **问题**：[minutes-reviewer.md] 执行框架步骤过少（0 步，建议 ≥2） 
- **修复**： 修复：补充具体执行步骤

