# Simple Note Taker

将任意文本转换为结构化笔记的 Agent Team。

## Team 成员

| Agent | 职责 |
|-------|------|
| note-taker | 文本解析、结构提取、笔记生成 |

## 功能

- **文本解析**：理解任意文本的语义
- **结构提取**：识别标题、要点、总结
- **格式输出**：生成标准 Markdown 笔记

## 快速启动

```bash
# 复制到项目
cp -r simple-note-taker_teams_v2/.claude/ /your/project/.claude/
cp simple-note-taker_teams_v2/CLAUDE.md /your/project/
cp simple-note-taker_teams_v2/CONVENTIONS.md /your/project/
mkdir -p /your/project/.learnings
```

触发示例：
```
帮我整理笔记：今天开会讨论了项目进度，主要决定了三个事项...
```

## 文件树

```
simple-note-taker_teams_v2/
├── CLAUDE.md                    # Team 配置
├── CONVENTIONS.md               # 规范文件
├── README.md                    # 本文件
├── .claude/
│   ├── agents/
│   │   └── note-taker.md        # 核心 agent
│   └── skills/
│       └── self-improving-agent/# 自我改进 skill
└── .learnings/
    └── README.md                # 学习目录
```

## 协作流程

单 agent 串行执行：
```
用户输入 → note-taker 处理 → 输出笔记
```

## 输出示例

```markdown
# 项目会议纪要

## 要点

1. 下周三提交初版设计稿
2. 技术方案周五前完成评审
3. 下周团队增加两名新成员

## 总结

本次会议确定了项目关键时间节点和团队扩展计划。

---
*生成时间：2026-03-16*
*原文长度：68 字*
```

## 自我改进

本 team 启用自我改进功能。反馈保存在 `.learnings/feedback.md`。

提供反馈示例：
```
反馈：要点可以更简洁，总结控制在2句话以内
```

## 清理说明（Teardown）

如需移除本 team：

```bash
# 删除 agent 和 skill 配置
rm -rf /your/project/.claude/agents/note-taker.md
rm -rf /your/project/.claude/skills/self-improving-agent/

# 删除学习记录（可选保留）
rm -rf /your/project/.learnings/

# 删除配置文件
rm /your/project/CLAUDE.md
rm /your/project/CONVENTIONS.md
```

## 版本

- **v2**：当前版本
- 创建时间：2026-03-16
