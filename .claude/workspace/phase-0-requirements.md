# Phase 0 需求文档 — Tutorial Generator Agent Team

## 核心目标
为技术文档自动生成交互式教程，包含分步指南、代码示例和练习题。

---

## Agent 设计需求（5个）

### 1. file-analyzer
- **职责**：扫描项目目录，识别代码文件和文档结构
- **权限**：需要 Bash 权限读取项目文件结构
- **输出**：项目结构分析报告

### 2. content-writer
- **职责**：基于分析结果编写教程正文（分步指南 + 代码示例）
- **依赖**：file-analyzer 完成后执行
- **输出**：各章节教程内容

### 3. exercise-designer
- **职责**：为每个章节设计动手练习题
- **权限**：可与 file-analyzer 并行执行
- **输出**：练习题集合

### 4. content-reviewer
- **职责**：审查教程完整性和准确性
- **反馈循环**：最多 2 轮
- **输出**：审查报告 + 修改建议

### 5. assembler
- **职责**：将所有内容组装为最终教程文档
- **依赖**：所有上游 agent 完成
- **输出**：最终教程文档

---

## 协作拓扑

```
file-analyzer ──┬──► content-writer ──► content-reviewer ──► assembler
                │           ↑                    │
exercise-       ────────────┘────────────────────┘
designer                         (反馈循环，最多2轮)
```

### 并行关系
- **file-analyzer** 和 **exercise-designer** 可并行执行
- **content-writer** 依赖 file-analyzer 完成
- **content-reviewer** 形成反馈循环（最多 2 轮）

---

## 技术约束

| 项目 | 要求 |
|-----|------|
| 项目位置 | 当前目录 |
| self-improving | yes |
| 数据库 | 不需要 |
| 支持语言 | Python 和 JavaScript 项目 |
| 反馈循环 | 最多 2 轮 |
| MCP 集成 | 无 |

---

## 交付物
- 5 个 agent 配置文件
- 完整的 CLAUDE.md 和 CONVENTIONS.md
- self-improving-agent skill（因为 self-improving = yes）
- README.md 使用说明