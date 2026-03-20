# CONVENTIONS.md — Meta-Agents v8 全局规范索引

> 规范按职责拆分到 `.claude/rules/` 目录，每个文件独立加载。
> Toolsmith-Infra 在生成新 team 时通过 conventions-gen.sh 传递规范给目标 team。

## 规范文件

| 文件 | 内容 | 加载条件 |
|------|------|---------|
| `.claude/rules/core.md` | 命名、frontmatter、权限、代码、语言、版本、安全红线、Agent/Skill 设计规范 | 始终 |
| `.claude/rules/workspace.md` | workspace 协议、fork 变量、目录、并行等待、共享资源 | 始终 |
| `.claude/rules/execution.md` | 执行模型、fork 规则、错误处理模板 | 始终 |
| `.claude/rules/task-board.md` | Task Board、Context Compaction、Worktree 隔离 | 始终 |
| `.claude/rules/hooks.md` | Hook 生成规范、运行时 Profile 定义 | 始终 |
| `.claude/rules/skill-design.md` | Skill 创建流程、模板、测试评估、Description 优化 | toolsmith-skills 调用时 |
| `.claude/rules/instincts.md` | Instincts 数据结构、提炼/衰减规则 | self-improving + instincts 启用时 |

## @引用

在 `CLAUDE.md` 中通过 `@` 引用：

```markdown
@CONVENTIONS.md
@.claude/rules/core.md
@.claude/rules/workspace.md
@.claude/rules/execution.md
@.claude/rules/task-board.md
@.claude/rules/hooks.md
```

按需引用（生成的 team 根据配置决定是否包含）：
```markdown
@.claude/rules/skill-design.md
@.claude/rules/instincts.md
```
