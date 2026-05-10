# Critical Analysis — xiaohongshu v4 → v5

## 主要风险

按严重程度排序：

### 🔴 R1：node-canvas 在 Windows 上的安装是噩梦级别的
node-canvas 不是纯 JS 包，它绑定原生 Cairo + Pango + libjpeg + giflib + librsvg。Windows 用户首次 `npm install canvas` 极大概率失败：
- 需要 Visual Studio Build Tools（含 C++ 工作负载，>4GB）
- 需要 Python 2.7 或 3.x 在 PATH
- 需要 GTK 2 二进制包（官方文档让用户手动下载 `GTK2-Runtime` 解压到 C:\）
- node-gyp 报错信息几乎不可读
v4 用 Pillow 时 Python 用户 `pip install Pillow` 一行解决。**v5 把 90% 的安装难度从有 Python 环境的用户转嫁到没有 Cairo 工具链的用户。**

### 🔴 R2：image-processor 改成 Bash 调 Node 后，错误链路变长
v4 路径：image-processor → Bash → `python scripts/image_pipeline.py` → 直接出图
v5 路径：image-processor → Bash → Node 脚本 → `canvas-image-composer` skill → node-canvas → libcairo
**多了一层"skill 间接"**。当出图错误时，用户看到的栈是 JS 异常而不是 Pillow 的 Python traceback，调试 Cairo 的字体回退问题比调 Pillow 难一个数量级（Cairo 的字体子像素渲染失败往往静默输出方块字，没有报错）。

### 🟡 R3：image2 兜底链路过长且没有熔断
当前设计：素材匹配失败 → image2 生成新素材 → 写入 materials/ → Canvas 拼合。三个环节任一失败都导致最终无图。但 v4→v5 的变更里**没看到 image2 失败时的二次兜底**（比如纯文字 Canvas 卡片）。在 IMAGE2_API_KEY 未设置或网络挂掉时，用户得到的是一个空 output 目录。

### 🟡 R4：字体分发的合规与体积陷阱
思源黑体（Noto Sans SC）单个 .otf ~10MB，如果再加 Emoji（Noto Color Emoji ~24MB）、英文字体、衬线字体，`assets/fonts/` 轻松突破 60MB。git 仓库不适合存这种二进制；如果有 user 不小心把团队配置 push 到自己的 GitHub 公共仓，思源黑体 SIL OFL 没问题，但若日后有人换成方正/汉仪商用字体就是合规雷区。

### 🟡 R5：v4 已工作的 Pillow 路径直接砍掉，无 fallback
v4 的 image-processor 经过实战使用，至少素材直接复用、AI 编辑、Canvas 拼接三条路径都跑过。v5 把这些全部删除并指向尚未实现的 canvas-image-composer。**先写新模块再删旧模块**是正确做法，但 change-requests.md 明确说"删除 scripts/image_pipeline.py"——这等于让用户在 v5 没跑通时连降级回 v4 的本地能力都没了。

---

## 简化建议

**Canvas skill 是否真有必要？**——**有必要但当前设计偏重**。

当前 change-requests.md 把 skill 描述成"封装合成原语：图层叠加、文字描边、Emoji/中文字体、毛玻璃、圆角、分割布局"，**这是把整个 Photoshop 抽象成 skill**。实际小红书封面只需要 3 种布局：
1. 单图 + 顶部/底部标题条
2. 双图分屏 + 中间标题
3. 九宫格 + 角标

简化方案：
- 不做"封装合成原语"的通用 skill，而是 **3 个固定模板 Node 脚本**（`scripts/canvas/templates/single.js` / `split.js` / `grid.js`），每个 < 200 行
- skill 的职责退化为"根据 image-matcher-output.md 选模板 + 注入参数"，而不是抽象 Canvas API
- 不引入毛玻璃、圆角等高级特效（Cairo 的 blur 实现差且慢），用 PNG 预制贴图代替

---

## 跨平台陷阱

| 平台 | 安装命令 | 隐藏依赖 | 失败率（首次）|
|-----|---------|---------|-------------|
| **Windows** | `npm install canvas` | Visual Studio Build Tools + GTK2 Runtime + Python | 高（>60%）|
| **macOS** | `brew install pkg-config cairo pango libpng jpeg giflib librsvg` 然后 `npm install canvas` | Xcode Command Line Tools | 中（30%，主要是 Apple Silicon 下 brew 路径）|
| **Linux (Debian/Ubuntu)** | `apt install build-essential libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev` | 需 sudo | 低（<10%）|
| **Linux (Alpine/Docker)** | `apk add cairo-dev pango-dev jpeg-dev giflib-dev` | 缺 musl 兼容字体 | 中 |

**真正的坑**：node-canvas 主仓推荐了 `@napi-rs/canvas`（Rust 实现，纯预编译二进制，无原生依赖）。**强烈建议把"canvas"换成"@napi-rs/canvas"**——API 99% 兼容，安装零依赖，跨平台体验完全不同。change-requests.md 没考虑这个选项。

---

## 字体许可与分发

| 字体 | 许可 | 可分发 | 风险 |
|-----|------|-------|------|
| 思源黑体 (Noto Sans SC) | SIL OFL 1.1 | ✅ | 无 |
| Noto Color Emoji | SIL OFL 1.1 | ✅ | 体积 24MB |
| 微软雅黑 / 苹方 | 商用，禁分发 | 🔴 | 严重 |
| 方正/汉仪等 | 商用 | 🔴 | 严重 |

**风险点**：
1. 用户克隆 team 后自行替换 `assets/fonts/` 内容，若放入商用字体并提交，team 维护者需在 README 明确 disclaimer
2. v5 应在 `infra` 阶段写 `assets/fonts/LICENSE.md` 列出每个字体的来源和许可
3. 加一个 `pre-tool-safety.js` hook 检查 Write 到 `assets/fonts/` 时提示许可证审核

---

## 反对的假设

### 假设 1："Canvas 的字体生态丰富，与小红书前端审美对齐"
**反对**：小红书 App 前端用的是系统字体（iOS 苹方 / Android 思源），Canvas 在服务端渲染**永远拿不到苹方**（受版权限制）。所谓"审美对齐"是错觉——只是 Pillow 默认中文字体丑陋让人误以为换 Canvas 就好看。Pillow 用 `Source Han Sans` 也能渲染相同效果。**真正的差距在字体文件本身，而非渲染引擎。**

### 假设 2："image2 角色简化使决策树更清晰"
**反对**：v4 的 image2 既能生成又能编辑，灵活性高。v5 砍掉编辑能力意味着**用户提示"把这张照片调成黄昏色调"无法实现**——只能要么直接用素材，要么 image2 生成全新图。砍掉 edit endpoint 是产品功能回退，不是简化。

---

## 测试盲区

v4 Pillow 路径需要在 v5 重点验证的行为：

| 行为 | v4 (Pillow) | v5 (Canvas) 风险点 |
|-----|------------|-------------------|
| 中文标题超长自动换行 | `textwrap` + `getbbox` | Canvas 无内置换行，需手写 `measureText` 二分 |
| Emoji 渲染（🔥💯）| Pillow 默认不支持，需 `pilmoji` | node-canvas 需注册 Color Emoji 字体且同时注册中文字体，font fallback 顺序敏感 |
| 长文本描边（4-8px stroke）| `stroke_width` 参数 | Canvas 的 `strokeText` 在中文字下会出现笔画粘连，需 `lineJoin: "round"` |
| JPG 输出色彩 | Pillow `quality=95` | node-canvas `toBuffer('image/jpeg', { quality: 0.95 })` 颜色配置文件不同（sRGB vs Display P3）|
| 透明 PNG 合成顺序 | `Image.alpha_composite` | Canvas `globalCompositeOperation` 默认 `source-over`，alpha 计算精度差异 |
| 大图缩放（>4K → 1024）| Pillow `LANCZOS` | Canvas `imageSmoothingQuality='high'` 在 node-canvas 下实际是 bilinear，质量差 |

**至少要写 6 个回归测试用例，每个对应 v4 的真实出图场景。**

---

## 折中方案

如果用户不愿冒迁移风险，建议提供**双引擎并存的过渡方案**：

```
image-processor
  ├── 读 ENGINE 环境变量（"canvas" | "pillow"，默认 "canvas"）
  ├── ENGINE=canvas → 调 canvas-image-composer skill
  └── ENGINE=pillow → 调 v4 的 image_pipeline.py（保留）
```

具体落地：
1. **不删除 `scripts/image_pipeline.py`**，仅标记 deprecated
2. v5 的 `image-processor.md` 加一段："如 Canvas 安装失败，设置 `IMAGE_ENGINE=pillow` 临时回退"
3. 直到 v6 再彻底删除 Pillow 路径
4. 在 `output-validator` 加一项检查：如果 Canvas 跑通则建议下版本删 Pillow

**理由**：v4 的 Pillow 路径是已验证的安全网。当 node-canvas Windows 安装失败时（基于跨平台陷阱章节，概率 >50%），用户至少能把 ENGINE 切回 pillow 继续工作。这是 1 个文件的成本换 50% 用户的可用性。

---

## 总结一句话

**Canvas 替换 Pillow 在视觉上的收益（中文字体好看一点）远不及在分发维护上的成本（Windows 60% 安装失败 + Cairo 静默渲染缺陷 + 字体合规风险）。强烈建议：① 改用 @napi-rs/canvas 替代 node-canvas；② Pillow 路径保留为 fallback 至少一个版本；③ Canvas skill 简化为 3 个固定模板而非通用合成原语。**
