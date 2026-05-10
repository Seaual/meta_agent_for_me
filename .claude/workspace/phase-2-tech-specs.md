# Visionary-Tech 规格 — xiaohongshu-content-creator v5

**基于**：phase-1-architecture.md / council-convergence.md / phase-2-ux-specs.md
**负责范围**：代码 + 配置 + CLAUDE.md/CONVENTIONS.md + Hook + 工具权限白名单

---

## Section 1：package.json

```json
{
  "name": "xiaohongshu-content-creator-v5",
  "version": "5.0.0",
  "private": true,
  "description": "Xiaohongshu image composition pipeline based on @napi-rs/canvas (v5)",
  "engines": { "node": ">=18.0.0" },
  "dependencies": {
    "@napi-rs/canvas": "^0.1.50"
  },
  "scripts": {
    "compose": "node scripts/canvas/compose.js",
    "setup-fonts": "node scripts/setup-fonts.js",
    "setup-overlays": "node scripts/setup-overlays.js",
    "postinstall": "node scripts/setup-fonts.js && node scripts/setup-overlays.js"
  }
}
```

`postinstall` 让 `npm install` 自动下载字体并生成 overlay；首次失败可单独 `npm run setup-fonts` 重试。

---

## Section 2：字体方案

### 2.1 `assets/fonts/LICENSE.md`

```markdown
# 字体许可声明

本目录字体均使用 **SIL Open Font License Version 1.1 (OFL 1.1)**。
OFL 1.1 允许：免费使用、修改、商业分发；不允许将字体本身单独售卖。

## 字体清单

| 文件 | 字体名 | 来源 | 许可 |
|-----|-------|------|------|
| SourceHanSansSC-Regular.otf | 思源黑体 SC Regular | Adobe & Google | OFL 1.1 |
| SourceHanSansSC-Bold.otf | 思源黑体 SC Bold | Adobe & Google | OFL 1.1 |
| SourceHanSerifSC-Regular.otf | 思源宋体 SC Regular | Adobe & Google | OFL 1.1 |
| NotoColorEmoji.ttf | Noto Color Emoji | Google | OFL 1.1 |

## 下载源

- 思源黑体/宋体: https://github.com/adobe-fonts/source-han-sans / source-han-serif
- Noto Color Emoji: https://github.com/googlefonts/noto-emoji

## OFL 1.1 完整文本

参见 https://scripts.sil.org/OFL ，本目录附 OFL.txt 完整副本。
```

### 2.2 `scripts/setup-fonts.js`

```javascript
#!/usr/bin/env node
// 下载思源黑体/宋体 + Noto Color Emoji 到 assets/fonts/
const https = require('https');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const FONTS_DIR = path.resolve(__dirname, '..', 'assets', 'fonts');

// 字体清单：name -> {url, sha256(可选，留空跳过校验)}
const FONTS = {
  'SourceHanSansSC-Regular.otf': {
    url: 'https://github.com/adobe-fonts/source-han-sans/raw/release/OTF/SimplifiedChinese/SourceHanSansSC-Regular.otf',
    sha256: ''
  },
  'SourceHanSansSC-Bold.otf': {
    url: 'https://github.com/adobe-fonts/source-han-sans/raw/release/OTF/SimplifiedChinese/SourceHanSansSC-Bold.otf',
    sha256: ''
  },
  'SourceHanSerifSC-Regular.otf': {
    url: 'https://github.com/adobe-fonts/source-han-serif/raw/release/OTF/SimplifiedChinese/SourceHanSerifSC-Regular.otf',
    sha256: ''
  },
  'NotoColorEmoji.ttf': {
    url: 'https://github.com/googlefonts/noto-emoji/raw/main/fonts/NotoColorEmoji.ttf',
    sha256: ''
  }
};

function ensureDir(dir) { fs.mkdirSync(dir, { recursive: true }); }

function download(url, dest, redirects = 5) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    https.get(url, { headers: { 'User-Agent': 'xhs-v5-setup' } }, (res) => {
      if ([301, 302, 303, 307, 308].includes(res.statusCode)) {
        file.close(); fs.unlinkSync(dest);
        if (redirects <= 0) return reject(new Error('too many redirects'));
        return resolve(download(res.headers.location, dest, redirects - 1));
      }
      if (res.statusCode !== 200) {
        file.close(); fs.unlinkSync(dest);
        return reject(new Error(`HTTP ${res.statusCode} for ${url}`));
      }
      res.pipe(file);
      file.on('finish', () => file.close(resolve));
    }).on('error', (err) => { try { fs.unlinkSync(dest); } catch {} reject(err); });
  });
}

function sha256File(filepath) {
  const hash = crypto.createHash('sha256');
  hash.update(fs.readFileSync(filepath));
  return hash.digest('hex');
}

(async () => {
  ensureDir(FONTS_DIR);
  let okCount = 0, skipCount = 0, failCount = 0;
  for (const [name, meta] of Object.entries(FONTS)) {
    const dest = path.join(FONTS_DIR, name);
    if (fs.existsSync(dest) && fs.statSync(dest).size > 0) {
      console.log(`[skip] ${name} 已存在`);
      skipCount++; continue;
    }
    try {
      console.log(`[fetch] ${name} <- ${meta.url}`);
      await download(meta.url, dest);
      if (meta.sha256) {
        const got = sha256File(dest);
        if (got !== meta.sha256) {
          console.error(`[fail] ${name} sha256 不匹配`);
          fs.unlinkSync(dest); failCount++; continue;
        }
      }
      console.log(`[ok] ${name} (${fs.statSync(dest).size} bytes)`);
      okCount++;
    } catch (e) {
      console.error(`[fail] ${name}: ${e.message}`);
      failCount++;
    }
  }
  console.log(`\n字体下载完成：成功 ${okCount}，已存在 ${skipCount}，失败 ${failCount}`);
  if (failCount > 0) {
    console.error('部分字体下载失败，请手动放入 assets/fonts/ 或重试 npm run setup-fonts');
    process.exit(1);
  }
})();
```

---

## Section 3：`scripts/canvas/font-registry.js`

```javascript
// 字体批量注册：扫描 assets/fonts/ 注册到 GlobalFonts，缺失收集为 warnings
const path = require('path');
const fs = require('fs');
const { GlobalFonts } = require('@napi-rs/canvas');

// 默认字体 alias 约定：文件名（去后缀）→ alias
const DEFAULT_ALIASES = {
  'SourceHanSansSC-Regular': 'SHS-Regular',
  'SourceHanSansSC-Bold': 'SHS-Bold',
  'SourceHanSerifSC-Regular': 'SHSerif',
  'NotoColorEmoji': 'Emoji'
};

/**
 * 注册字体集合
 * @param {string} fontsDir 字体目录绝对路径
 * @param {Array<{path:string,alias:string}>} explicitFonts 来自 config.fonts 的显式声明
 * @returns {{loaded: string[], warnings: string[]}}
 */
function registerAllFonts(fontsDir, explicitFonts = []) {
  const loaded = [];
  const warnings = [];

  // 优先注册显式声明的字体
  for (const f of explicitFonts) {
    const abs = path.isAbsolute(f.path) ? f.path : path.resolve(process.cwd(), f.path);
    if (!fs.existsSync(abs)) {
      warnings.push(`font_missing: ${f.alias} at ${f.path}`);
      continue;
    }
    try {
      GlobalFonts.registerFromPath(abs, f.alias);
      loaded.push(f.alias);
    } catch (e) {
      warnings.push(`font_register_failed: ${f.alias} (${e.message})`);
    }
  }

  // 兜底扫描 fontsDir 内所有未注册的字体
  if (fs.existsSync(fontsDir)) {
    for (const file of fs.readdirSync(fontsDir)) {
      if (!/\.(otf|ttf|ttc)$/i.test(file)) continue;
      const base = file.replace(/\.[^.]+$/, '');
      const alias = DEFAULT_ALIASES[base] || base;
      if (loaded.includes(alias)) continue;
      const abs = path.join(fontsDir, file);
      try {
        GlobalFonts.registerFromPath(abs, alias);
        loaded.push(alias);
      } catch (e) {
        warnings.push(`font_register_failed: ${alias} (${e.message})`);
      }
    }
  } else {
    warnings.push(`fonts_dir_missing: ${fontsDir}`);
  }

  return { loaded, warnings };
}

module.exports = { registerAllFonts, DEFAULT_ALIASES };
```

---

## Section 4：`scripts/canvas/primitives.js`

```javascript
// 6 原语实现：loadImage / registerFont / drawLayer / drawText / drawShape / exportImage
const fs = require('fs');
const path = require('path');
const {
  loadImage: napiLoadImage,
  GlobalFonts,
  createCanvas
} = require('@napi-rs/canvas');

/* ---------- 1. loadImage ---------- */
async function loadImage(imgPath) {
  const abs = path.isAbsolute(imgPath) ? imgPath : path.resolve(process.cwd(), imgPath);
  if (!fs.existsSync(abs)) {
    const err = new Error(`image_load_failed: ${imgPath}`);
    err.code = 'image_load_failed';
    throw err;
  }
  return napiLoadImage(abs);
}

/* ---------- 2. registerFont ---------- */
function registerFont(fontPath, alias) {
  const abs = path.isAbsolute(fontPath) ? fontPath : path.resolve(process.cwd(), fontPath);
  if (!fs.existsSync(abs)) throw new Error(`font_missing: ${alias} at ${fontPath}`);
  GlobalFonts.registerFromPath(abs, alias);
}

/* ---------- 3. drawLayer ---------- */
function drawLayer(ctx, image, opts = {}) {
  const { x = 0, y = 0, w, h, opacity = 1, blendMode = 'source-over' } = opts;
  ctx.save();
  ctx.globalAlpha = Math.max(0, Math.min(1, opacity));
  ctx.globalCompositeOperation = blendMode;
  const dw = w || image.width;
  const dh = h || image.height;
  ctx.drawImage(image, x, y, dw, dh);
  ctx.restore();
}

/* ---------- 4. drawText（中文换行 measureText 二分 + 描边 + Emoji fallback） ---------- */
function _wrapChinese(ctx, text, maxWidth) {
  const lines = [];
  let buf = '';
  for (const ch of Array.from(text)) {
    if (ch === '\n') { lines.push(buf); buf = ''; continue; }
    const test = buf + ch;
    if (ctx.measureText(test).width > maxWidth && buf.length > 0) {
      lines.push(buf); buf = ch;
    } else {
      buf = test;
    }
  }
  if (buf) lines.push(buf);
  return lines;
}

function drawText(ctx, text, opts = {}) {
  const {
    x = 0, y = 0,
    font = 'sans-serif', size = 32, color = '#000',
    maxWidth = 1024, lineHeight = 1.3,
    stroke = null, align = 'left',
    emojiFont = 'Emoji'
  } = opts;

  ctx.save();
  // 字体串：含 Emoji fallback
  ctx.font = `${size}px "${font}", "${emojiFont}", sans-serif`;
  ctx.fillStyle = color;
  ctx.textAlign = align;
  ctx.textBaseline = 'top';

  const lines = _wrapChinese(ctx, String(text), maxWidth);
  const lh = Math.round(size * lineHeight);
  let drawX = x;
  if (align === 'center') drawX = x + maxWidth / 2;
  else if (align === 'right') drawX = x + maxWidth;

  let cursorY = y;
  for (const line of lines) {
    if (stroke && stroke.width > 0) {
      ctx.lineWidth = stroke.width;
      ctx.strokeStyle = stroke.color || '#fff';
      ctx.strokeText(line, drawX, cursorY);
    }
    ctx.fillText(line, drawX, cursorY);
    cursorY += lh;
  }
  ctx.restore();

  return { x, y, w: maxWidth, h: cursorY - y };
}

/* ---------- 5. drawShape ---------- */
function drawShape(ctx, type, opts = {}) {
  const { x = 0, y = 0, w = 0, h = 0, radius = 0, fill = '#000', gradient = null } = opts;
  ctx.save();

  let style = fill;
  if (gradient) {
    const isVertical = (gradient.direction || 'vertical') === 'vertical';
    const grad = isVertical
      ? ctx.createLinearGradient(x, y, x, y + h)
      : ctx.createLinearGradient(x, y, x + w, y);
    grad.addColorStop(0, gradient.from);
    grad.addColorStop(1, gradient.to);
    style = grad;
  }
  ctx.fillStyle = style;

  switch (type) {
    case 'rect':
      ctx.fillRect(x, y, w, h);
      break;
    case 'roundRect':
    case 'roundedRect': {
      const r = Math.min(radius, w / 2, h / 2);
      ctx.beginPath();
      ctx.moveTo(x + r, y);
      ctx.lineTo(x + w - r, y);
      ctx.quadraticCurveTo(x + w, y, x + w, y + r);
      ctx.lineTo(x + w, y + h - r);
      ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
      ctx.lineTo(x + r, y + h);
      ctx.quadraticCurveTo(x, y + h, x, y + h - r);
      ctx.lineTo(x, y + r);
      ctx.quadraticCurveTo(x, y, x + r, y);
      ctx.closePath();
      ctx.fill();
      break;
    }
    case 'circle': {
      const cx = x + w / 2, cy = y + h / 2;
      const r2 = Math.min(w, h) / 2;
      ctx.beginPath();
      ctx.arc(cx, cy, r2, 0, Math.PI * 2);
      ctx.closePath();
      ctx.fill();
      break;
    }
    case 'gradientRect':
      ctx.fillRect(x, y, w, h);
      break;
    default:
      throw new Error(`drawShape: unknown type "${type}"`);
  }
  ctx.restore();
}

/* ---------- 6. exportImage ---------- */
function exportImage(canvas, outPath, opts = {}) {
  const { format = 'jpg', quality = 92 } = opts;
  const abs = path.isAbsolute(outPath) ? outPath : path.resolve(process.cwd(), outPath);
  fs.mkdirSync(path.dirname(abs), { recursive: true });

  let buf;
  if (format === 'jpg' || format === 'jpeg') {
    buf = canvas.toBuffer('image/jpeg', quality);
  } else if (format === 'png') {
    buf = canvas.toBuffer('image/png');
  } else {
    throw new Error(`exportImage: unsupported format "${format}"`);
  }
  fs.writeFileSync(abs, buf);
  return { path: abs, size: `${canvas.width}x${canvas.height}`, bytes: buf.length };
}

module.exports = { loadImage, registerFont, drawLayer, drawText, drawShape, exportImage, createCanvas };
```

---

## Section 5：`scripts/canvas/compose.js`

```javascript
#!/usr/bin/env node
// 入口脚本：node compose.js <config.json>
const fs = require('fs');
const path = require('path');
const { createCanvas, exportImage } = require('./primitives');
const { registerAllFonts } = require('./font-registry');

function emit(obj) { process.stdout.write(JSON.stringify(obj) + '\n'); }
function fail(reason, detail, fallback) {
  emit({ status: 'error', reason, detail, fallback: fallback || null });
  process.exit(1);
}

const TEMPLATE_DIR = path.resolve(__dirname, 'templates');
const KNOWN = ['cover-text-only', 'cover-image-text', 'left-image-right-text', 'grid-3x3', 'quote-card'];

(async () => {
  const t0 = Date.now();
  const configPath = process.argv[2];
  if (!configPath) fail('config_invalid', 'missing argv[2]: config.json path');

  let config;
  try {
    const raw = fs.readFileSync(configPath, 'utf8');
    config = JSON.parse(raw);
  } catch (e) {
    fail('config_invalid', `cannot read/parse config: ${e.message}`);
  }

  for (const f of ['template', 'size', 'output', 'format', 'fonts', 'params']) {
    if (config[f] === undefined) fail('config_invalid', `missing field: ${f}`);
  }

  if (!KNOWN.includes(config.template)) {
    fail('template_unknown', `template "${config.template}" not in ${KNOWN.join('|')}`);
  }

  const fontsDir = path.resolve(process.cwd(), 'assets', 'fonts');
  const { loaded, warnings } = registerAllFonts(fontsDir, config.fonts || []);
  if (loaded.length === 0) {
    fail('font_missing', 'no fonts registered', 'system-sans');
  }

  const [w, h] = config.size;
  const canvas = createCanvas(w, h);
  const ctx = canvas.getContext('2d');

  let templateModule;
  try {
    templateModule = require(path.join(TEMPLATE_DIR, `${config.template}.js`));
  } catch (e) {
    fail('template_unknown', `cannot load template module: ${e.message}`);
  }

  try {
    await templateModule.render(ctx, config);
  } catch (e) {
    fail('render_crashed', `${e.code || ''} ${e.message}`.trim());
  }

  let result;
  try {
    result = exportImage(canvas, config.output, { format: config.format, quality: config.quality || 92 });
  } catch (e) {
    fail('export_failed', e.message);
  }

  const out = {
    status: 'ok',
    path: result.path,
    size: result.size,
    render_ms: Date.now() - t0,
    fonts_loaded: loaded
  };
  if (warnings.length > 0) out.warnings = warnings;
  emit(out);
  process.exit(0);
})().catch((e) => fail('render_crashed', e && e.message ? e.message : String(e)));
```

---

## Section 6：5 个模板代码骨架

### 6.1 `scripts/canvas/templates/cover-text-only.js`

```javascript
const { drawShape, drawText } = require('../primitives');

async function render(ctx, config) {
  const [W, H] = config.size;
  const p = config.params || {};
  const bg = p.gradient
    ? { gradient: { from: p.gradient.from, to: p.gradient.to, direction: p.gradient.direction || 'vertical' } }
    : { fill: p.bgColor || '#F8EFE2' };
  drawShape(ctx, 'rect', { x: 0, y: 0, w: W, h: H, ...bg });

  if (p.decorativeShape) {
    drawShape(ctx, 'circle', {
      x: W * 0.7, y: H * 0.1, w: W * 0.4, h: W * 0.4,
      fill: p.accentColor || '#C8482E'
    });
  }

  const padding = 80;
  const titleSize = Math.round(W / 10);
  drawText(ctx, p.title || '', {
    x: padding, y: H * 0.35,
    font: 'SHS-Bold', size: titleSize,
    color: p.titleColor || '#1A1A1A',
    maxWidth: W - padding * 2,
    lineHeight: 1.25,
    align: 'left'
  });

  if (p.subtitle) {
    drawText(ctx, p.subtitle, {
      x: padding, y: H * 0.65,
      font: 'SHS-Regular', size: Math.round(W / 24),
      color: p.subtitleColor || '#666',
      maxWidth: W - padding * 2,
      lineHeight: 1.4
    });
  }
}

module.exports = { render };
```

### 6.2 `scripts/canvas/templates/cover-image-text.js`

```javascript
const { loadImage, drawLayer, drawShape, drawText } = require('../primitives');

async function render(ctx, config) {
  const [W, H] = config.size;
  const p = config.params || {};
  const ratio = typeof p.imageRatio === 'number' ? p.imageRatio : 0.6;
  const imgH = Math.round(H * ratio);

  drawShape(ctx, 'rect', { x: 0, y: 0, w: W, h: H, fill: p.bgColor || '#FFFFFF' });

  if (p.image) {
    const img = await loadImage(p.image);
    // 等比裁剪填满上 60%
    const scale = Math.max(W / img.width, imgH / img.height);
    const dw = img.width * scale, dh = img.height * scale;
    const dx = (W - dw) / 2, dy = (imgH - dh) / 2;
    drawLayer(ctx, img, { x: dx, y: dy, w: dw, h: dh });
  }

  for (const ov of (config.overlays || [])) {
    try {
      const o = await loadImage(ov.path);
      drawLayer(ctx, o, { x: 0, y: 0, w: W, h: imgH, opacity: ov.opacity || 0.3, blendMode: ov.blendMode || 'multiply' });
    } catch (_) { /* overlay 缺失不阻塞 */ }
  }

  const accent = p.accentColor || '#C8482E';
  const padding = 60;
  const textTop = imgH + 40;

  drawShape(ctx, 'roundRect', {
    x: padding, y: textTop,
    w: 12, h: Math.round(W / 8),
    radius: 6, fill: accent
  });

  drawText(ctx, p.title || '', {
    x: padding + 28, y: textTop,
    font: 'SHS-Bold', size: Math.round(W / 12),
    color: p.titleColor || '#1A1A1A',
    maxWidth: W - padding * 2 - 28,
    lineHeight: 1.25
  });

  if (p.subtitle) {
    drawText(ctx, p.subtitle, {
      x: padding + 28, y: textTop + Math.round(W / 8) + 24,
      font: 'SHS-Regular', size: Math.round(W / 28),
      color: p.subtitleColor || '#666',
      maxWidth: W - padding * 2 - 28,
      lineHeight: 1.45
    });
  }
}

module.exports = { render };
```

### 6.3 `scripts/canvas/templates/left-image-right-text.js`

```javascript
const { loadImage, drawLayer, drawShape, drawText } = require('../primitives');

async function render(ctx, config) {
  const [W, H] = config.size;
  const p = config.params || {};
  const ratio = typeof p.imageRatio === 'number' ? p.imageRatio : 0.5;
  const imgW = Math.round(W * ratio);

  drawShape(ctx, 'rect', { x: 0, y: 0, w: W, h: H, fill: p.bgColor || '#FAFAFA' });

  if (p.image) {
    const img = await loadImage(p.image);
    const scale = Math.max(imgW / img.width, H / img.height);
    const dw = img.width * scale, dh = img.height * scale;
    const dx = (imgW - dw) / 2, dy = (H - dh) / 2;
    drawLayer(ctx, img, { x: dx, y: dy, w: dw, h: dh });
  }

  const padding = 48;
  const textX = imgW + padding;
  const textW = W - imgW - padding * 2;
  let cursorY = padding * 1.5;

  for (const para of (p.paragraphs || [])) {
    const bbox = drawText(ctx, para.text || '', {
      x: textX, y: cursorY,
      font: para.font || 'SHS-Regular',
      size: para.size || Math.round(W / 32),
      color: para.color || '#1A1A1A',
      maxWidth: textW,
      lineHeight: para.lineHeight || 1.5
    });
    cursorY = bbox.y + bbox.h + (para.gap || 24);
    if (cursorY > H - padding) break;
  }
}

module.exports = { render };
```

### 6.4 `scripts/canvas/templates/grid-3x3.js`

```javascript
const { loadImage, drawLayer, drawShape, drawText } = require('../primitives');

async function render(ctx, config) {
  const [W, H] = config.size;
  const p = config.params || {};
  const spacing = p.spacing || 8;
  const captionH = p.caption ? Math.round(H * 0.12) : 0;
  const gridH = H - captionH;

  drawShape(ctx, 'rect', { x: 0, y: 0, w: W, h: H, fill: p.bgColor || '#FFFFFF' });

  const cellW = (W - spacing * 4) / 3;
  const cellH = (gridH - spacing * 4) / 3;
  const images = (p.images || []).slice(0, 9);

  for (let i = 0; i < images.length; i++) {
    const row = Math.floor(i / 3), col = i % 3;
    const x = spacing + col * (cellW + spacing);
    const y = spacing + row * (cellH + spacing);
    try {
      const img = await loadImage(images[i]);
      const scale = Math.max(cellW / img.width, cellH / img.height);
      const dw = img.width * scale, dh = img.height * scale;
      ctx.save();
      ctx.beginPath();
      ctx.rect(x, y, cellW, cellH);
      ctx.clip();
      drawLayer(ctx, img, { x: x + (cellW - dw) / 2, y: y + (cellH - dh) / 2, w: dw, h: dh });
      ctx.restore();
    } catch (_) {
      drawShape(ctx, 'rect', { x, y, w: cellW, h: cellH, fill: '#EEE' });
    }
  }

  if (p.caption) {
    drawText(ctx, p.caption, {
      x: 40, y: gridH + 12,
      font: 'SHS-Bold', size: Math.round(W / 24),
      color: p.captionColor || '#1A1A1A',
      maxWidth: W - 80,
      lineHeight: 1.3,
      align: 'center'
    });
  }
}

module.exports = { render };
```

### 6.5 `scripts/canvas/templates/quote-card.js`

```javascript
const { loadImage, drawLayer, drawShape, drawText } = require('../primitives');

async function render(ctx, config) {
  const [W, H] = config.size;
  const p = config.params || {};

  drawShape(ctx, 'rect', { x: 0, y: 0, w: W, h: H, fill: p.bgColor || '#F8EFE2' });

  const accent = p.accentColor || '#C8482E';
  const padding = Math.round(W * 0.1);

  // 装饰大引号
  drawText(ctx, '"', {
    x: padding, y: padding,
    font: 'SHSerif', size: Math.round(W / 4),
    color: accent,
    maxWidth: W - padding * 2,
    lineHeight: 1
  });

  const quoteY = padding + Math.round(W / 4) + 20;
  drawText(ctx, p.quote || '', {
    x: padding, y: quoteY,
    font: 'SHSerif', size: Math.round(W / 14),
    color: p.quoteColor || '#1A1A1A',
    maxWidth: W - padding * 2,
    lineHeight: 1.5,
    align: 'left'
  });

  drawText(ctx, p.author || '', {
    x: padding, y: H - padding - Math.round(W / 28),
    font: 'SHS-Regular', size: Math.round(W / 32),
    color: accent,
    maxWidth: W - padding * 2,
    lineHeight: 1.2,
    align: 'right'
  });

  if (p.decorative) {
    try {
      const d = await loadImage(p.decorative);
      drawLayer(ctx, d, { x: W - 200, y: H - 200, w: 160, h: 160, opacity: 0.85 });
    } catch (_) { /* 装饰缺失不阻塞 */ }
  }
}

module.exports = { render };
```

---

## Section 7：`scripts/setup-overlays.js`

```javascript
#!/usr/bin/env node
// 用 @napi-rs/canvas 程序生成 vignette.png 和 grain.png
const fs = require('fs');
const path = require('path');
const { createCanvas } = require('@napi-rs/canvas');

const OVERLAYS_DIR = path.resolve(__dirname, '..', 'assets', 'overlays');
fs.mkdirSync(OVERLAYS_DIR, { recursive: true });

function genVignette(W = 1024, H = 1536) {
  const canvas = createCanvas(W, H);
  const ctx = canvas.getContext('2d');
  const cx = W / 2, cy = H / 2;
  const grad = ctx.createRadialGradient(cx, cy, Math.min(W, H) * 0.3, cx, cy, Math.max(W, H) * 0.7);
  grad.addColorStop(0, 'rgba(0,0,0,0)');
  grad.addColorStop(1, 'rgba(0,0,0,0.65)');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, W, H);
  return canvas.toBuffer('image/png');
}

function genGrain(W = 1024, H = 1536) {
  const canvas = createCanvas(W, H);
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = 'rgba(255,255,255,0)';
  ctx.fillRect(0, 0, W, H);
  // 随机噪点
  const imageData = ctx.getImageData(0, 0, W, H);
  const d = imageData.data;
  for (let i = 0; i < d.length; i += 4) {
    const v = Math.random() < 0.5 ? 0 : 255;
    const a = Math.floor(Math.random() * 30); // 低 alpha 保证柔和
    d[i] = v; d[i + 1] = v; d[i + 2] = v; d[i + 3] = a;
  }
  ctx.putImageData(imageData, 0, 0);
  return canvas.toBuffer('image/png');
}

function writeIfMissing(name, gen) {
  const dest = path.join(OVERLAYS_DIR, name);
  if (fs.existsSync(dest)) { console.log(`[skip] ${name} 已存在`); return; }
  fs.writeFileSync(dest, gen());
  console.log(`[ok] ${name} 生成 (${fs.statSync(dest).size} bytes)`);
}

writeIfMissing('vignette.png', () => genVignette());
writeIfMissing('grain.png', () => genGrain());
console.log('overlays 完成');
```

---

## Section 8：`.claude/settings.json`

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node scripts/hooks/pre-tool-safety.js",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node scripts/hooks/session-summary.js",
            "timeout": 30
          }
        ]
      }
    ]
  },
  "env": {
    "TEAM_HOOK_PROFILE": "standard"
  }
}
```

---

## Section 9：`scripts/hooks/pre-tool-safety.js`

```javascript
#!/usr/bin/env node
// PreToolUse(Bash) 安全检查：阻止危险命令、硬编码 API key、非白名单 curl
let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => { raw += c; });
process.stdin.on('end', () => {
  let evt;
  try { evt = JSON.parse(raw || '{}'); } catch { process.exit(0); }

  const cmd = (evt.tool_input && evt.tool_input.command) || '';
  if (!cmd) process.exit(0);

  const HOSTS_ALLOW = ['api.chatanywhere.tech', 'github.com', 'raw.githubusercontent.com', 'codeload.github.com'];

  // 1. rm -rf 危险路径
  if (/\brm\s+(-[rRfF]+|--recursive|--force)\b.*\s+\/(\s|$)/.test(cmd) ||
      /\brm\s+-[rRfF]+\s+\$\w+/.test(cmd) ||
      /\brm\s+-[rRfF]+\s+\/(?:etc|usr|bin|root)\b/.test(cmd)) {
    process.stderr.write('[hook] blocked: rm -rf 指向危险路径\n');
    process.exit(2);
  }

  // 2. 硬编码 IMAGE2_API_KEY
  if (/IMAGE2_API_KEY\s*=\s*["']?[A-Za-z0-9_\-]{8,}/.test(cmd) &&
      !/IMAGE2_API_KEY\s*=\s*["']?\$\{?(IMAGE2_API_KEY|env:IMAGE2_API_KEY)/.test(cmd)) {
    process.stderr.write('[hook] blocked: 硬编码 IMAGE2_API_KEY，请用环境变量\n');
    process.exit(2);
  }

  // 3. eval 注入
  if (/\beval\b/.test(cmd) && /\$\{?\w+\}?/.test(cmd)) {
    process.stderr.write('[hook] blocked: eval 配合变量注入\n');
    process.exit(2);
  }

  // 4. 写 /etc/
  if (/>\s*\/etc\//.test(cmd) || /tee\s+\/etc\//.test(cmd)) {
    process.stderr.write('[hook] blocked: 写入 /etc/\n');
    process.exit(2);
  }

  // 5. curl 白名单（仅对真实 URL 拦截，本地路径放行）
  const curlMatches = cmd.match(/\b(?:curl|wget)\s+[^\n;|&]*?(https?:\/\/[^\s'"]+)/gi);
  if (curlMatches) {
    for (const m of curlMatches) {
      const urlMatch = m.match(/https?:\/\/([^\/\s'"]+)/i);
      if (!urlMatch) continue;
      const host = urlMatch[1].toLowerCase();
      const ok = HOSTS_ALLOW.some((h) => host === h || host.endsWith('.' + h));
      if (!ok) {
        process.stderr.write(`[hook] blocked: curl 非白名单域名 ${host}\n`);
        process.exit(2);
      }
    }
  }

  process.exit(0);
});
```

---

## Section 10：`scripts/hooks/session-summary.js`

```javascript
#!/usr/bin/env node
// Stop hook：将本次会话关键操作写入 .learnings/entries/SESSION-{ts}.json
const fs = require('fs');
const path = require('path');

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => { raw += c; });
process.stdin.on('end', () => {
  let evt = {};
  try { evt = JSON.parse(raw || '{}'); } catch { /* 容忍空输入 */ }

  const root = process.cwd();
  const dir = path.join(root, '.learnings', 'entries');
  try { fs.mkdirSync(dir, { recursive: true }); } catch { process.exit(0); }

  const ts = new Date().toISOString().replace(/[:.]/g, '-');
  const id = `SESSION-${ts}`;
  const entry = {
    id,
    type: 'LRN',
    timestamp: new Date().toISOString(),
    context: 'Claude Code session ended',
    lesson: '',
    status: 'pending',
    source_agent: evt.session_id || 'unknown',
    confidence: 0.5,
    meta: {
      stop_reason: evt.stop_reason || null,
      cwd: root
    }
  };

  try {
    fs.writeFileSync(path.join(dir, `${id}.json`), JSON.stringify(entry, null, 2));
  } catch { /* 写入失败也不阻塞 Stop */ }
  process.exit(0);
});
```

---

## Section 11：`CLAUDE.md`（v5 完整内容）

```markdown
# 小红书图文生成 Team v5

@CONVENTIONS.md
@.claude/skills/self-improving-agent/SKILL.md
@.claude/skills/instinct-engine/SKILL.md

---

## 项目概述

本 Team 用于自动化生产小红书图文笔记，支持从参考文章和示例图片学习风格，通过素材识图索引和智能匹配实现「文章 → 图片提示词 → 素材匹配 → Canvas 合成」闭环。

**v5 核心变更**：
- **底盘替换**：image-processor 内部 Pillow / Python 路径完全替换为基于 `@napi-rs/canvas` 的 Node 合成管线
- **新增 skill**：`canvas-image-composer`（业务无关合成层，6 原语 + 5 模板）
- **image2 收敛**：仅保留 `generations` 端点，作为「素材兜底生成」单一职责（写入 `image-examples/materials/`）
- **跨平台零编译**：`@napi-rs/canvas` Rust 预编译，Windows/macOS/Linux 安装零失败
- **字体打包**：思源黑体 + Noto Color Emoji（OFL 1.1 许可，可分发）
- **删除**：Pillow 依赖、image2 edits 端点、Python 脚本
- **对外接口 100% 兼容 v4**

---

## Team 成员

### 工作组 A：文字提炼组

| Agent | 核心职责 | v4→v5 |
|-------|---------|-------|
| `article-analyzer` | 遍历 articles/{folder}/，提取文字风格特征 | 不变 |
| `style-synthesizer` | 合成 xiaohongshu-style-writer skill | 不变 |

### 工作组 B：图片提炼组

| Agent | 核心职责 | v4→v5 |
|-------|---------|-------|
| `image-prompt-analyzer` | 结合文章上下文分析配图风格 | 不变 |
| `image-prompt-synthesizer` | 合成 xiaohongshu-image-prompt-writer skill | 不变 |

### 素材索引组

| Agent | 核心职责 | v4→v5 |
|-------|---------|-------|
| `image-recognizer` | 扫描 materials/ 建 index.json | 不变 |

### 生成组

| Agent | 核心职责 | v4→v5 |
|-------|---------|-------|
| `content-creator` | 生成推文草稿 + 图片提示词 | 不变 |
| `keyword-guard` | 通用敏感词审查（含图片提示词） | 不变 |
| `xiaohongshu-policy-guard` | 平台合规审查（含图片提示词） | 不变 |
| `image-matcher` | 根据图片提示词匹配最佳素材 | 不变 |
| **`image-processor`** | **缺素材→image2 generations 兜底；构造 canvas config；调 compose.js 合成** | **v5 重写** |

---

## 可用 Skills

| Skill | 说明 |
|-------|------|
| `xiaohongshu-style-writer` | 文字风格指南（动态生成） |
| `xiaohongshu-image-prompt-writer` | 图片提示词风格（动态生成） |
| `self-improving-agent` | 跨 skill 经验积累与自纠 |
| `instinct-engine` | 学习条目→instinct 提炼 |
| **`canvas-image-composer`** | **v5 新增**：6 原语 + 5 模板的业务无关合成层 |

---

## 工作流拓扑

```
articles/{folder}/
    ├── *.md / *.txt  →  article-analyzer  →  style-synthesizer  →  style skill
    └── images/       →  image-prompt-analyzer → image-prompt-synthesizer → prompt skill

image-examples/materials/  →  image-recognizer  →  index.json

用户关键词  →  content-creator  →  [keyword-guard ∥ xiaohongshu-policy-guard]
                                          ↓
                                    image-matcher  ←  index.json
                                          ↓
                                  ┌───────────────────────────────────┐
                                  │ image-processor (v5)              │
                                  │   1. 双审查校验                    │
                                  │   2. 缺素材 → image2 generations   │
                                  │      └→ image-examples/materials/  │
                                  │   3. 构造 canvas config:           │
                                  │      output/{name}/.canvas/N.json  │
                                  │   4. node compose.js → 合成图       │
                                  │   5. 重试 + 部分失败处理            │
                                  └───────────────────────────────────┘
                                          ↓
                              output/{article-name}/
                                  ├── article.md
                                  ├── images/*.jpg
                                  └── .canvas/   (临时 config)
```

---

## 上下文传递协议

| 文件 | 写入者 | 读取者 | v4→v5 |
|-----|-------|-------|-------|
| `article-analyzer-output.md` | article-analyzer | style-synthesizer | 不变 |
| `image-prompt-analyzer-output.md` | image-prompt-analyzer | image-prompt-synthesizer | 不变 |
| `image-examples/materials/index.json` | image-recognizer | image-matcher, image-processor | 不变 |
| `content-creator-output.md` | content-creator | guards, image-matcher, image-processor | 不变 |
| `keyword-guard-output.md` | keyword-guard | image-processor | 不变 |
| `xiaohongshu-policy-guard-output.md` | xiaohongshu-policy-guard | image-processor | 不变 |
| `image-matcher-output.md` | image-matcher | image-processor | 不变 |
| `image-processor-output.md` | image-processor | 用户 | 格式微调 |
| `*-done.txt` | 各 agent | 下游 agent | 不变 |
| **`output/{name}/.canvas/{N}.json`** | image-processor | compose.js | **v5 新增临时文件** |

---

## 初始化步骤

首次激活本 Team 时：

1. 创建 `.claude/workspace/`
2. 创建 `articles/`，按文章分文件夹（含文本文件 + `images/`）
3. 创建 `image-examples/reference/` 和 `image-examples/materials/`
4. 创建 `output/`
5. 初始化 `.learnings/entries/` 和 `.learnings/instincts/`
6. 初始化 `.claude/data/sensitive-words.txt` 和 `xiaohongshu-rules.txt`
7. **v5 新增**：执行 `npm install`（安装 `@napi-rs/canvas`，自动下载字体与生成 overlay）
8. **v5 新增**：确认 `assets/fonts/` 含思源黑体与 Noto Color Emoji；如缺失运行 `npm run setup-fonts`
9. 配置环境变量 `IMAGE2_API_KEY`（可选，仅素材兜底时需要）

---

## 降级规则

| 情况 | 处理 |
|-----|------|
| `@napi-rs/canvas` 安装失败 | 引导用户查 README 故障排除；不自动 fallback Python |
| `node` 未安装或版本 < 18 | image-processor 报错并提示升级 Node |
| 字体文件缺失 | font-registry fallback 系统 sans + warning，记入输出报告 |
| `assets/overlays/` 缺失 | 模板内 try/catch 跳过 overlay，不阻塞主合成 |
| image2 API 配额耗尽/网络异常 | 该图标注「无素材，已跳过」，重试 3 次指数退避 |
| compose.js 进程崩溃 | image-processor 重试 2 次；最终失败记入「部分完成」 |
| `IMAGE2_API_KEY` 未设置 | 仅在需兜底时报「无素材」并跳过；全部需兜底时全部跳过并提示用户 |
| 双审查未通过 | 展示修订建议，停止；不写 done.txt |
| `output/{name}/` 残留 | 仅清理 `.canvas/`；`images/` 覆盖式写入 |

---

## 安全红线

- 不硬编码任何凭证，统一用环境变量（`IMAGE2_API_KEY`）
- 不使用 `rm -rf $VARIABLE`（变量未验证时）
- 不对用户输入直接 `eval`
- `Bash` 权限仅 image-processor 持有，调用范围由白名单约束（见 CONVENTIONS.md）
- 所有路径从 `output-dir.txt` 读取，不依赖继承变量
- curl 仅允许白名单域名（`api.chatanywhere.tech`、`github.com` 字体下载）

---

## 版本信息

- **版本**：v5（从 v4 升级）
- **生成时间**：2026-05-05
- **Meta-Agents 版本**：v8
- **Profile**：standard
- **self-improving**：yes
- **instincts**：yes

---

## 命令速查表

| 命令 | 说明 |
|------|------|
| `/project:team` | 查看所有可用 Agent 和 Skill |
| `/project:article-analyzer` | 启动文章风格分析 |
| `/project:style-synthesizer` | 启动文字风格 skill 合成 |
| `/project:image-prompt-analyzer` | 启动配图风格分析 |
| `/project:image-prompt-synthesizer` | 启动图片提示词 skill 合成 |
| `/project:image-recognizer` | 启动素材识图索引 |
| `/project:content-creator` | 启动小红书推文生成 |
| `/project:keyword-guard` | 启动通用内容安全审查 |
| `/project:xiaohongshu-policy-guard` | 启动小红书平台合规审查 |
| `/project:image-matcher` | 启动素材匹配 |
| `/project:image-processor` | 启动 Canvas 合成（v5 新管线） |
```

---

## Section 12：`CONVENTIONS.md`（v5 完整内容）

```markdown
# CONVENTIONS.md — 小红书图文生成 Team v5

> 基于 Meta-Agents v8 核心规范，针对小红书图文生成场景裁剪。v5 仅 image-processor 工具用途字段更新，并新增 Canvas 合成规范章节。

---

## 文件命名规范

| 类型 | 规范 | 示例 |
|-----|------|------|
| Agent 文件 | kebab-case，与 `name` 字段一致 | `content-creator.md` |
| Skill 目录 | kebab-case | `canvas-image-composer/` |
| Skill 文件 | 固定名称 | `SKILL.md` |
| 辅助脚本 | kebab-case + 扩展名 | `compose.js` / `pre-tool-safety.js` |
| Canvas 模板文件 | kebab-case + `.js` | `cover-image-text.js` |
| Canvas 原语文件 | 固定 `primitives.js` | — |
| workspace 输出 | `[agent-name]-output.md` | `image-processor-output.md` |
| workspace 完成标记 | `[agent-name]-done.txt` | `image-processor-done.txt` |
| 版本目录 | `[name]_teams/[name]_teams_vN` | `xiaohongshu-content-creator_teams_v5/` |

---

## Agent Frontmatter 规范

```yaml
---
name: agent-name
description: |
  Use this agent when [触发条件]. Examples:

  <example>
  Context: [场景描述]
  user: "[用户请求]"
  assistant: "[如何响应]"
  <commentary>
  [为什么触发这个 agent]
  </commentary>
  </example>

  [2-4 个 example 块]

allowed-tools: ["Read", "Write"]
model: inherit
color: blue
---
```

### 必需字段

| 字段 | 说明 | 格式 |
|------|------|------|
| `name` | Agent 标识符 | 3-50 字符，小写字母、数字、连字符 |
| `description` | 触发条件 + 示例 | 必须含 2-4 个 `<example>` 块 |
| `allowed-tools` | 工具权限 | 最小权限原则 |
| `model` | 使用的模型 | `inherit`（推荐）/ `sonnet` / `opus` / `haiku` |
| `color` | UI 颜色标识 | `blue` / `cyan` / `green` / `yellow` / `magenta` / `red` |

### color 映射

| 颜色 | 适用场景 |
|------|---------|
| `blue` | 分析、审查、管理 |
| `cyan` | 文档、信息 |
| `green` | 生成、创建 |
| `yellow` | 验证、警告、搜索 |
| `red` | 安全、关键分析、审查 |
| `magenta` | 重构、转换 |

---

## 工具权限规范

| 工具 | 说明 | 风险 |
|-----|------|------|
| `Read` | 只读文件 | 最低，优先使用 |
| `Grep` | 全文搜索 | 最低 |
| `Glob` | 文件模式匹配 | 最低 |
| `Edit` | 精确修改片段 | 低，优于 Write |
| `Write` | 创建/覆盖文件 | 中，慎用 |
| `Bash` | 执行命令 | 高，必须说明使用场景 |

### 本 Team 的权限分配（v5）

| Agent | 权限 | Bash 使用场景 |
|-------|------|--------------|
| article-analyzer | Read, Write, Glob | — |
| style-synthesizer | Read, Write, Grep | — |
| image-prompt-analyzer | Read, Write, Glob | — |
| image-prompt-synthesizer | Read, Write, Grep | — |
| image-recognizer | Read, Write, Glob | — |
| content-creator | Read, Write, Grep | — |
| keyword-guard | Read, Write, Grep | — |
| xiaohongshu-policy-guard | Read, Write, Grep | — |
| image-matcher | Read, Write, Grep | — |
| **image-processor** | **Read, Write, Bash** | **调用 Node Canvas 合成脚本（`scripts/canvas/compose.js`）+ image2 generations API（curl）** |

---

## Canvas 合成规范（v5 新增）

### 模板命名约定

- 文件路径：`scripts/canvas/templates/<template-name>.js`
- 名称采用 kebab-case，描述布局而非业务（如 `cover-image-text` 而非 `xhs-cover`）
- 必须导出 `async function render(ctx, config)`，不返回值，由 compose.js 调用 exportImage

### 原语命名约定

- 6 个固定原语：`loadImage` / `registerFont` / `drawLayer` / `drawText` / `drawShape` / `exportImage`
- 不允许新增原语；新需求需在模板内组合现有原语
- 原语 opts 使用对象解构 + 默认值，避免位置参数

### 字体命名约定

| 字体文件 | alias | 用途 |
|---------|-------|------|
| `SourceHanSansSC-Regular.otf` | `SHS-Regular` | 正文 |
| `SourceHanSansSC-Bold.otf` | `SHS-Bold` | 标题 |
| `SourceHanSerifSC-Regular.otf` | `SHSerif` | 引言/装饰 |
| `NotoColorEmoji.ttf` | `Emoji` | Emoji fallback（drawText 自动 fallback）|

模板中 `font` 字段必须使用 alias，不直接写文件路径。新增字体需更新 `font-registry.js` 的 `DEFAULT_ALIASES` 表。

### Canvas Config 文件约定

- 写入路径：`output/{name}/.canvas/{N}.json`（隐藏目录）
- N 为零填充 2 位序号（`01`, `02`, ...）
- 字段顺序：template / size / output / format / quality / fonts / params / overlays
- 启动时 image-processor 必须清理旧 `.canvas/` 目录

---

## 代码规范

### Bash 脚本

```bash
#!/usr/bin/env bash
set -euo pipefail
readonly VAR="value"
"${VAR}"
[[ condition ]]
```

禁止：硬编码凭证 / `rm -rf $VARIABLE`（无验证）/ `eval` 配合用户输入 / 未加引号变量

### Node.js 脚本（v5 新增）

- 使用 CommonJS（`require`/`module.exports`），与 @napi-rs/canvas 默认 API 对齐
- 路径处理用 `path.resolve` + `path.isAbsolute`，不拼接字符串
- 异步操作用 `async/await`，不混用 callback
- 错误对象赋 `code` 字段（如 `image_load_failed`），便于上层路由
- stdout 仅输出合法 JSON，调试信息写 stderr
- 文件写入前 `fs.mkdirSync(path.dirname(p), { recursive: true })`

---

## 输出语言规范

| 内容类型 | 规范 |
|---------|------|
| Agent 提示词正文 | 中文 |
| `description` 字段 | 中英双语 |
| 代码注释 | 中文，变量名英文 |
| README.md / CONVENTIONS.md | 中文 |
| 错误信息输出 | 中文 |

---

## 版本管理规范

- 目录结构：`[name]_teams/[name]_teams_vN/`
- 首版：v1，无 改进点.md
- 升版：v2+，必须包含 改进点.md

---

## 安全红线

1. 不硬编码任何凭证，统一用环境变量
2. 不使用 `rm -rf $VARIABLE`（变量未验证时）
3. 不对用户输入直接 `eval`
4. 不在未确认的情况下覆盖已有版本目录
5. `Bash` 权限必须在提示词中有明确使用场景说明
6. 所有路径从 `output-dir.txt` 读取，不依赖继承变量
7. **v5 新增**：image-processor 的 Bash 调用必须落入白名单（见 phase-2-tech-specs.md Section 13）
```

---

## Section 13：image-processor 工具权限白名单

| 类别 | 命令模板 | 说明 |
|------|---------|------|
| ✅ 允许 | `node scripts/canvas/compose.js "<config-path>"` | Canvas 合成入口，config-path 必须在 `output/*/.canvas/` 内 |
| ✅ 允许 | `node --version` | Node 版本预检 |
| ✅ 允许 | `npm install` / `npm run setup-fonts` | 首次安装与字体下载（仅文档提示）|
| ✅ 允许 | `mkdir -p "output/<name>/.canvas"` / `mkdir -p "output/<name>/images"` | 路径必须以 `output/` 开头且不含 `..` |
| ✅ 允许 | `rm -rf "output/<name>/.canvas"` | 仅 `.canvas` 隐藏目录，且必须显式拼接绝对/项目相对路径，禁止变量 |
| ✅ 允许 | `curl -sS -X POST -H "Authorization: Bearer $IMAGE2_API_KEY" -H "Content-Type: application/json" -d @<payload-json> "https://api.chatanywhere.tech/v1/images/generations"` | 仅 generations 端点；密钥通过环境变量；payload 落盘 JSON 后 `@` 引用 |
| ✅ 允许 | `curl -sS -o "image-examples/materials/<slug>.jpg" "<image-url-from-api-response>"` | 下载 image2 返回的图片 URL，`<slug>` 由 prompt 哈希前 8 位生成 |
| 🔴 禁止 | `rm -rf $VAR` / `rm -rf /` / `rm -rf ./` | 任何变量未验证的删除 |
| 🔴 禁止 | `IMAGE2_API_KEY=sk-xxx ...` | 不允许命令行内联 key（hook 拦截）|
| 🔴 禁止 | `curl https://other-host.com/...` | 非白名单域名（hook 拦截）|
| 🔴 禁止 | `eval $...` / `bash -c "$..."` | 任何 eval / 间接执行 |
| 🔴 禁止 | 写入 `/etc/`、`/usr/`、`/root/`、`~/.ssh/` | hook 拦截 |
| 🔴 禁止 | `python` / `python3` / `pip` 调用 | v5 已删除 Pillow 路径，禁止回退 |

**Hook 兜底**：`pre-tool-safety.js` 在所有 Bash 命令执行前拦截非白名单 curl 和危险 rm。即使 image-processor 提示词出错，也无法绕过白名单。

---

## Section 14：依赖与环境检查清单

| 项 | 检查命令 | 失败处理 |
|---|---------|---------|
| Node 版本 ≥ 18 | `node --version` | image-processor 启动时检查；不达标报错并停止 |
| npm 已安装 | `npm --version` | 同上 |
| `@napi-rs/canvas` 已安装 | `node -e "require('@napi-rs/canvas')"` | 提示用户运行 `npm install` |
| `assets/fonts/` 包含 4 个字体 | 检查 4 个 `.otf/.ttf` 文件存在且 size > 0 | 提示运行 `npm run setup-fonts`，否则降级系统字体 |
| `assets/overlays/` 含 vignette/grain | 检查 PNG 文件存在 | 提示运行 `npm run setup-overlays`；overlay 缺失不阻塞主合成 |
| `IMAGE2_API_KEY` 已设置 | `[ -n "$IMAGE2_API_KEY" ]` | 可选；仅缺素材兜底时需要；未设置则该图标注「无素材」 |
| `scripts/hooks/*.js` 存在 | `[ -f scripts/hooks/pre-tool-safety.js ]` | toolsmith-infra 在 Phase 4a 创建；缺失则 settings.json hook 调用失败但不阻塞流程 |
| 网络可访问 `api.chatanywhere.tech` | `curl -I https://api.chatanywhere.tech` | 仅 image2 兜底时需要；网络异常 → 跳过该图 |

**首次安装路径**：

```bash
cd xiaohongshu-content-creator_teams_v5
npm install
# postinstall 自动执行 setup-fonts + setup-overlays
# 若失败可手动重试：
npm run setup-fonts
npm run setup-overlays
export IMAGE2_API_KEY="your_key"   # PowerShell: $env:IMAGE2_API_KEY="your_key"
```

---

## Section 15：与 UX 接口契约

| 由 UX 负责 | 由 Tech 负责（本文件） |
|-----------|---------------------|
| `image-processor.md` 五层 prompt 文案与 description | `compose.js` / `primitives.js` / `font-registry.js` / 5 模板代码 |
| `canvas-image-composer/SKILL.md` 文案与 6 原语契约说明 | `setup-fonts.js` / `setup-overlays.js` / `package.json` |
| `README.md` 故障排除与迁移指南文案 | hook 脚本（`pre-tool-safety.js` / `session-summary.js`）+ `.claude/settings.json` |
| `改进点.md` 用户视角 | `CLAUDE.md` v5 + `CONVENTIONS.md` v5 完整内容（含 Canvas 合成规范）|
| 7 条 Prompt 增强规则文本 | image-processor Bash 白名单与依赖检查清单 |
| 复用 v4 文件清单 | Node ≥ 18 / 字体下载流程 / IMAGE2_API_KEY 环境变量协议 |

**协调点（与 UX 一致性核对）**：
- UX 写的 image-processor.md 中 `allowed-tools: ["Read", "Write", "Bash"]` 与本文件 Section 13 白名单一致 ✅
- UX 在 SKILL.md 列出的 6 原语签名与本文件 Section 4 实现一致 ✅
- UX 在 SKILL.md 列出的 config.json 字段与本文件 Section 5 compose.js 解析一致 ✅
- UX 在 README 标注「`npm install` + Node ≥ 18」与本文件 Section 14 检查清单一致 ✅

**toolsmith 落盘提示**：
- toolsmith-infra：创建目录、初始化 `package.json`、`assets/fonts/LICENSE.md`、hook 脚本、`.claude/settings.json`
- toolsmith-agents：写入 image-processor.md（UX 提供）+ 复制 9 个 v4 agent
- toolsmith-skills：写入 canvas-image-composer/SKILL.md（UX 提供）+ 复制 4 个 v4 skill；写入 5 模板代码 + primitives.js + compose.js + font-registry.js + setup-fonts.js + setup-overlays.js（本文件 Section 4-7）
- toolsmith-assembler：合并 worktree、写入 README、改进点.md、CLAUDE.md、CONVENTIONS.md（本文件 Section 11-12）
