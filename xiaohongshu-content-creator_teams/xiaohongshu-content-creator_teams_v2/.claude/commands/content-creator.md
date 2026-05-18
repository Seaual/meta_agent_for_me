# /project:content-creator

启动小红书推文生成 Agent，根据用户提供的主题关键词和多轮对话上下文生成推文草稿及图片提示词。

## 对应 Agent

- **文件**：`.claude/agents/content-creator.md`
- **职责**：读取 skill，根据关键词+对话生成推文草稿 + 图片提示

## 使用方式

```
/project:content-creator
```

然后提供主题关键词，例如：
- 「帮我写一篇小红书风格的种草笔记，主题是防晒霜」
- 「用刚才分析的风格写」
- 「根据修改建议重新生成」

## 触发条件

- 用户提供了 1-3 个主题关键词，请求生成小红书风格推文
- 用户有多轮对话补充需求（如「要可爱一点」「面向大学生」）
- 用户想使用已合成的风格 skill 生成内容
- 审查反馈后需要重新生成

## 前置条件

- 无强制前置；如存在 `xiaohongshu-style-writer` skill 则优先使用，否则使用默认风格

## 输出

- `.claude/workspace/content-creator-output.md` — 推文草稿 + 图片提示词
- `.claude/workspace/content-creator-done.txt` — 完成标记

## 下游 Agent

生成完成后，由 `/project:keyword-guard` 和 `/project:xiaohongshu-policy-guard` 并行审查，通过后由 `/project:image-processor` 生成配图。
