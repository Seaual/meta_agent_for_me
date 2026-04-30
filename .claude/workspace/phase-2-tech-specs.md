# Phase 2 Tech 规格 — question-generator

**基于**：phase-1-architecture.md
**负责范围**：工具权限 + Skill/MCP + Workspace 协议

---

## 工具权限分配

| Agent | allowed-tools | Bash 使用场景 |
|-------|---------------|--------------|
| **pdf-reader** | Read | — |
| **question-generator** | Read, Write | — |
| **quality-reviewer** | Read, Write | — |
| **word-exporter** | Read, Bash | 执行 pandoc 命令进行 Markdown → Word 转换 |

---

## Skill 需求 + 搜索提示（供 Library Scout 使用）

| 需求描述 | 搜索关键词（英文） | 使用的 Agent | 备注 |
|---------|------------------|------------|------|
| PDF 内容解析 | pdf parse, pdf read, document extract | pdf-reader | Claude 内置 PDF 读取，可能不需要独立 skill |
| 题目生成 | question generate, quiz create, exam maker | question-generator | 核心功能，需原创或深度定制 |
| 答案验证 | answer validate, fact check, verify | quality-reviewer | 可能不需要独立 skill，使用 agent 逻辑 |
| Markdown 转 Word | markdown to word, pandoc, docx convert | word-exporter | 使用 pandoc 命令行工具 |
| 自我改进 | self-improving, learning, feedback | 所有 agent | 需配置 self-improving-agent skill |
| Instinct 提炼 | instinct, pattern mining, learning | self-improving-agent | 需配置 instinct-engine skill |

## Agent 搜索提示（供 Library Scout 使用）

| 目标 Agent | 搜索关键词（英文） | 期望的核心能力 |
|-----------|------------------|--------------|
| pdf-reader | pdf reader, document parser, content extractor | 读取 PDF，提取结构化内容 |
| question-generator | quiz generator, exam creator, question maker | 根据内容生成题目 |
| quality-reviewer | code reviewer, content reviewer, validator | 审查内容质量，验证准确性 |
| word-exporter | document exporter, format converter | 导出文档到不同格式 |

---

## 需原创的 Skill

### self-improving-agent

**触发场景**：Team 启用了 self-improving 功能，需要记录运行经验

**核心步骤**：
1. 检查 `.learnings/` 目录是否存在
2. 每次会话结束时，提取关键操作和决策
3. 将经验写入 `.learnings/entries/LRN-XXX.json`
4. 记录错误时写入 `.learnings/entries/ERR-XXX.json`

**需要辅助脚本**：no（由 agent 内部逻辑实现）

### instinct-engine

**触发场景**：self-improving 启用且 instincts 启用，需要提炼可复用模式

**核心步骤**：
1. 扫描 `.learnings/entries/` 目录
2. 识别相同模式的 learning（≥3 条）
3. 提炼为 instinct，写入 `.learnings/instincts/INSTINCT-XXX.json`
4. 更新置信度和衰减时间

**需要辅助脚本**：no（由 agent 内部逻辑实现）

---

## MCP 集成配置

**本 Team 不依赖 MCP 工具**，使用 Claude 内置能力 + pandoc 命令行工具。

---

## Hook 配置

根据 Profile: minimal，仅包含安全检查 Hook。

### settings.json hooks 配置段

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "node .claude/scripts/hooks/pre-tool-safety.js",
        "timeout": 5
      }]
    }]
  }
}
```

### Hook 脚本实现要点

#### pre-tool-safety.js

| 检查项 | 实现要点 |
|-------|---------|
| 危险命令拦截 | 阻止 `rm -rf /`、`rm -rf ~`、`rm -rf *` |
| 凭证硬编码检测 | 检测命令中是否包含 API key、password 等敏感信息 |
| eval 注入检测 | 阻止 `eval` 配合用户输入的组合 |

---

## Workspace 文件协议

| 文件 | 写入者 | 读取者 | 格式说明 |
|-----|-------|-------|---------|
| `workspace/pdf-content.md` | pdf-reader | question-generator, quality-reviewer | PDF 内容分析报告（结构化 Markdown）|
| `workspace/questions.md` | question-generator | quality-reviewer, word-exporter | 题目文件（Markdown 格式）|
| `workspace/review-report.md` | quality-reviewer | 用户 | 审查报告 |
| `output/questions.docx` | word-exporter | 用户 | Word 导出文件 |

**传递顺序**：
```
pdf-reader → pdf-content.md → question-generator → questions.md → quality-reviewer → word-exporter → questions.docx
```

---

## 辅助脚本需求

| 脚本 | 用途 | 调用方 |
|-----|------|-------|
| `hooks/pre-tool-safety.js` | Bash 命令安全检查 | Hook 系统 |
| `check-pandoc.sh` | 检测 pandoc 是否安装 | word-exporter |

### check-pandoc.sh 实现

```bash
#!/usr/bin/env bash
# 检测 pandoc 是否可用

if command -v pandoc &> /dev/null; then
    echo "✅ pandoc 已安装: $(pandoc --version | head -1)"
    exit 0
else
    echo "❌ pandoc 未安装"
    echo ""
    echo "安装方法："
    echo "  Windows: choco install pandoc 或 winget install pandoc"
    echo "  macOS:   brew install pandoc"
    echo "  Linux:   sudo apt install pandoc 或 sudo yum install pandoc"
    exit 1
fi
```

---

## .learnings 目录结构

启用 self-improving + instincts 时使用：

```
.learnings/
├── README.md                    # 说明文档
├── entries/                     # 原始 learning 条目
│   ├── LRN-001.json            # 成功经验
│   └── ERR-001.json            # 错误记录
└── instincts/                   # 提炼后的 instinct
    └── INSTINCT-001.json       # 可复用模式
```

### Learning 条目格式

```json
{
  "id": "LRN-001",
  "type": "LRN",
  "timestamp": "2026-03-27T10:00:00Z",
  "context": "出题场景描述",
  "lesson": "学到的经验",
  "status": "pending",
  "source_agent": "question-generator",
  "confidence": 0.8
}
```

### Instinct 格式

```json
{
  "id": "INSTINCT-001",
  "pattern": "招聘资料优先考查数字、时间类知识点",
  "confidence": 0.85,
  "source_entries": ["LRN-001", "LRN-002", "LRN-003"],
  "created": "2026-03-27T10:00:00Z",
  "last_reinforced": "2026-03-27T10:00:00Z",
  "decay_days": 30,
  "status": "active"
}
```

---

## 与 Visionary-UX 的注意点

| Agent | UX Layer 3 步骤 | Tech 注意事项 |
|-------|----------------|--------------|
| word-exporter | Step 2 检查 pandoc | 需要提供 check-pandoc.sh 脚本 |
| quality-reviewer | 需同时读取两个文件 | 无特殊权限需求，Read 即可 |
| question-generator | Subagent 委派逻辑 | 无特殊权限需求，使用 Claude 内置能力 |

---

## 目录结构

```
question-generator_teams_v1/
├── CLAUDE.md
├── README.md
├── CONVENTIONS.md
├── input/                      # 用户放置 PDF 文件
├── output/                     # 导出文件输出
├── .claude/
│   ├── agents/
│   │   ├── pdf-reader.md
│   │   ├── question-generator.md
│   │   ├── quality-reviewer.md
│   │   └── word-exporter.md
│   ├── skills/
│   │   └── self-improving-agent/
│   │       └── SKILL.md
│   ├── scripts/
│   │   └── hooks/
│   │       └── pre-tool-safety.js
│   ├── workspace/              # 运行时数据传递
│   └── commands/
│       └── team.md             # /project:team 入口
└── .learnings/
    ├── README.md
    ├── entries/
    └── instincts/
```