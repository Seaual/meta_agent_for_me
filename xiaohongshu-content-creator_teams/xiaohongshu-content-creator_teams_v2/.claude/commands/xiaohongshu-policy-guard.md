# /project:xiaohongshu-policy-guard

启动小红书平台合规审查 Agent，对推文草稿进行广告法、虚假宣传、行业限制、格式规范四维审查。

## 对应 Agent

- **文件**：`.claude/agents/xiaohongshu-policy-guard.md`
- **职责**：小红书平台合规审查（质量门禁）

## 使用方式

```
/project:xiaohongshu-policy-guard
```

## 触发条件

- `content-creator` 已生成推文草稿，需要平台合规审查
- 用户说「检查一下是否符合小红书平台规则」
- 推文使用了「最」「第一」「顶级」等绝对化用语
- 内容涉及医疗、美妆、金融等受限行业

## 前置条件

- `.claude/workspace/content-creator-output.md` 存在

## 输出

- `.claude/workspace/xiaohongshu-policy-guard-output.md` — 四维审查报告
- `.claude/workspace/xiaohongshu-policy-guard-done.txt` — 完成标记

## 审查维度

| 维度 | 说明 |
|------|------|
| 广告法审查 | 绝对化用语、虚假承诺、未标明广告性质 |
| 虚假宣传审查 | 夸大功效、伪造数据、对比贬损、虚假用户体验 |
| 行业限制审查 | 医疗/药品/保健品、金融投资、美妆特殊用途、教育培训 |
| 格式规范审查 | 标签数量、段落长度、emoji 适度性、互动引导合规 |

## 说明

审查结果为非阻断式建议模式：提供「违规依据 + 合规替代文案」，由用户决定是否采纳。
