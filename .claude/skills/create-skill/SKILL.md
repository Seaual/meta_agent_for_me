---
name: create-skill
description: |
  Create new skills, modify and improve existing skills, and measure skill performance.
  Use when users want to create a skill from scratch, edit, or optimize an existing skill,
  run evals to test a skill, benchmark skill performance with variance analysis,
  or optimize a skill's description for better triggering accuracy.

  Also handles adapting agency-agents agent's Process/Deliverables sections into skill format.
  Use after find-skill confirms no suitable skill exists.
  Triggers on: "create skill", "新建skill", "创建技能", "make a skill for",
  "写一个skill来做X", "build skill", "skill不存在需要新建", "从零创建skill",
  "improve skill", "优化skill", "test skill", "eval skill".
  Do NOT use if a suitable skill already exists (run find-skill first to check).
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Create Skill — 技能锻造炉

A skill for creating new skills and iteratively improving them.

At a high level, the process of creating a skill goes like this:

- Decide what you want the skill to do and roughly how it should do it
- Write a draft of the skill
- Create a few test prompts and run claude-with-access-to-the-skill on them
- Help the user evaluate the results both qualitatively and quantitatively
  - While the runs happen in the background, draft some quantitative evals if there aren't any (if there are some, you can either use as is or modify if you feel something needs to change about them). Then explain them to the user (or if they already existed, explain the ones that already exist)
  - Use the `eval-viewer/generate_review.py` script to show the user the results for them to look at, and also let them look at the quantitative metrics
- Rewrite the skill based on feedback from the user's evaluation of the results (and also if there are any glaring flaws that become apparent from the quantitative benchmarks)
- Repeat until you're satisfied
- Expand the test set and try again at larger scale

Your job when using this skill is to figure out where the user is in this process and then jump in and help them progress through these stages. So for instance, maybe they're like "I want to make a skill for X". You can help narrow down what they mean, write a draft, write the test cases, figure out how they want to evaluate, run all the prompts, and repeat.

On the other hand, maybe they already have a draft of the skill. In this case you can go straight to the eval/iterate part of the loop.

Of course, you should always be flexible and if the user is like "I don't need to run a bunch of evaluations, just vibe with me", you can do that instead.

Then after the skill is done (but again, the order is flexible), you can also run the skill description improver, which we have a whole separate script for, to optimize the triggering of the skill.

---

## 创建路径选择

```
用户描述需求
       │
       ├── agency-agents 库中有类似 agent？
       │         │
       │      是 ─┤─── 否
       │         │         │
       │         ▼         ▼
       │     改编路径    原创路径
       │   (提取执行逻辑) (从零构建)
       │
       └── 需要调用外部工具/MCP？
                 │
              是 ─┤─── 否
                 │         │
                 ▼         ▼
           MCP-aware    标准 skill
             skill
```

---

## 路径 A：改编 Agency-Agents Agent

agency-agents 的 agent 是**有人格的专家**，不能直接当 skill 用。
但它们的「执行流程」部分非常高质量，值得提取。

### Step 1：识别可提取的内容

```bash
AGENCY_PATH="${AGENCY_AGENTS_PATH:-./agency-agents}"
AGENT_FILE="$AGENCY_PATH/[division]/[agent-name].md"

echo "=== 分析原 Agent ==="
cat "$AGENT_FILE"
```

**提取映射表**：

| Agency-Agent 中的部分 | 提取到 Skill 中 | 操作 |
|---------------------|---------------|------|
| `## Core Mission` / `## Mission` | `## 概述` | 提取核心功能描述（去掉人格语气） |
| `## My Process` / `## Workflow` | `## 执行步骤` | 直接映射，是 skill 的核心 ✅ |
| `## Technical Deliverables` / `## Deliverables` | `## 输出格式` | 转化为格式规范 |
| `## Success Metrics` | `## 完成标准` | 转化为可验证的检查清单 |
| `## Critical Rules` | 嵌入各步骤的约束条件 | 分散到相关步骤中 |
| `## Identity` / `## Personality` | **丢弃** | Skill 不需要人格 |
| `## Communication Style` | **丢弃** | Skill 不需要语气描述 |
| `## Memory` / `## Background` | **丢弃** | Skill 不保存状态 |

### Step 2：生成改编后的 SKILL.md

在 frontmatter 中注明来源：
```yaml
---
name: [skill-name]
description: |
  [从 agent Mission 改编的触发描述]
  Keywords: [从 agent 名称和功能提取].
  Do NOT use for: [明确排除].
  # Adapted from: agency-agents/[division]/[original-agent].md
allowed-tools: [根据 agent 实际操作确定]
---
```

---

## 路径 B：从零原创 Skill

### Step 1：四问定位

```
Q1: 这个 skill 做什么？（一句话）
    格式：[动词] + [对象] + [目的/约束]
    例：「扫描 Python 代码中的安全漏洞，生成带行号的报告」

Q2: 触发条件是什么？
    - 用户说什么话时应该触发？
    - 哪些场景不该触发（排除项）？

Q3: 需要哪些工具权限？（最小原则）
    只读：Read, Grep, Glob
    读写：+ Write 或 Edit（优先 Edit）
    执行命令：+ Bash（需要明确理由）

Q4: 输出是什么格式？
    Markdown 报告 / 生成的代码文件 / JSON 结构 / 终端输出
```

### Step 2：判断是否需要 MCP

如果 skill 需要调用**外部服务**，先确认 MCP 可用性：

```bash
# 检查 Claude Code 的 MCP 配置
echo "=== 已配置的 MCP ==="
cat ~/.claude/settings.json 2>/dev/null \
  | grep -A5 '"mcpServers"' \
  | grep '"name"\|"command"' \
  || echo "（未找到 MCP 配置，或路径不同）"
```

**常见 MCP 需求映射**：

| Skill 需要做的事 | 需要的 MCP | 配置示例 |
|---------------|----------|---------|
| 操作 GitHub Issues/PR | `@anthropic-ai/mcp-server-github` | `"github"` |
| 网络搜索 | `@anthropic-ai/mcp-server-brave-search` | `"brave-search"` |
| 抓取网页内容 | `@anthropic-ai/mcp-server-fetch` | `"fetch"` |
| 操作 SQLite 数据库 | `@anthropic-ai/mcp-server-sqlite` | `"sqlite"` |
| 读写本地文件系统 | `@anthropic-ai/mcp-server-filesystem` | `"filesystem"` |
| 运行 Python 代码 | 无需 MCP（用 Bash） | — |
| 发送 Slack 消息 | `@modelcontextprotocol/server-slack` | `"slack"` |

如果需要 MCP 但尚未配置，在输出中告知用户配置方式。

### Step 3：步骤设计原则

将任务分解为 **3-7 个步骤**，遵循：

```
步骤名：动词短语（不超过 5 个词）
步骤内容：
  - 明确的操作说明
  - 分支处理：「如果 [条件A]，则 [操作A]；否则 [操作B]」
  - 工具使用：给出具体命令示例（而非「用 Bash 执行」这种废话）
步骤输出：这步完成后产出什么
```

### Step 4：生成完整 SKILL.md

**完整模板**：

```markdown
---
name: [kebab-case-name]
description: |
  Activate when [触发动词短语].
  Handles: [场景A], [场景B].
  Keywords: [en-kw-1], [en-kw-2], [中文词1], [中文词2].
  Do NOT use for: [排除场景] (use [替代方案] instead).
allowed-tools: [最小权限]
---

# Skill: [人类可读标题]

## 概述
[1-2句话：做什么，解决什么问题]

## 前置检查
\`\`\`bash
# 验证必要工具/环境/MCP
[具体检查命令]
\`\`\`

## 执行步骤

### Step 1：[动词短语]
[说明]
\`\`\`bash
[具体命令示例]
\`\`\`

### Step 2：[动词短语]
[说明，含分支处理]

[...继续直到覆盖所有步骤]

## 输出格式
\`\`\`
[输出结构样例]
\`\`\`

## 完成标准
- [ ] [可验证的标准 1]
- [ ] [可验证的标准 2]

## 错误处理
| 错误 | 原因 | 处理方式 |
|-----|------|---------|
| [错误1] | [原因] | [如何处理] |

## 使用示例
用户输入：「[典型触发语句]」
Skill 行为：[简述执行过程]
输出样例：[预期输出片段]
```

---

## 创建后自检

```bash
SKILL_FILE=".claude/skills/$SKILL_NAME/SKILL.md"

echo "=== Create-Skill 自检 ==="
grep -q "^name:"          "$SKILL_FILE" && echo "✅ name"          || echo "🔴 缺少 name"
grep -q "^description:"   "$SKILL_FILE" && echo "✅ description"   || echo "🔴 缺少 description"
grep -q "^allowed-tools:" "$SKILL_FILE" && echo "✅ allowed-tools" || echo "🔴 缺少 allowed-tools"

# 使用示例
grep -q "使用示例\|Example" "$SKILL_FILE" \
  && echo "✅ 有使用示例" || echo "🟡 建议添加使用示例"

echo "Skill 路径：$SKILL_FILE"
echo "=== 自检完成 ==="
```

---

## 测试与评估

此部分用于验证 skill 质量并迭代改进。

### 运行测试用例

Put results in `<skill-name>-workspace/` as a sibling to the skill directory. Within the workspace, organize results by iteration (`iteration-1/`, `iteration-2/`, etc.) and within that, each test case gets a directory (`eval-0/`, `eval-1/`, etc.).

### Step 1：Spawn all runs (with-skill AND baseline) in the same turn

For each test case, spawn two subagents in the same turn — one with the skill, one without. This is important: don't spawn the with-skill runs first and then come back for baselines later. Launch everything at once so it all finishes around the same time.

**With-skill run:**

```
Execute this task:
- Skill path: <path-to-skill>
- Task: <eval prompt>
- Input files: <eval files if any, or "none">
- Save outputs to: <workspace>/iteration-<N>/eval-<ID>/with_skill/outputs/
- Outputs to save: <what the user cares about — e.g., "the .docx file", "the final CSV">
```

**Baseline run** (same prompt, but the baseline depends on context):
- **Creating a new skill**: no skill at all. Same prompt, no skill path, save to `without_skill/outputs/`.
- **Improving an existing skill**: the old version. Before editing, snapshot the skill (`cp -r <skill-path> <workspace>/skill-snapshot/`), then point the baseline subagent at the snapshot. Save to `old_skill/outputs/`.

### Step 2：While runs are in progress, draft assertions

Don't just wait for the runs to finish — you can use this time productively. Draft quantitative assertions for each test case and explain them to the user.

Good assertions are objectively verifiable and have descriptive names — they should read clearly in the benchmark viewer.

### Step 3：Grade, aggregate, and launch the viewer

Once all runs are done:

1. **Grade each run** — spawn a grader subagent (or grade inline) that reads `agents/grader.md` and evaluates each assertion against the outputs.

2. **Aggregate into benchmark** — run the aggregation script:
   ```bash
   python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name <name>
   ```

3. **Launch the viewer**:
   ```bash
   python eval-viewer/generate_review.py \
     <workspace>/iteration-N \
     --skill-name "my-skill" \
     --benchmark <workspace>/iteration-N/benchmark.json
   ```

   **Headless environments:** Use `--static <output_path>` to write a standalone HTML file.

### Step 4：Read the feedback

When the user tells you they're done, read `feedback.json`:

```json
{
  "reviews": [
    {"run_id": "eval-0-with_skill", "feedback": "the chart is missing axis labels", "timestamp": "..."},
    {"run_id": "eval-1-with_skill", "feedback": "", "timestamp": "..."}
  ],
  "status": "complete"
}
```

Empty feedback means the user thought it was fine. Focus your improvements on the test cases where the user had specific complaints.

---

## 迭代改进

This is the heart of the loop. You've run the test cases, the user has reviewed the results, and now you need to make the skill better based on their feedback.

### How to think about improvements

1. **Generalize from the feedback.** Don't put in fiddly overfitty changes. Try branching out and using different metaphors.

2. **Keep the prompt lean.** Remove things that aren't pulling their weight.

3. **Explain the why.** Try hard to explain the **why** behind everything you're asking the model to do.

4. **Look for repeated work across test cases.** If all test cases resulted in similar helper scripts, that's a strong signal the skill should bundle that script.

### The iteration loop

After improving the skill:

1. Apply your improvements to the skill
2. Rerun all test cases into a new `iteration-<N+1>/` directory
3. Launch the reviewer with `--previous-workspace`
4. Wait for the user to review
5. Read the new feedback, improve again, repeat

Keep going until:
- The user says they're happy
- The feedback is all empty (everything looks good)
- You're not making meaningful progress

---

## Description 优化

The description field in SKILL.md frontmatter is the primary mechanism that determines whether Claude invokes a skill.

### Step 1：Generate trigger eval queries

Create 20 eval queries — a mix of should-trigger and should-not-trigger:

```json
[
  {"query": "the user prompt", "should_trigger": true},
  {"query": "another prompt", "should_trigger": false}
]
```

### Step 2：Review with user

Present the eval set to the user for review using `assets/eval_review.html`.

### Step 3：Run the optimization loop

```bash
python -m scripts.run_loop \
  --eval-set <path-to-trigger-eval.json> \
  --skill-path <path-to-skill> \
  --model <model-id> \
  --max-iterations 5 \
  --verbose
```

### Step 4：Apply the result

Take `best_description` from the JSON output and update the skill's SKILL.md frontmatter.

---

## 打包

Check whether you have access to the `present_files` tool. If you do, package the skill:

```bash
python -m scripts.package_skill <path/to/skill-folder>
```

After packaging, direct the user to the resulting `.skill` file path.

---

## 参考文件

The `agents/` directory contains instructions for specialized subagents:
- `agents/grader.md` — How to evaluate assertions against outputs
- `agents/comparator.md` — How to do blind A/B comparison between two outputs
- `agents/analyzer.md` — How to analyze why one version beat another

The `references/` directory has additional documentation:
- `references/schemas.md` — JSON structures for evals.json, grading.json, etc.

---

## 核心循环总结

- Figure out what the skill is about
- Draft or edit the skill
- Run claude-with-access-to-the-skill on test prompts
- With the user, evaluate the outputs:
  - Create benchmark.json and run `eval-viewer/generate_review.py`
  - Run quantitative evals
- Repeat until you and the user are satisfied
- Package the final skill and return it to the user