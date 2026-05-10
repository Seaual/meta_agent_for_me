# Strategic Analysis — xiaohongshu v4 → v5

## 价值主张

**核心价值**：将图像合成从「Python 后端拼接逻辑」升级为「前端工艺级排版引擎」，让生成图片在视觉上真正具备小红书 KOL 笔记的排版质感。

| 维度 | v4（Pillow） | v5（Canvas） | 用户实际收益 |
|------|------------|-------------|------------|
| 字体生态 | Pillow + 系统字体（PIL.ImageFont 单字重）| node-canvas + .ttf/.otf 任意注册（思源黑体多字重 + Emoji + 装饰字）| 封面文字「能上得了台面」，不再是 Times New Roman 默认味 |
| 跨平台 | Win/Mac/Linux 字体路径不一致，频繁报错 | assets/fonts/ 自带，与 Team 一起分发 | 用户拿到 Team 即用，不需在本地折腾字体 |
| 工艺细节 | 文字描边/毛玻璃/圆角靠手写 numpy | Canvas 原生 API（`shadowBlur`/`globalCompositeOperation`/`roundRect`）| 封面工艺感 ↑↑，更接近爆款笔记视觉 |
| 与 Web 审美对齐 | Pillow 渲染感偏「桌面感」 | Canvas/CSS 风格一致，与小红书前端同源 | 视觉气质天然贴合平台 |
| 依赖治理 | Python venv + Pillow + 字体配置 | 单一 npm install canvas | 安装路径变短，Node 生态本就在用户机器上 |

**量化判断**：v5 是「视觉质量」而非「功能数量」的升级。Agent 数量、流程拓扑、目录结构均不变，**风险面收敛在 image-processor 一个 agent + 一个新 skill**。

---

## 边界定义

### v5 范围内
- `image-processor` 内部实现切换（删 Python 脚本，改调 Canvas skill）
- 新增 `canvas-image-composer` skill（图层、文字、字体、布局、导出）
- `assets/fonts/` 字体资产目录 + `scripts/canvas/templates/` 布局模板
- image2 API 角色简化为「素材兜底生成」单一职责
- `package.json` 新增 canvas 依赖 + 字体注册逻辑
- CONVENTIONS.md 中 image-processor 的 Bash 使用场景描述更新（从 Python 改为 Node）

### v5 不在范围内（守住边界）
- 不动 articles/ / image-examples/ / output/ 目录结构（用户已建立的内容资产保留）
- 不动其他 9 个 agent 的职责与 prompt
- 不动审查链（keyword-guard / xiaohongshu-policy-guard）
- 不动 self-improving + instincts 学习机制
- 不引入新的 AI 服务（仍只有 chatanywhere image2）
- 不做交互式编辑器（Canvas 只用作合成引擎，不做 UI）

### 明确不解决的问题（写给用户）
- **不解决「素材完全没有」的内容创意问题**（image2 兜底生成已是上限）
- **不解决「字体版权」问题**（用户需自行确认所选 .ttf 商用授权）
- **不解决「真人封面合成」**（Canvas 不做 AI 换脸/抠图，仍走 image2）

---

## 扩展路线

| 版本 | 可能演进 | 依赖条件 |
|------|---------|---------|
| **v6** | 模板市场化：`scripts/canvas/templates/` 升级为可枚举的命名模板（如「教程九宫格」「测评对比卡」「金句封面」），content-creator 在生成时即指定模板 ID | v5 模板抽象稳定，且 ≥3 个模板沉淀 |
| **v6** | 字体智能匹配：根据文章主题（治愈系/职场/美食）自动选择字体组合 | 需 image-prompt-analyzer 输出主题标签 |
| **v7** | SVG 中间产物：先渲染 SVG，再转 PNG，便于后期人工微调 | 用户有「半自动化」的诉求 |
| **v7** | 多平台输出：Canvas skill 抽离平台尺寸预设（小红书 / 微信公众号 / 抖音封面 / B站头图）| canvas-image-composer 已被验证在多个 team 复用 |
| **v8** | 视频封面（Canvas + ffmpeg 序列帧）| 用户开始做视频内容 |

**演进哲学**：v5 是引擎切换的「基础设施投资」，v6+ 才是收割红利的「产品力扩展」。强烈建议本次升级**克制功能扩张**，把 Canvas 切换做扎实。

---

## 复用价值

### canvas-image-composer skill 独立性评估

| 维度 | 评估 | 理由 |
|------|------|------|
| 命名独立性 | ✅ 强 | 名称不含 xiaohongshu，纯通用合成原语 |
| 依赖独立性 | ✅ 强 | 仅依赖 npm `canvas`，不依赖本 team 任何 agent |
| 配置可移植 | ⚠️ 中 | 字体目录 `assets/fonts/` 依赖宿主项目结构，需在 SKILL.md 中允许配置注入 |
| 业务耦合 | ✅ 低 | 不内嵌小红书审美规则；审美决定权在调用方 prompt 中 |
| 输出通用 | ✅ 强 | 输出 PNG/JPG，任何下游可消费 |

**推荐做法**：
1. canvas-image-composer 设计为「**布局+合成原语层**」，不内嵌平台审美
2. 小红书专属审美（圆角程度、阴影色温、典型字号）放在 `scripts/canvas/templates/xiaohongshu/` 模板，与 skill 解耦
3. 在 SKILL.md description 中**避开 xiaohongshu 关键词**，允许其他 team（公众号封面、知乎卡片）触发

**复用场景预测**：
- ✅ 微信公众号封面 team（同样需要中文字体合成）
- ✅ B站视频缩略图 team
- ✅ 通用「营销卡片生成」team
- ⚠️ 不适合：纯像素艺术 / 复杂图像处理（应继续用 Pillow/OpenCV）

---

## 推荐拓扑

**结论：维持 10 agent，无需调整。**

### 判断依据

| 评估项 | 是否需要新 agent | 理由 |
|-------|--------------|------|
| Canvas 合成逻辑封装 | ❌ | 应封装为 skill，不增加 agent |
| 字体管理 | ❌ | 字体注册是 skill 内部步骤，不构成独立职责 |
| 模板选择决策 | ❌ | 由 image-processor 在调用 skill 时按 image-matcher 输出选择 |
| image2 兜底生成 | ❌ | 仍由 image-processor 内部判断，决策树简化反而减负 |

**v4 的 10 agent 拓扑在 v5 中**：
- 9 个 agent 完全不变（包括 prompt 文案）
- 1 个 agent（image-processor）替换实现：删除 Pillow 路径，改调 canvas-image-composer skill；image2 调用从「双路径（generate + edit）」收敛为「单路径（generate 兜底素材）」
- image-processor 的 `allowed-tools` 仍为 `Read, Write, Bash`（Bash 用途从 `python` 改为 `node`）

**架构上的简化收益**：image-processor 的 Processing Mode 从 v4 的 4 种（直接复用 / Canvas 拼接 / API 编辑 / API 生成）收敛为 v5 的 3 种（**素材复用 / image2 兜底新素材 / canvas-image-composer 合成**），决策树更清晰，错误率更低。

---

## 关键洞察

### 洞察 1：这是一次「实现替换」而非「能力升级」，应当严格控制范围
v5 的本质是**把图像合成的「工艺底盘」从 Python 换到 Node**。容易诱发的失误是借机「顺便加点功能」（多模板、多平台输出、批处理）。建议本次升级严守**只换底盘**的纪律，把扩展全部留给 v6。Sentinel 审查时应特别警惕「范围蔓延」。

### 洞察 2：canvas-image-composer 的「业务无关性」是战略级投资
该 skill 设计得越通用，未来 team 的复用红利越大。**强烈建议在 SKILL.md 设计阶段就做「去小红书化」**：审美参数全部走调用方传入，模板放外部目录，skill 本身只暴露 `compose({layers, fonts, layout, export})` 这种通用 API。一个写得好的 canvas-image-composer 可能比这个 team 本身活得更久。

### 洞察 3：image2 的角色澄清是隐藏的架构胜利
v4 中 image2 既做「生成」又做「编辑」，与 Pillow 形成两条并行路径，决策成本高、错误率大。v5 把 image2 收敛为「素材兜底生成器」，把所有「文字+排版」交给 Canvas，**这是一次干净的关注点分离**：image2 负责「画面」，Canvas 负责「版式」。这条边界一旦立住，未来无论是替换 image2 为其他 AI 服务（DALL-E、即梦、Flux）还是升级 Canvas 模板，都不会互相牵动。**这个简化的战略价值，可能高于 Canvas 本身。**
