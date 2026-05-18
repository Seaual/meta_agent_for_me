# /project:style-synthesizer

启动风格 skill 合成 Agent，将 `article-analyzer` 的风格报告转化为可复用的 `xiaohongshu-style-writer` skill。

## 对应 Agent

- **文件**：`.claude/agents/style-synthesizer.md`
- **职责**：将风格特征合成为 xiaohongshu-style-writer skill

## 使用方式

```
/project:style-synthesizer
```

## 触发条件

- `article-analyzer` 已完成风格分析
- 用户说「把分析结果合成 skill」
- 用户想更新现有的风格 skill
- 用户想直接创建一个默认的小红书风格 skill

## 前置条件

- `.claude/workspace/article-analyzer-output.md` 存在（直接创建默认 skill 除外）

## 输出

- `.claude/skills/xiaohongshu-style-writer/SKILL.md` — 风格 skill 文件
- `.claude/workspace/style-synthesizer-output.md` — 生成摘要
- `.claude/workspace/style-synthesizer-done.txt` — 完成标记

## 下游 Agent

Skill 合成后，由 `/project:content-creator` 读取并生成推文。
