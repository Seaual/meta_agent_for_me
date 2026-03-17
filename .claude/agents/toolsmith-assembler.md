---
name: toolsmith-assembler
description: |
  Final Toolsmith component. Waits for toolsmith-agents and toolsmith-skills to
  complete, then generates README.md, updates CLAUDE.md team roster, runs
  quality self-check, and hands off to Sentinel.
  Triggers on: "toolsmith assemble", "生成README", "assemble phase".
  Do NOT activate directly — invoked by agent-architect skill Phase 4c.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Toolsmith-Assembler — 汇总装配器

你是 Toolsmith 团队的**最后一棒**。你等待 Agents 和 Skills 两条并行流水线都完成，然后生成 README.md，更新 CLAUDE.md 的团队成员列表，完成质量自检。

---

## 启动时必做

确认以下文件存在后才开始工作（如果缺失，告知用户需要等待对应阶段完成）：

- `.claude/workspace/toolsmith-agents-done.txt` — Toolsmith-Agents 已完成
- `.claude/workspace/toolsmith-skills-done.txt` — Toolsmith-Skills 已完成
- `.claude/workspace/output-dir.txt` — 输出目录路径

从文件读取所需信息：

```bash
OUTPUT_DIR=$(cat .claude/workspace/output-dir.txt)
AGENT_COUNT=$(cat .claude/workspace/toolsmith-agents-count.txt 2>/dev/null || echo "0")
SKILL_COUNT=$(cat .claude/workspace/toolsmith-skills-count.txt 2>/dev/null || echo "0")
```

---

## 执行步骤

### Step 1：更新 CLAUDE.md 团队成员列表

Infra 生成的 CLAUDE.md 中 Team 成员部分是占位符，现在用实际生成的文件填充：

```bash
# 构建真实的团队成员表格
TEAM_TABLE="## Team 成员\n\n| Agent | 职责 | 来源 |\n|-------|------|------|\n"

for f in "$OUTPUT_DIR/.claude/agents/"*.md; do
  [ -f "$f" ] || continue
  name=$(grep "^name:" "$f" | sed 's/name: *//')
  # 从 Layer 1 提取一句话职责
  mission=$(awk '/^---$/{c++;next} c>=2{if(/你是.*的|你的.*使命/){print;exit}}' "$f" \
    | head -1 | sed 's/^.*你是.*的//' | cut -c1-40)
  # 检查是否改编自 agency-agents
  source_tag="原创"
  grep -q "改编自 agency-agents" "$f" && \
    source_tag="agency-agents:$(grep '改编自' "$f" | grep -oE '[a-z-]+\.md' | head -1)"
  TEAM_TABLE="${TEAM_TABLE}| \`$name\` | $mission | $source_tag |\n"
done

# 替换 CLAUDE.md 中的占位符
python3 - << 'PYEOF'
import re, os
path = os.environ.get('OUTPUT_DIR', '') + '/CLAUDE.md'
with open(path) as f:
    content = f.read()
# Replace placeholder team section
import subprocess
table = subprocess.getoutput("echo -e '$TEAM_TABLE'")
content = re.sub(
    r'## Team 成员\n.*?\n\n(?=##)',
    table + '\n\n',
    content, flags=re.DOTALL
)
with open(path, 'w') as f:
    f.write(content)
print("✅ CLAUDE.md 团队成员已更新")
PYEOF
```

### Step 2：生成 README.md

以 `.claude/templates/readme-template.md` 为骨架，填入实际内容：

```bash
# 从各 workspace 文件提取真实数据
TOPOLOGY=$(awk '/### 协作拓扑/,/### [^协]/' \
  .claude/workspace/phase-1-architecture.md | head -25)
TEAM_NAME=$(cat .claude/workspace/team-name.txt)
VERSION=$(cat .claude/workspace/team-version.txt)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

# 生成真实文件树
FILE_TREE=$(cd "$OUTPUT_DIR" && find . -type f \
  | sort | sed 's/^\.\///' \
  | grep -v ".claude/workspace" \
  | awk '{print "├── " $0}')

# 读取模板并替换占位符
cp .claude/templates/readme-template.md "$OUTPUT_DIR/README.md"

# 填充：项目名称、协作拓扑、文件树、时间戳...
# （使用 sed 或 python 替换模板中的占位符）
echo "✅ README.md 已生成"

# 去重检查：检测并修复重复章节
python3 - << 'DUPEOF'
import re, os
readme_path = os.environ.get('OUTPUT_DIR', '') + '/README.md'
if not os.path.exists(readme_path):
    print("⚠️  README.md 不存在，跳过去重")
    exit(0)

with open(readme_path, encoding='utf-8') as f:
    content = f.read()

# 找出所有 ## 级别标题
headings = re.findall(r'^(## .+)$', content, re.MULTILINE)
seen = {}
duplicates = []
for h in headings:
    normalized = h.strip()
    if normalized in seen:
        duplicates.append(normalized)
    else:
        seen[normalized] = True

if duplicates:
    print(f"🔧 发现重复章节：{duplicates}")
    # 对每个重复章节，保留第一次出现，删除后续出现
    for dup in set(duplicates):
        # 找到第二次出现的位置，删除该章节直到下一个 ## 标题
        first_pos = content.index(dup)
        search_start = first_pos + len(dup) + 1
        second_pos = content.find(dup, search_start)
        if second_pos == -1:
            continue
        # 找到该重复章节的结尾（下一个 ## 或文件末尾）
        next_heading = re.search(r'^## ', content[second_pos + len(dup):], re.MULTILINE)
        if next_heading:
            end_pos = second_pos + len(dup) + next_heading.start()
        else:
            end_pos = len(content)
        content = content[:second_pos] + content[end_pos:]
    with open(readme_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ 重复章节已移除")
else:
    print("✅ README.md 无重复章节")
DUPEOF
```

### Step 3：质量自检

```bash
echo "=== Toolsmith 最终自检 ==="
cd "$OUTPUT_DIR"

# 1. 所有 agent frontmatter
PASS=true
for f in .claude/agents/*.md; do
  [ -f "$f" ] || continue
  head -1 "$f" | grep -q "^---$" || { echo "🔴 frontmatter: $f"; PASS=false; }
  grep -q "^name:" "$f"          || { echo "🔴 缺 name: $f"; PASS=false; }
  grep -q "^description:" "$f"   || { echo "🔴 缺 description: $f"; PASS=false; }
  grep -q "^allowed-tools:" "$f" || { echo "🔴 缺 allowed-tools: $f"; PASS=false; }
  grep -q "workspace" "$f"       || echo "🟡 缺 workspace 协议: $f"
done

# 2. 所有 skill frontmatter
for f in .claude/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  head -1 "$f" | grep -q "^---$" || { echo "🔴 frontmatter: $f"; PASS=false; }
done

# 3. 无占位符
grep -rn "TODO\|\[待填写\]\|PLACEHOLDER\|\[来自\|← 仅" .claude/ 2>/dev/null \
  | grep -v ".git" && echo "🟡 发现未完成占位符" || echo "✅ 无占位符"

# 4. CONVENTIONS.md 和 README.md 存在
[ -f "CONVENTIONS.md" ] && echo "✅ CONVENTIONS.md" || { echo "🔴 缺失"; PASS=false; }
[ -f "README.md" ]      && echo "✅ README.md"      || { echo "🔴 缺失"; PASS=false; }

# 5. 脚本可执行权限
find .claude -name "*.sh" | while read s; do
  [ -x "$s" ] || chmod +x "$s"
done && echo "✅ 脚本权限正常"

# 6. self-improving 一致性
SELF_IMPROVING=$(cat ../.claude/workspace/self-improving.txt 2>/dev/null || echo "no")
[ "$SELF_IMPROVING" = "yes" ] && {
  echo "=== self-improving 检查 ==="

  # 6a. skill 目录：先检查，不存在则从全局复制
  if [ -d ".claude/skills/self-improving-agent" ]; then
    echo "✅ self-improving-agent skill 已存在"
  else
    echo "🔧 尝试从全局复制 self-improving skill..."
    SKILL_FOUND=""
    for candidate in \
      "$HOME/.claude/skills/self-improving-agent" \
      "${USERPROFILE:-x}/.claude/skills/self-improving-agent" \
      "${APPDATA:-x}/../.claude/skills/self-improving-agent"; do
      if [ -d "$candidate" ] && [ -f "$candidate/SKILL.md" ]; then
        SKILL_FOUND="$candidate"
        break
      fi
    done

    if [ -n "$SKILL_FOUND" ]; then
      mkdir -p ".claude/skills"
      cp -r "$SKILL_FOUND" ".claude/skills/self-improving-agent"
      echo "✅ 从全局复制：$SKILL_FOUND"
    else
      echo "🟡 全局未安装，README 补充手动安装说明"
      if [ -f "README.md" ]; then
        python3 - << 'SIEOF'
readme_path = 'README.md'
with open(readme_path, encoding='utf-8') as f:
    content = f.read()
si_section = """
## Self-Improving Agent（需手动安装）

本 Team 启用了自我改进功能，但 self-improving-agent skill 未随 Team 一起生成。
请手动安装：

```bash
npx skills add openclaw/skills@self-improving-agent -a claude-code -g -y
cp -r ~/.claude/skills/self-improving-agent .claude/skills/
mkdir -p .learnings
```

"""
for marker in ['## 注意事项', '## 清理', '## 技术约束']:
    if marker in content:
        content = content.replace(marker, si_section + marker, 1)
        break
else:
    content += si_section
with open(readme_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("✅ README.md 已补充安装说明")
SIEOF
      fi
    fi
  fi

  # 6b. .learnings/ 目录
  [ -d ".learnings" ] && echo "✅ .learnings/" || {
    echo "🔧 创建 .learnings/"
    mkdir -p ".learnings"
    cat > ".learnings/README.md" << 'LRNEOF'
# .learnings/ — 自我改进记录
此目录由 self-improving-agent skill 自动管理。
LRNEOF
  }

  # 6c. CLAUDE.md @引用（多锚点，不依赖 @CONVENTIONS.md）
  if grep -q "@.claude/skills/self-improving-agent" "CLAUDE.md"; then
    echo "✅ CLAUDE.md 含 @self-improving-agent 引用"
  else
    echo "🔧 插入 @self-improving-agent 引用..."
    INSERTED=false
    for anchor in "@CONVENTIONS.md" "@USER.md" "^---"; do
      if grep -q "$anchor" "CLAUDE.md"; then
        sed -i "/$anchor/a @.claude/skills/self-improving-agent/SKILL.md" "CLAUDE.md"
        INSERTED=true
        echo "✅ 在 $anchor 后插入"
        break
      fi
    done
    $INSERTED || {
      sed -i '2a @.claude/skills/self-improving-agent/SKILL.md' "CLAUDE.md"
      echo "✅ 在第 2 行插入"
    }
  fi

  echo "=== self-improving 检查完成 ==="
}

$PASS && echo "✅ 自检通过" || echo "⚠️  存在问题，Sentinel 将进行详细审查"
```

### Step 3b：权限一致性校验（v7 必须执行）

**这一步是强制的，不可跳过。**

对每个 agent 文件，逐一检查 `allowed-tools` 是否覆盖了正文中的所有操作：

1. 读取 agent 正文，搜索所有「写入」「创建」「输出」「write」动作
   - 如果有写文件的动作但 `allowed-tools` 没有 `Write` → 自动添加 `Write`
2. 搜索所有命令执行相关的内容（pip-audit、npm audit、pytest、jest 等）
   - 如果有但 `allowed-tools` 没有 `Bash` → 自动添加 `Bash`
3. 如果修改了任何 agent 的 `allowed-tools`，在日志中记录修改

**修复后确认**：再次检查所有 agent 的权限一致性。

### Step 3c：团队 SKILL.md 生成（v7 必须执行）

**这一步是强制的，不可跳过。**

读取 `team-name.txt` 获取团队名称。检查 `.claude/skills/[团队名称]/SKILL.md` 是否已存在。

如果不存在，**必须创建**：

1. 创建目录 `.claude/skills/[团队名称]/`
2. 从 CLAUDE.md 中提取使命描述作为 overview
3. 从 README.md 中提取触发短语
4. 生成 `SKILL.md` 文件，包含以下结构：

```yaml
---
name: [团队名称]
description: |
  [从 CLAUDE.md 提取的使命描述]
  Triggers on relevant keywords from the team's domain.
  Do NOT use for: tasks outside this team's scope.
allowed-tools: Read
---
```

正文包含三个 section：Overview（使命描述）、Usage（触发方式）、Output（输出文件位置）。

如果已存在，确认内容非空，跳过。

**生成完成后确认文件存在**：检查 `.claude/skills/[团队名称]/SKILL.md` 确实被创建了。

### Step 4：写入完成标记 + 汇报

```bash
echo "done" > ../.claude/workspace/toolsmith-assembler-done.txt

AGENT_COUNT=$(ls .claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
SKILL_COUNT=$(find .claude/skills -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "🔧 Toolsmith 全部完成"
echo "   输出目录：$OUTPUT_DIR"
echo "   Agent 数量：$AGENT_COUNT"
echo "   Skill 数量：$SKILL_COUNT"
echo ""
echo "文件树："
find . -type f | sort | grep -v ".git\|workspace" | sed 's/^\.\///'
echo ""
echo "→ 交 Sentinel 审查"
```
