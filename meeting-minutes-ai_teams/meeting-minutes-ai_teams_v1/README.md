# Meeting Minutes AI Agent Team

> 将会议录音的转录文本转化为结构化的会议纪要，包含智能议题提取、决策记录、行动项分配和后续跟进提醒。

---

## 架构概览

```
用户输入 transcript.txt
        │
        ▼
┌─────────────────────┐
│   minutes-generator  │ ──→ minutes-draft.md
└─────────────────────┘
        │
        ▼
┌─────────────────────┐      revise      ┌──────────────┐
│   quality-reviewer   │ ────────────────→│ 反馈修改      │
└─────────────────────┘                  │ (回到generator)│
        │                                └──────────────┘
        │ pass / 最多2轮
        ▼
┌─────────────────────┐
│   minutes-final.md   │
└─────────────────────┘
```

**拓扑类型**：反馈循环（固定流程）

**设计决策**：2 个 agent 足够完成所有需求。minutes-generator 负责提取 + 生成 + 接收反馈修改，quality-reviewer 负责审查 + 反馈。反馈循环通过 workspace 文件传递实现。

---

## Team 成员

| Agent | 职责 | 工具权限 | 来源 |
|-------|------|---------|------|
| `minutes-generator` | 提取议题/决策/行动项/后续建议 + 接收反馈修改 | Read, Write | 原创 |
| `quality-reviewer` | 审查完整性/准确性 + 给出修改建议 | Read, Write | 原创 |

### 各 Agent 详细说明

#### minutes-generator
- **使命**：将会议转录文本转化为结构清晰、信息完整的会议纪要
- **输入**：`.claude/workspace/transcript.txt`（转录文本）
- **输出**：`.claude/workspace/minutes-draft.md`（初稿）/ `minutes-final.md`（终稿）
- **触发关键词**：meeting minutes, transcript, action items, 会议纪要, 议题提取

#### quality-reviewer
- **使命**：确保会议纪要的完整性、准确性和格式规范性
- **输入**：`.claude/workspace/minutes-draft.md` + `transcript.txt`
- **输出**：`.claude/workspace/review-status.txt` + `review-feedback.md`
- **触发关键词**：review, quality check, 审查, 质量检查, 纪要审查

---

## 文件树

```
meeting-minutes-ai_teams_v1/
├── README.md
├── CLAUDE.md
├── CONVENTIONS.md
└── .claude/
    ├── agents/
    │   ├── minutes-generator.md
    │   └── quality-reviewer.md
    ├── skills/
    │   └── (无)
    ├── workspace/
    │   └── README.md
    └── scripts/
        ├── conventions-gen.sh
        ├── improvements-gen.sh
        ├── self-improving-setup.sh
        └── version-manager.sh
```

---

## 协作流程

```
Step 1: "生成会议纪要"
         │
         ▼
minutes-generator — 读取转录文本 → workspace/minutes-draft.md
         │
         ▼
quality-reviewer — 审查纪要 → workspace/review-status.txt
         │
    ┌────┴────┐
    │         │
  [pass]   [revise]
    │         │
    ▼         ▼
minutes-final.md  review-feedback.md
                      │
                      ▼
                (round < 2 ?)
                 /      \
              [yes]    [no]
               │         │
               ▼         ▼
        minutes-generator  强制输出 final
```

### 上下文传递

| 文件 | 写入者 | 读取者 | 内容 |
|-----|-------|-------|------|
| `transcript.txt` | 用户 | minutes-generator | 会议转录文本 |
| `minutes-draft.md` | minutes-generator | quality-reviewer | 纪要初稿 |
| `review-feedback.md` | quality-reviewer | minutes-generator | 审查反馈 |
| `review-status.txt` | quality-reviewer | minutes-generator | pass/revise |
| `review-round.txt` | quality-reviewer | quality-reviewer | 轮次计数 |
| `minutes-final.md` | minutes-generator | 用户 | 最终纪要 |

### 反馈循环

- 最多 2 轮审查
- 每轮：minutes-generator 生成 → quality-reviewer 审查 → 反馈修改
- 第 2 轮仍不通过时强制输出当前版本

---

## 可用 Skills

此团队无需独立 Skill，所有能力由 agent Prompt 提供。

---

## MCP 配置

此团队只操作本地文件，无需 MCP 配置。

---

## 快速启动

```bash
# 1. 复制到你的项目
cp -r meeting-minutes-ai_teams/meeting-minutes-ai_teams_v1/.claude/ /your/project/.claude/

# 2. 进入项目目录
cd /your/project

# 3. 将转录文本放入 workspace
cat > .claude/workspace/transcript.txt << 'EOF'
[粘贴你的会议转录文本]
EOF

# 4. 启动 Claude Code
claude
```

触发语句：
- `「生成会议纪要」`
- `「处理会议转录」`
- `「Generate meeting minutes」`

---

## 注意事项

- `.claude/workspace/` 建议加入 `.gitignore`
- 支持中英文混合转录文本
- 转录质量差时（ASR 错误多）agent 会尝试根据上下文推断
- 行动项截止日期未提及时标注"待定"
- 置信度说明：高=明确表述，中=上下文推断，低=推测

---

## 清理与卸载

### 清理运行时数据（每次新构建前）

```bash
# 清理 workspace 临时文件，保留版本信息
rm -f .claude/workspace/phase-*.md
rm -f .claude/workspace/council-*.md
rm -f .claude/workspace/sentinel-*.txt
rm -f .claude/workspace/sentinel-*.md
rm -f .claude/workspace/*-done.txt
rm -f .claude/workspace/*-count.txt
rm -f .claude/workspace/review-*.txt
rm -f .claude/workspace/review-*.md
rm -f .claude/workspace/minutes-*.md
echo "workspace 已清理"
```

### 完全清除此 Team

```bash
# 删除整个 team 目录（不可恢复）
rm -rf meeting-minutes-ai_teams/
```

---

*由 Meta-Agents 自动生成 · 2026-03-16*