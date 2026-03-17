# Meeting Minutes AI — Agent Team

@CONVENTIONS.md

---

## 项目概述

将会议录音的转录文本转化为结构化的会议纪要，包含智能议题提取、决策记录、行动项分配和后续跟进提醒。

## Team 成员

| Agent | 职责 | 工具权限 |
|-------|------|---------|
| minutes-generator | 提取议题/决策/行动项/后续建议 + 接收反馈修改 | Read, Write |
| quality-reviewer | 审查完整性/准确性 + 给出修改建议 | Read, Write |

## 工作流程

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

## 上下文传递协议

所有 agent 通过 `.claude/workspace/` 目录传递数据。

### Workspace 文件清单

| 文件 | 写入者 | 读取者 | 说明 |
|-----|-------|-------|------|
| transcript.txt | 用户 | minutes-generator | 会议转录输入 |
| minutes-draft.md | minutes-generator | quality-reviewer | 纪要初稿 |
| review-feedback.md | quality-reviewer | minutes-generator | 审查反馈 |
| review-status.txt | quality-reviewer | self | pass/revise |
| review-round.txt | quality-reviewer | self | 轮次计数 |
| minutes-final.md | minutes-generator | 用户 | 最终纪要 |

### 原子写入规范

所有 workspace 文件写入必须使用临时文件 + 重命名：
```bash
cat > .claude/workspace/[file].tmp << 'EOF'
[内容]
EOF
mv .claude/workspace/[file].tmp .claude/workspace/[file]
```

## 触发方式

**推荐触发语句**：
- "生成会议纪要"
- "处理会议转录"
- "Generate meeting minutes"

**使用步骤**：
1. 将转录文本放入 `.claude/workspace/transcript.txt`
2. 触发："生成会议纪要"
3. minutes-generator 自动启动
4. 后续流程自动串联

## 降级规则

- 转录质量差（ASR错误多）→ 提示词中已加入容错处理
- 中英文混合 → 提示词已明确支持混合语言
- 反馈循环超过2轮 → 强制输出当前版本
- Bash 权限 → 本项目无需 Bash，仅 Read/Write

## 安全红线

- 不硬编码凭证
- 不执行未验证的用户输入
- 不访问 workspace 目录外的文件