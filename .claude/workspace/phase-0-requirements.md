# Phase 0 — 版本升级需求摘要（v4 → v5）

## 升级基础（v4 现状）

**Team 名称**：xiaohongshu-content-creator
**版本路径**：v3（基础版）→ v4（素材索引+识图）→ v5（Canvas 合成引擎）
**Agent 数量**：v4 共 10 个 agent（保持不变）
**Skill 数量**：v4 共 4 个 skill（v5 新增 canvas-image-composer，共 5 个）

### v4 团队结构（保持的部分）

```
工作组 A（文字提炼）：article-analyzer → style-synthesizer
工作组 B（图片提炼）：image-prompt-analyzer → image-prompt-synthesizer
素材索引组：image-recognizer
生成组：content-creator → keyword-guard ∥ xiaohongshu-policy-guard → image-matcher → image-processor
```

## v5 核心变更需求

### 用户原文
> 改进 v4，现在将 pillow 替换为 canvas，生成图片带字体的，可能需要一个 canvas 的 skill，让他生成图片，最后，image2 作为生成 output 素材图的就行。

### 三个明确变更点
1. **替换图像合成引擎**：Pillow（Python）→ Canvas（Node.js node-canvas）
2. **新增 Canvas Skill**：封装合成原语，特别支持字体渲染
3. **image2 角色简化**：仅用于生成 output 素材图（替代 image-examples/materials/ 缺失时的兜底）

## 运行时配置（继承 v4）

- **profile**：standard（与 v4 一致，保持稳定）
- **self-improving**：yes（保留学习能力）
- **instincts**：yes（保留两层学习结构）

## 不在本次范围

- 不改变 articles/ 目录结构
- 不改变 image-examples/ 分区结构
- 不改变 output/ 输出结构
- 不改变其他 9 个 agent 的核心职责（仅 image-processor 内部实现切换）
- 不新增 agent（保持 10 个 agent）

## 关键约束

1. v5 必须能在 Windows / macOS / Linux 三平台运行（node-canvas 跨平台）
2. 字体文件必须可与 Team 一起分发（assets/fonts/ 目录）
3. image-processor 的对外接口（输入/输出）保持 v4 兼容
4. canvas-image-composer skill 必须可被其他 team 复用（独立性）
