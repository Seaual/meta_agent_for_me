# Hook 系统与运行时 Profile

## 标准 Hook 集

| Hook | 事件 | Matcher | 作用 | Profile |
|------|------|---------|------|---------|
| 安全检查 | PreToolUse | Bash | 阻止危险命令（`rm -rf /`、硬编码凭证等），exit 2 阻止执行 | minimal+ |
| 会话摘要 | Stop | — | 将本次会话关键决策写入 `.learnings/` 或 workspace | standard+ |
| 文档提醒 | PostToolUse | Write | 写入代码文件后提醒更新相关文档 | strict |

## Hook 脚本规范

```
scripts/hooks/
├── pre-tool-safety.js      ← PreToolUse: 安全检查
├── session-summary.js      ← Stop: 会话摘要
└── post-write-doc-check.js ← PostToolUse: 文档提醒
```

脚本要求：
- Node.js（跨平台：Windows / macOS / Linux）
- 从 stdin 读取 JSON 输入，输出 JSON 到 stdout
- PreToolUse：exit 2 = 阻止，exit 0 = 放行
- 超时：安全检查 5s，会话摘要 30s，文档提醒 10s
- 开头包含 `#!/usr/bin/env node`

## settings.json hooks 配置格式

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "node scripts/hooks/pre-tool-safety.js",
        "timeout": 5
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "node scripts/hooks/session-summary.js",
        "timeout": 30
      }]
    }],
    "PostToolUse": [{
      "matcher": "Write",
      "hooks": [{
        "type": "command",
        "command": "node scripts/hooks/post-write-doc-check.js",
        "timeout": 10
      }]
    }]
  }
}
```

## 自定义 Hook

visionary-tech 可根据业务需求在 Tech 规格中设计额外 hook（如限制写入路径白名单、限制只能执行特定命令、自动 git commit 等）。自定义 hook 遵循与标准 hook 相同的脚本规范。

## 运行时 Profile

三个 Profile 对应不同的约束力度，在 Phase 0 由用户选择（Q8），写入 `.claude/workspace/profile.txt`。

| Profile | Hook 行为 | Agent 权限策略 | 适用场景 |
|---------|----------|--------------|---------|
| `minimal` | 仅安全检查（1 hook） | Bash 宽松，Write 无限制 | 个人项目、快速原型 |
| `standard` | 安全 + 会话摘要（2 hooks）| Bash 需说明理由 | 团队日常开发（默认） |
| `strict` | 全部 hook + 审批 | Bash 最小化，Write 需路径白名单 | 生产环境、安全敏感 |

**Profile 影响**：
- `settings.json` — hooks 配置段根据 profile 增减
- 生成的 agent 的 `allowed-tools` — strict 模式下自动收紧
- CONVENTIONS — strict 模式追加额外安全规则

**运行时切换**：环境变量 `TEAM_HOOK_PROFILE=minimal|standard|strict` 覆盖，不需要重新生成 Team。
