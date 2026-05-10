# Council 收敛 — xiaohongshu v4 → v5

## 三方共识（直接采纳）

1. **拓扑保持 10 agent 不变**：唯一变化点收敛在 `image-processor` 内部 + 新增 1 个 skill
2. **image2 API 角色澄清**：仅用于生成 output 素材图（写入 `image-examples/materials/`）
3. **新增 canvas-image-composer skill**：封装 Canvas 合成原语
4. **保留 self-improving + instincts** 学习机制
5. **字体方案**：思源黑体（Source Han Sans SC，OFL 1.1，可分发）+ Noto Color Emoji
6. **不变的 9 个 agent**：article-analyzer、style-synthesizer、image-prompt-analyzer、image-prompt-synthesizer、image-recognizer、content-creator、keyword-guard、xiaohongshu-policy-guard、image-matcher

## 三方分歧 + 裁决

### 分歧 1：技术选型 — node-canvas vs @napi-rs/canvas

| 立场 | 主张 | 理由 |
|-----|------|------|
| Critical | `@napi-rs/canvas` | Windows 60%+ 安装失败率；Rust 预编译，零原生依赖 |
| Technical | `canvas` 2.x | 事实标准，预编译 prebuild 已多数覆盖 |
| Strategic | 不表态 | 关注点在战略价值 |

**裁决**（规则 4：Critical 简化方案满足核心价值）：
- **主选 `@napi-rs/canvas`**（npm: `@napi-rs/canvas`）
- API 与原生 Canvas 99% 兼容，迁移成本低
- 跨平台零编译依赖，大幅降低用户门槛
- 性能优于 node-canvas（Rust 实现）
- 字体注册 API 一致（`GlobalFonts.registerFromPath()`）

### 分歧 2：是否保留 Pillow 作为 fallback

| 立场 | 主张 |
|-----|------|
| Critical | 强烈建议保留，env 切换 |
| Strategic | 只换底盘，不留旧路径 |
| Technical | 删除 Pillow 路径 |

**裁决**（规则 4：考虑用户机器现实）：
- **删除 Pillow 路径**（与用户原意一致：「将 pillow 替换为了 canvas」）
- 不引入双引擎复杂性
- 但在 `image-processor.md` 错误处理段加入「如 Canvas 安装失败，参考 README 故障排除」的指引
- README 提供 `@napi-rs/canvas` 安装故障排除 + 备用方案（用户可手动运行 v4 的 Pillow 脚本应急）

### 分歧 3：Canvas Skill 复杂度

| 立场 | 主张 |
|-----|------|
| Critical | 3 个固定模板脚本（< 200 行/个）|
| Technical | 8 原语 + 7 模板 |
| Strategic | 通用化设计，业务参数外置 |

**裁决**（融合 Strategic + Critical）：
- **6 个核心原语**：`loadImage`、`registerFont`、`drawLayer`、`drawText`、`drawShape`、`exportImage`
  - 删除 `applyFilter`（Cairo blur 质量差，Critical 建议有理）
  - 删除 `applyTemplate`（提升为模板独立调用，更清晰）
- **5 个标准模板**（精简自 Technical 的 7 个）：
  1. `cover-text-only.js`（封面纯文字）
  2. `cover-image-text.js`（上图下字封面）
  3. `left-image-right-text.js`（左图右文）
  4. `grid-3x3.js`（九宫格）
  5. `quote-card.js`（引言卡片）
  - 删除 `top-image-bottom-text`（与 cover-image-text 重复）
  - 删除 `comparison-2col`（与 left-image-right-text 重复）
- **去小红书化**（Strategic 建议）：skill 不内嵌 xiaohongshu 关键词，模板放在 team 内 `scripts/canvas/templates/`，skill 提供原语层

### 分歧 4：滤镜与特效

| 立场 | 主张 |
|-----|------|
| Critical | 不要 Cairo blur，用 PNG 预制贴图 |
| Technical | 保留 applyFilter |

**裁决**：
- **删除 applyFilter 原语**
- 滤镜需求改为 PNG 预制叠加（暗角贴图、颗粒纹理放在 `assets/overlays/`）
- 简单的 vignette 通过 `drawShape` + 渐变实现

## v5 最终架构

### Agent 矩阵（10 个，仅 1 个变更）

| Agent | 状态 | v5 说明 |
|-------|------|---------|
| article-analyzer | 不变 | — |
| style-synthesizer | 不变 | — |
| image-prompt-analyzer | 不变 | — |
| image-prompt-synthesizer | 不变 | — |
| image-recognizer | 不变 | — |
| content-creator | 不变 | — |
| keyword-guard | 不变 | — |
| xiaohongshu-policy-guard | 不变 | — |
| image-matcher | 不变 | — |
| **image-processor** | **重写** | 删除 Pillow 路径；调 `node scripts/canvas/compose.js`；image2 仅生成素材兜底 |

### Skill 矩阵（5 个，新增 1 个）

| Skill | 状态 | 说明 |
|-------|------|------|
| xiaohongshu-style-writer | 不变 | v3 复用 |
| xiaohongshu-image-prompt-writer | 不变 | v3 复用 |
| self-improving-agent | 不变 | 学习机制 |
| instinct-engine | 不变 | 模式提炼 |
| **canvas-image-composer** | **v5 新增** | 6 原语 + 业务无关合成层 |

### 数据流（v5 简化版）

```
articles/{folder}/   ──→ article-analyzer ──→ style-synthesizer ──→ style skill
                    └─→ image-prompt-analyzer ──→ image-prompt-synthesizer ──→ prompt skill

image-examples/materials/ ──→ image-recognizer ──→ index.json

用户关键词 ──→ content-creator
                  │
                  ├─→ keyword-guard ∥ xiaohongshu-policy-guard
                  │
                  └─→ image-matcher ←── index.json
                          │
                          ▼
              ┌─────────────────────────────────┐
              │ image-processor (v5)            │
              │   1. 读匹配结果                   │
              │   2. 缺素材？→ image2 API 生成   │  ★ image2 角色：素材兜底
              │      └─→ 写入 materials/        │
              │   3. 构造 canvas config.json    │
              │   4. node scripts/canvas/        │
              │       compose.js config.json    │  ★ canvas-image-composer
              │      ↓                          │
              │   output/{name}/images/*.jpg    │
              └─────────────────────────────────┘
```

### 关键技术决策

| 决策 | 选定 | 理由 |
|------|------|------|
| Canvas 实现 | `@napi-rs/canvas` | 跨平台零依赖，Windows 友好 |
| 字体 | 思源黑体 SC + Noto Color Emoji | OFL 许可，可分发，覆盖中文+Emoji |
| 模板数量 | 5 个 | 覆盖小红书核心排版，避免过度设计 |
| 原语数量 | 6 个 | 精简自 Technical 8 个，去除模糊滤镜 |
| Pillow 路径 | 完全删除 | 遵循用户「替换」语义 |
| image2 endpoint | 仅 generations | 砍掉 edits（用户明确） |

## 关键风险与兜底

| 风险 | 兜底方案 |
|-----|---------|
| `@napi-rs/canvas` 安装失败 | README 提供故障排除（rebuild、不同 Node 版本）；image-processor 输出 error 报告 |
| 字体文件缺失 | font-registry 启动时校验，缺失则 fallback 到系统字体 + warning |
| image2 API 配额耗尽 | 标注「无素材」并跳过该图，不阻塞其他图 |
| compose.js 进程崩溃 | image-processor 重试 2 次，失败记录到部分失败列表 |
| 中文换行/Emoji 渲染异常 | drawText 提供 `maxWidth` + `lineHeight` 参数，模板内做 measureText 二分换行 |

## 推荐拓扑

**协作模式**：与 v4 完全一致（混合：素材索引支线 + 主流程串/并行）
**MCP 集成**：无（保持 v4 现状）
**复杂度**：中等（10 agent，明确链路）
**升级强度**：实现层局部替换（最小切口）

## 关键洞察传承

- **范围控制**（Strategic 洞察 1）：本次升级严守「只换底盘」，所有扩展留给 v6
- **战略级投资**（Strategic 洞察 2）：canvas-image-composer skill 设计为业务无关层
- **关注点分离**（Strategic 洞察 3）：image2 = 画面，Canvas = 版式（架构胜利）
- **可用性兜底**（Critical 提醒）：Windows 用户优先，故障排除文档前置
- **测试回归**（Critical 提醒）：6 个 v4 已工作场景必须在 v5 验证（中文换行/Emoji/描边/JPG 色彩/alpha 合成/缩放质量）

## 收敛规则应用记录

- 规则 1（三方共识）：拓扑/职责/skill/字体/角色澄清 — 直接采纳
- 规则 4（Critical 简化方案）：技术选型 `@napi-rs/canvas`、删除 applyFilter、模板精简 — 采用
- 用户原意优先：删除 Pillow 路径、删除 image2 edit endpoint — 不拒绝用户明确指令

## 下一步

进入 visionary-arch，基于本收敛文件设计具体架构方案（agent 提示词修改 + skill 文件结构 + 数据流细节）。
