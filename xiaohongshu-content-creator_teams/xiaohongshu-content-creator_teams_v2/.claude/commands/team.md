# /project:team

查看小红书图文生成 Team 的所有可用 Agent 和 Skill。

## 使用方式

```
/project:team
```

## 触发条件

- 用户想了解本 Team 有哪些 Agent 和 Skill
- 用户不确定该用哪个命令启动
- 用户首次使用本 Team

## 可用 Agent

| Agent | 命令 | 职责 |
|-------|------|------|
| article-analyzer | `/project:article-analyzer` | 批量读取 articles/ 文章，提取文字风格特征 |
| style-synthesizer | `/project:style-synthesizer` | 将文字风格特征合成为 xiaohongshu-style-writer skill |
| image-prompt-analyzer | `/project:image-prompt-analyzer` | 批量读取 image-examples/ 示例图片+描述，提取视觉风格特征 |
| image-prompt-synthesizer | `/project:image-prompt-synthesizer` | 将视觉风格特征合成为 xiaohongshu-image-prompt-writer skill |
| content-creator | `/project:content-creator` | 读取双 skill，根据关键词+对话生成推文草稿 + 结构化图片提示词 |
| keyword-guard | `/project:keyword-guard` | 通用敏感词审查（质量门禁）|
| xiaohongshu-policy-guard | `/project:xiaohongshu-policy-guard` | 小红书平台合规审查（质量门禁）|
| image-processor | `/project:image-processor` | 调用 image2 API 合成/生成配图 |

## 可用 Skill

| Skill | 用途 |
|-------|------|
| `xiaohongshu-style-writer` | 小红书文字风格写作规范与模板库 |
| `xiaohongshu-image-prompt-writer` | 小红书图片提示词五层结构规范与模板库 |
| `self-improving-agent` | 通用自我改进系统 |
| `instinct-engine` | 持续学习系统，将经验提炼为可执行 instinct |

## 典型工作流

**路径 1：完整风格学习（文字+图片）**
1. 将参考文章放入 `articles/`
2. 将推文图片示例（+同名 `.md` 描述）放入 `image-examples/`
3. `/project:article-analyzer` + `/project:image-prompt-analyzer`（可独立触发）
4. `/project:style-synthesizer` + `/project:image-prompt-synthesizer`（可独立触发）
5. `/project:content-creator`（读取双 skill 生成推文+提示词）
6. `/project:keyword-guard` + `/project:xiaohongshu-policy-guard`
7. `/project:image-processor`

**路径 2：仅学习文字风格**
1. 将参考文章放入 `articles/`
2. `/project:article-analyzer`
3. `/project:style-synthesizer`
4. `/project:content-creator`
5. `/project:keyword-guard` + `/project:xiaohongshu-policy-guard`
6. `/project:image-processor`

**路径 3：仅学习图片风格**
1. 将推文图片示例放入 `image-examples/`
2. `/project:image-prompt-analyzer`
3. `/project:image-prompt-synthesizer`
4. `/project:content-creator`
5. `/project:keyword-guard` + `/project:xiaohongshu-policy-guard`
6. `/project:image-processor`

**路径 4：使用默认风格直接生成**
1. `/project:content-creator`（提供主题关键词）
2. `/project:keyword-guard` + `/project:xiaohongshu-policy-guard`
3. `/project:image-processor`
