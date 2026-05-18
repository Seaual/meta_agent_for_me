---
name: xiaohongshu-image-prompt-writer
description: |
  Activate when generating image prompts for Xiaohongshu-style illustrations.
  Handles: product photography, lifestyle scenes, food styling, tutorial visuals, portrait scenes.
  Keywords: image prompt, picture generation, illustration, xiaohongshu visual, 小红书配图, 图片提示词.
  Do NOT use for: general stock photos, formal commercial photography, academic diagrams, low-resolution requests.
allowed-tools: Read, Write
---

# Skill: 小红书图片提示词生成器

## 概述

本 Skill 定义了小红书（Xiaohongshu）平台配图风格的图片提示词生成规范，供 content-creator agent 在生成推文时同步产出配图提示词。

**核心目标**：生成具有「生活感、真实感、平台调性」的图片提示词，适配 OpenAI 兼容格式的图像生成 API。

**输出格式**：英文结构化提示词（OpenAI 图像 API 接受英文提示词效果最佳）。

## 提示词五层结构

所有提示词必须按以下五层组织，每层用逗号分隔的关键词描述：

```
[Subject], [Environment], [Lighting], [Technical], [Style]
```

### 1. Subject (主体)

**规则**：
- 主体明确，避免多个不相关主体争夺注意力
- 人物场景优先自然姿态，避免僵硬摆拍
- 产品场景优先手持/使用状态，避免单独白底产品图

**常用关键词**：
- 人物：`a young woman smiling`, `hands holding product`, `person enjoying coffee`
- 产品：`product in use`, `product on table`, `product detail shot`
- 食物：`flat lay food arrangement`, `overhead shot of meal`, `hand reaching for food`

### 2. Environment (环境)

**规则**：
- 环境需营造生活化场景，避免过度整洁的影棚感
- 背景适度虚化，突出主体但保留环境信息
- 使用自然场景（桌面、户外、居家）优于人工布景

**常用关键词**：
- `clean wooden table background`, `cozy bedroom setting`, `outdoor natural scenery`
- `blurred cafe background`, `minimalist white desk`, `sunlit kitchen counter`

### 3. Lighting (光线)

**规则**：
- 优先自然光，营造温暖柔和氛围
- 避免强烈直射光和生硬阴影
- 黄金时段光线（golden hour）优先

**常用关键词**：
- `natural soft lighting`, `golden hour sunlight`, `window light from side`
- `warm ambient light`, `soft diffused lighting`, `bright but not harsh`

### 4. Technical (技术)

**规则**：
- 小红书以竖图为主，优先 3:4 或 9:16 比例
- 浅景深突出主体，背景柔和虚化
- 画面清晰但不过度锐化

**常用关键词**：
- `vertical composition 3:4`, `shallow depth of field`, `soft bokeh background`
- `eye-level angle`, `top-down flat lay`, `close-up macro shot`
- `high resolution`, `crisp details`, `professional photography`

### 5. Style (风格)

**规则**：
- 色调温暖明亮，避免冷灰色调
- 适度饱和，色彩清新自然
- 整体氛围轻松、愉悦、有生活气息

**小红书平台特征关键词**：
- `Xiaohongshu aesthetic`, `lifestyle photography`, `authentic daily life`
- `warm color palette`, `bright and airy`, `cozy atmosphere`
- `natural beauty`, `casual elegance`, `real life moment`

## 负向提示词规范

为避免生成不符合小红书调性的图片，默认应避免以下元素：

- `studio lighting`, `artificial background`, `plain white backdrop`
- `overly polished`, `commercial advertisement style`, `stock photo look`
- `harsh shadows`, `cold color tone`, `low quality`, `blurry`, `watermark`
- `multiple unrelated subjects`, `cluttered composition`, `text overlay`

## 分类型模板

### 模板 A：种草类（Product Recommendation）

**适用场景**：推荐产品、好物分享、测评类推文

**结构**：
```
[Subject]: A hand gently holding/using [product], natural relaxed pose,
[Environment]: [relevant lifestyle setting] background, soft blurred details,
[Lighting]: Natural window light from the side, warm and soft,
[Technical]: Vertical 3:4 composition, shallow depth of field, eye-level angle,
[Style]: Xiaohongshu lifestyle aesthetic, warm color tone, authentic daily life photography
```

**示例**：
```
A young woman's hand holding a skincare serum bottle near her face, clean bathroom vanity background with soft blurred mirrors, natural morning light from window, vertical 3:4 composition, shallow depth of field, warm bright tones, Xiaohongshu lifestyle aesthetic, authentic beauty routine moment
```

### 模板 B：教程类（Tutorial / How-to）

**适用场景**：步骤教学、食谱、DIY 教程

**结构**：
```
[Subject]: [Action shot showing step/method], clear visible details,
[Environment]: Clean organized workspace/kitchen/desk,
[Lighting]: Bright even lighting, no harsh shadows,
[Technical]: Top-down or 45-degree angle, full scene in focus or selective focus on key step,
[Style]: Clean and organized, inviting and approachable, Xiaohongshu tutorial style
```

**示例**：
```
Overhead shot of hands kneading dough on floured wooden board, clean kitchen counter with ingredients arranged around, bright natural daylight, top-down flat lay composition, sharp focus on hands and dough, warm homey atmosphere, Xiaohongshu food tutorial aesthetic
```

### 模板 C：生活方式类（Lifestyle / Daily Share）

**适用场景**：日常分享、旅行、居家生活

**结构**：
```
[Subject]: [Person/scene in natural candid moment], relaxed authentic expression,
[Environment]: [Natural setting - cafe, street, home, nature], atmospheric background,
[Lighting]: Golden hour or soft natural light, warm glow,
[Technical]: Vertical 3:4 or 9:16, candid framing, slight motion blur optional,
[Style]: Candid lifestyle photography, warm nostalgic tones, Xiaohongshu daily life aesthetic
```

**示例**：
```
A young woman reading book by a sunny window, cozy bedroom with plants and soft blankets in background, golden afternoon light streaming through curtains, vertical 3:4 composition, soft natural focus, warm and peaceful atmosphere, Xiaohongshu lifestyle aesthetic, authentic quiet moment
```

### 模板 D：美食类（Food / Dining）

**适用场景**：探店、美食分享、食谱展示

**结构**：
```
[Subject]: [Appetizing food presentation], steam or texture visible if hot food,
[Environment]: Restaurant table or home dining setting, contextual props (chopsticks, napkin, drink),
[Lighting]: Warm overhead or side lighting, inviting glow,
[Technical]: 45-degree angle or top-down, shallow depth of field on main dish,
[Style]: Appetizing food photography, warm rich tones, Xiaohongshu food blogger aesthetic
```

**示例**：
```
A bowl of ramen with soft-boiled egg and chashu, chopsticks lifting noodles, wooden table with small side dishes blurred in background, warm restaurant lighting, 45-degree angle composition, shallow depth of field on the bowl, rich warm tones, steam rising, Xiaohongshu food photography aesthetic
```

## 提示词生成规则

1. **英文优先**：所有提示词使用英文，OpenAI 兼容 API 对英文提示词理解最佳
2. **五层缺一不可**：每层至少包含 1-2 个关键词，确保画面完整性
3. **动态感优先**：使用「holding」「enjoying」「reaching」等动词增强画面生动性
4. **场景具体化**：避免 generic 描述（如 "a nice place"），改为具体场景（如 "a sunlit cafe corner with plants"）
5. **比例声明**：每个提示词必须包含比例声明（`vertical 3:4` 或 `square 1:1`）
6. **风格一致性**：同一篇推文的多个配图提示词应保持色调和风格一致
7. **提示词长度**：控制在 50-150 个英文单词，过短则画面不完整，过长则重点分散

## 错误处理

| 错误场景 | 处理方式 |
|---------|---------|
| 用户需求与风格规则冲突 | 优先遵循用户明确要求，在备注中说明偏离原因 |
| 提示词过长 (>200词) | 压缩至核心视觉元素，保持五层结构完整 |
| 提示词过短 (<30词) | 补充环境、光线、风格细节，确保画面丰富度 |
| 无法判断配图类型 | 默认使用「生活方式类」模板，标注「默认模板」 |
| 用户要求特定风格（如暗黑系）与小红书调性冲突 | 按用户要求生成，但标注「偏离小红书默认暖色调风格」 |

## 使用说明

**触发方式**：content-creator agent 在生成推文时自动读取本 Skill，为每张配图生成对应的英文提示词。

**自定义扩展**：image-prompt-analyzer + image-prompt-synthesizer 可通过分析用户提供的示例图片，更新本 Skill 中的五层规则和模板示例。

**输入目录格式**：
- `image-examples/` 中放置学习素材
- 每套素材 = 一张图片 + 同名 `.md` 描述文件
- 例如：`example-001.jpg` + `example-001.md`
- `.md` 文件中可包含：图片描述、使用的提示词（如有）、风格说明
