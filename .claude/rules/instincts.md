# Instincts 持续学习协议

> 此规范仅在 `self-improving=yes` 且 `instincts=yes` 时适用。

## 目录结构

```
.learnings/
├── README.md
├── entries/               ← 原始 learning 条目
│   ├── LRN-001.json
│   └── ERR-002.json
└── instincts/             ← 提炼后的 instinct
    └── INSTINCT-001.json
```

## Learning 条目格式（entries/）

```json
{
  "id": "LRN-001",
  "type": "LRN",
  "timestamp": "2025-01-01T10:00:00Z",
  "context": "调用 API 时未检查 token 过期",
  "lesson": "API 调用前应检查 token 有效性",
  "status": "pending",
  "source_agent": "backend-dev",
  "confidence": 0.7
}
```

类型：`LRN`（经验）、`ERR`（错误）、`FEAT`（需求）
状态：`pending` → `reviewed` → `promoted`（提炼为 instinct 后）

## Instinct 格式（instincts/）

```json
{
  "id": "INSTINCT-001",
  "pattern": "API 调用前检查 token 有效性",
  "confidence": 0.85,
  "source_entries": ["LRN-001", "LRN-007", "ERR-012"],
  "created": "2025-01-05T10:00:00Z",
  "last_reinforced": "2025-01-10T10:00:00Z",
  "decay_days": 30,
  "status": "active"
}
```

## 提炼规则

- ≥3 条 learning 涉及相同模式 → 自动提炼为 1 个 instinct
- 置信度 = 源 learning 的平均置信度 × 数量加权（上限 0.95）
- 新 learning 验证已有 instinct → `last_reinforced` 更新，置信度 +0.05（上限 0.95）
- 超过 `decay_days` 未验证 → 置信度 -0.1/周
- 置信度 < 0.3 → `status` 改为 `archived`
- agent 执行时读取 `instincts/` 中 `status: active` 且置信度 ≥ 0.5 的条目

## 与 self-improving 的关系

| self-improving | instincts | 行为 |
|---------------|-----------|------|
| no | — | 不生成 `.learnings/`，跳过全部 |
| yes | no | 扁平 `.learnings/`（v7 兼容） |
| yes | yes | 两层结构 + instinct-engine skill |
