# /project:image-prompt-synthesizer

启动图片提示词 skill 合成 Agent，将 `image-prompt-analyzer` 的视觉风格报告转化为可复用的 `xiaohongshu-image-prompt-writer` skill。

## 对应 Agent

- **文件**：`.claude/agents/image-prompt-synthesizer.md`
- **职责**：将视觉风格特征合成为 xiaohongshu-image-prompt-writer skill

## 使用方式

```
/project:image-prompt-synthesizer
```

## 触发条件

- `image-prompt-analyzer` 已完成视觉风格分析
- 用户说「把图片分析结果合成 skill」
- 用户想更新现有的图片提示词 skill
- 用户想直接创建一个默认的小红书图片提示词 skill

## 前置条件

- `.claude/workspace/image-prompt-analyzer-output.md` 存在（直接创建默认 skill 除外）

## 输出

- `.claude/skills/xiaohongshu-image-prompt-writer/SKILL.md` — 图片提示词 skill 文件
- `.claude/workspace/image-prompt-synthesizer-output.md` — 生成摘要
- `.claude/workspace/image-prompt-synthesizer-done.txt` — 完成标记

## 下游 Agent

Skill 合成后，由 `/project:content-creator` 读取并生成配图提示词。
