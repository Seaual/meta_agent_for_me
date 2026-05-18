# /project:article-analyzer

启动文章风格分析 Agent，批量读取 `articles/` 目录中的参考文章，提取可量化的风格特征。

## 对应 Agent

- **文件**：`.claude/agents/article-analyzer.md`
- **职责**：批量读取 articles/ 文章，提取风格特征

## 使用方式

```
/project:article-analyzer
```

## 触发条件

- 用户已将参考文章放入 `articles/` 目录，需要分析风格
- 用户说「帮我分析一下这些文章的风格」
- 用户想根据参考文章生成风格 skill
- 用户在 `articles/` 目录中新增了文章，需要重新分析

## 前置条件

- `articles/` 目录存在且包含 `.md` 或 `.txt` 文件

## 输出

- `.claude/workspace/article-analyzer-output.md` — 风格特征报告
- `.claude/workspace/article-analyzer-done.txt` — 完成标记

## 下游 Agent

分析完成后，通常由 `/project:style-synthesizer` 将报告合成为 skill。
