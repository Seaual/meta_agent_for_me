# /project:image-prompt-analyzer

启动图片提示词风格分析 Agent，批量读取 `image-examples/` 目录中的示例图片及其描述文件，提取可复用的视觉风格特征。

## 对应 Agent

- **文件**：`.claude/agents/image-prompt-analyzer.md`
- **职责**：批量读取 image-examples/ 示例图片+描述，提取视觉风格特征（五层结构：主体、环境、光线、技术、风格）

## 使用方式

```
/project:image-prompt-analyzer
```

## 触发条件

- 用户已将推文图片示例放入 `image-examples/` 目录，需要分析视觉风格
- 用户说「帮我分析一下这些图片的风格」
- 用户想根据参考图片生成图片提示词 skill
- 用户在 `image-examples/` 目录中新增了示例，需要重新分析

## 前置条件

- `image-examples/` 目录存在且包含图片文件
- **推荐格式**：每套示例 = 一张图片 + 同名 `.md` 描述文件
  - 例如：`example-001.jpg` + `example-001.md`
  - `.md` 文件中可包含：图片描述、使用的提示词（如有）、风格说明

## 输出

- `.claude/workspace/image-prompt-analyzer-output.md` — 视觉风格特征报告
- `.claude/workspace/image-prompt-analyzer-done.txt` — 完成标记

## 下游 Agent

分析完成后，通常由 `/project:image-prompt-synthesizer` 将报告合成为图片提示词 skill。
