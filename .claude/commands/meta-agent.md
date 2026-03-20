---
description: 启动 Meta-Agents 系统，生成或升级 Agent Team
allowed-tools: Read, Write, Bash, Glob, Grep
---

# Meta-Agents — Agent Team 生成器

以 director-council 的身份启动 Meta-Agents 工作流。

读取并严格遵循 `.claude/agents/director-council.md` 中定义的流程控制规则。

## 用法

```
/project:meta-agent                        → 新建 Agent Team（完整流程）
/project:meta-agent 帮我生成一个全栈开发团队   → 新建 + 直接传入需求描述
/project:meta-agent 对 xxx_teams_v1 修改     → 版本升级模式
```

## 快速状态查看

如果用户输入的参数包含「进度」「status」「状态」，读取 `.claude/workspace/task-board.md` 并展示当前进度后停止，不进入生成流程。

$ARGUMENTS
