# 执行模型与错误处理

## Claude Code 执行模型

**关键认知：agent 的 .md 文件是指令文档，不是可执行脚本。**

1. `.md` 中的 bash 代码块是**示意性的**，Claude 会理解意图但不会自动逐行执行
2. 依赖管理通过**自然语言指令**实现，不是 bash 轮询
3. 并行通过 `context: fork` 声明实现，不是 bash 后台进程
4. 流程控制通过 agent 的多轮对话实现，不是 `exit 1`

### 禁止的模式

```bash
# 🔴 bash 轮询等待文件
while [ ! -f ".claude/workspace/done.txt" ]; do sleep 1; done

# 🔴 exit 作为流程控制
[ ! -f "input.md" ] && exit 1

# 🔴 bash 后台进程模拟并行
agent_a &
agent_b &
wait
```

### 正确的模式

```markdown
# ✅ 自然语言依赖检查
检查 `.claude/workspace/analysis-output.md` 是否存在。
如果不存在，告知用户需要先运行 transcript-analyzer，然后停止。

# ✅ 自然语言完成标记
完成后，将结果写入 `.claude/workspace/minutes.md`。

# ✅ frontmatter 声明并行
---
context: fork
---
```

### 生成的 agent 文件中允许的 bash 用法

仅限于 agent **实际需要执行的命令**（如运行测试、调用审计工具），不用于流程编排：

```bash
# ✅ 允许
pip-audit -r requirements.txt --format json
npm audit --json
pytest --cov=. --cov-report=json

# 🔴 禁止
for f in agent-done.txt skill-done.txt; do
  wait_for_file "$f"
done
```

## `context: fork` 使用规则

### 适合 fork 的场景

```
✅ 各自独立工作，输出不同文件的 agent
✅ 只读相同输入，不写入相同文件
✅ 使用 Worktree 隔离的并行 agent
```

### 不适合 fork 的场景

```
🔴 需要实时读写同一文件的多个 agent
🔴 需要 agent 之间实时通信的场景
```

### fork agent 设计校验清单

1. 该 agent 是否写入了被**其他 fork agent** 读取的文件？→ 🔴 冲突
2. 多个 fork agent 是否写入同一文件？→ 🔴 冲突
3. 如果有共享文件需求 → 改用串行 + 协调者模式
4. 如果必须并行写入重叠路径 → 使用 Worktree 隔离

## 错误处理模板

每个生成的 agent 必须包含以下错误处理逻辑：

### 输入缺失处理

```markdown
检查 `.claude/workspace/[input-file]` 是否存在。
如果不存在：
- 将错误信息写入 `.claude/workspace/[agent-name]-error.txt`
- 告知用户需要先运行 [上游 agent]
- 停止执行，不写入完成标记
```

### 部分失败处理

```markdown
如果处理过程中某个步骤失败：
- 记录失败原因到输出文件顶部（⚠️ 部分完成：[原因]）
- 继续处理其他可用数据
- 写入完成标记（不阻塞下游）
```

### 网络降级（仅限有网络权限的 agent）

```markdown
如果网络请求失败：
- 使用本地缓存或默认值
- 在输出中标注「[数据源] 不可用，使用本地描述」
- 仍然写入完成标记
```
