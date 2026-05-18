# /project:image-processor

启动图片生成/合成 Agent，调用 image2 HTTP API 为已通过审查的推文生成配图。

## 对应 Agent

- **文件**：`.claude/agents/image-processor.md`
- **职责**：调用 image2 HTTP API 合成/生成配图

## 使用方式

```
/project:image-processor
```

## 触发条件

- `keyword-guard` 和 `xiaohongshu-policy-guard` 均已完成审查
- 用户说「为这篇推文生成图片」
- 用户在 `input/` 目录中放置了素材图片，需要合成
- image2 服务临时不可用，需要降级输出

## 前置条件

- `.claude/workspace/content-creator-output.md` 存在
- 建议先完成 `/project:keyword-guard` 和 `/project:xiaohongshu-policy-guard` 审查

## 环境变量

| 变量 | 说明 |
|------|------|
| `IMAGE2_API_KEY` | image2 API 密钥 |
| `IMAGE2_BASE_URL` | image2 API 基础地址 |

## 输出

- `output/images/xhs-img-*.png` — 生成的配图文件
- `.claude/workspace/image-processor-output.md` — 处理报告
- `.claude/workspace/image-processor-done.txt` — 完成标记

## 处理模式

| 模式 | 触发条件 |
|------|---------|
| 生成模式 | `input/` 目录无素材，纯 AI 生成 |
| 合成模式 | `input/` 目录有素材，基于素材 + AI 增强 |
| 混合模式 | 部分素材可用，部分纯生成 |

## 降级处理

- API 密钥缺失 / API 不可用 → 输出纯文本推文 + 图片提示词，告知用户手动配图
- 素材损坏 → 跳过该素材，使用纯生成模式
- 输出目录无写权限 → 尝试写入 `./meta-agents-output/images/`
