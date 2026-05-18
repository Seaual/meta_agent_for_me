# Learnings

本目录存储小红书图文生成 Team 的持续学习记录。

## 结构

- `entries/` — 原始 learning 条目（经验、错误、需求）
- `instincts/` — 提炼后的 instinct（可复用的风格模式、决策规则）

## 格式

### Learning 条目（entries/）

```json
{
  "id": "LRN-XHS-001",
  "type": "LRN",
  "timestamp": "2025-01-01T10:00:00Z",
  "context": "...",
  "lesson": "...",
  "status": "pending",
  "source_agent": "content-creator",
  "confidence": 0.7
}
```

### Instinct（instincts/）

```json
{
  "id": "INSTINCT-XHS-001",
  "pattern": "小红书种草型推文风格",
  "confidence": 0.75,
  "source_entries": ["LRN-XHS-001"],
  "created": "2025-01-01T10:00:00Z",
  "last_reinforced": "2025-01-01T10:00:00Z",
  "decay_days": 30,
  "status": "active",
  "features": {
    "opening_style": "痛点提问式",
    "emoji_density": "中高密度",
    "paragraph_length": "短段落为主",
    "cta_style": "软引导",
    "hashtag_strategy": "3-5个精准标签"
  }
}
```
