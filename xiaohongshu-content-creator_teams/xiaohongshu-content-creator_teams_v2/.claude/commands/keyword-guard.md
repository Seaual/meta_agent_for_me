# /project:keyword-guard

启动通用内容安全审查 Agent，扫描推文草稿中的政治、色情、暴力、仇恨、非法内容。

## 对应 Agent

- **文件**：`.claude/agents/keyword-guard.md`
- **职责**：通用敏感词审查（质量门禁）

## 使用方式

```
/project:keyword-guard
```

## 触发条件

- `content-creator` 已生成推文草稿，需要通用安全审查
- 用户说「请审查这篇推文是否有敏感内容」
- 用户想验证自己手动编写的内容是否安全
- 内容包含大量网络 slang，需要排查隐藏敏感含义

## 前置条件

- `.claude/workspace/content-creator-output.md` 存在

## 输出

- `.claude/workspace/keyword-guard-output.md` — 审查报告（含命中记录和修改建议）
- `.claude/workspace/keyword-guard-done.txt` — 完成标记

## 审查维度

| 维度 | 说明 |
|------|------|
| 政治敏感 | 政治人物、事件、敏感口号、分裂言论 |
| 色情低俗 | 露骨描述、性暗示、淫秽词汇 |
| 暴力恐怖 | 血腥描述、暴力煽动、恐怖组织相关 |
| 仇恨言论 | 种族/地域/性别歧视、煽动对立 |
| 非法内容 | 毒品、赌博、诈骗、违禁品交易 |

## 说明

审查结果为非阻断式建议模式：即使命中敏感词，也会提供具体修改建议，由用户决定是否采纳。
