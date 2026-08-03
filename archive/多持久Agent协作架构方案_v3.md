# 多持久 Agent 协作架构方案 v3（终稿）

> 生成时间：2026-07-19 13:45
> 修订说明：整合 GLM 第二轮 4 条改进建议

---

## 修订日志

| 版本 | 时间 | 变更 |
|:----:|:----:|------|
| v1 | 13:03 | 初始方案 |
| v2 | 13:30 | 吸收 GLM 首轮 7 条建议 |
| **v3** | **13:45** | **解决 GLM 二轮 4 条新问题** |

### v3 对 v2 的具体改动

| # | 问题 | v2 状态 | v3 修复 |
|---|------|--------|---------|
| 1 | GLM 权限矛盾 | GLM deny 了 edit 但需要改 handoff 状态 | **改用文件名后缀状态机**，GLM 只需 write 创建新文件，edit 保留在 deny |
| 2 | 反思触发时序盲区 | 先生"反思"指令要等 13h | **恢复 cron run 手动触发 + DeepSeek 提示先生执行** |
| 3 | DeepSeek AGENTS.md 规则缺失 | 只写了"新增"但没具体内容 | **补全完整 4 条协作规则文本** |
| 4 | long-term 治理闭环 | 治理建议积压无人执行 | **DeepSeek 作为执行者，先生确认后清理** |

---

## 一、背景（同 v1）

（略，参见 v1）

---

## 二、整体架构

```
OpenClaw Gateway
│
├─ agent: main (DeepSeek V4 Flash)     ← 主助手、协作调度、治理执行者
├─ agent: glm (GLM-4-Plus)            ← 技术评审者、方案论证
├─ agent: reflector (GLM-4-Plus)      ← 后台反思引擎、记忆治理者
│
└─ ~/.openclaw/shared/                 ← 三方读写
    ├── handoff/          → 结构化消息投递
    ├── long-term/        → 长期记忆汇总
    ├── project/          → 项目方案文件
    └── reflections/      → 反思输出（仅 Reflector 写）
```

---

## 三、各 Agent 详细配置

### 3.1 DeepSeek (main) — 现有，新增协作规则

在现有 AGENTS.md 末尾追加：

```markdown
## 跨 Agent 协作规则

### 1. 触发反思
当先生表达"反思一下"、"复盘一下"、"看看最近讨论有什么问题"等意图时：
1. 写一条 handoff 消息到 handoff/ 目录，收件人为 reflector，内容包含反思范围和重点
2. 回复先生："反思指令已写入 `handoff/xxx`。先生可以在终端执行 `openclaw cron run --job reflector` 立即触发，或等待今晚 03:00 自动运行。"

### 2. 调用 GLM 的 sessions_send 规范
通过 sessions_send 向 GLM 发消息时，message 必须包含：
```markdown
## Context
<3-5 句话概括讨论背景，包含前因后果>

## Question
<具体要问的问题或要评审的内容>
```
禁止不带上下文直接抛问题。

### 3. Ping-Pong 截断处理
当与 GLM 的 ping-pong 对话因达到 15 轮上限而终止时：
1. 在最后一轮回复中标注 [PING-PONG_LIMIT_REACHED]
2. 将未讨论完的问题写入 handoff/ 目录，文件名格式 `pingpong-residue-<日期>-from-deepseek-to-glm.md`
3. 状态通过文件后缀标记（见 handoff 文件名约定规范）

### 4. Long-term 治理执行
每次被唤醒后开始对话前，检查 `reflections/long-term-maintenance/` 目录：
1. 如果有 Reflector 新输出的治理建议（比对已处理清单），向先生简要汇报
2. 先生确认后执行清理：
   - 将被标注为过时的 long-term 记录追加 `maintained_by: deepseek | maintained_date: YYYY-MM-DD`
   - 将被标注为矛盾的记录标注出矛盾双方，请先生决策
   - 执行清理后在治理建议文件中标注 `processed: true`
3. 维护已处理清单，避免重复汇报
```

### 3.2 GLM — 新创建

**核心身份**：技术评审者，方案论证伙伴。

**AGENTS.md 核心规则**：

```markdown
## 工作规则

### 1. handoff 检查
- 每次先生切换到本 Agent 开始对话前，先扫 handoff/ 目录
- 查找发给自己的、未被标记为已完成的消息（仅有 .md 文件、无对应的 .resolved.md 文件）
- 处理完成后，创建同名 .resolved.md 文件来标记完成
- 如需告知对方正在处理，可创建 .in-progress.md 文件

### 2. 与 DeepSeek 协作
- 通过 sessions_send 直接通信；通过 handoff/ 文件异步通信
- [Inter-session message] 来自 DeepSeek，不是先生本人
- 收到 DeepSeek 的 sessions_send 时，回复必须附带 Context 摘要的回执

### 3. handoff 文件名约定（只读规则）
本 Agent 遵循以下文件名状态约定：
- `<basename>.md` → status: open（待处理）
- `<basename>.in-progress.md` → 正在处理
- `<basename>.resolved.md` → 已完成
- `<basename>.rejected.md` → 拒绝处理
本 Agent 使用 write 工具创建上述标记文件，不使用 edit/apply_patch。
```

**工具权限**（修正 v2 的矛盾，采用文件名状态机）：

```json5
{
  allow: ["read", "write", "sessions_send", "sessions_list",
          "sessions_history", "memory_search", "session_status"],
  deny: ["exec", "cron", "gateway", "nodes", "edit",
         "apply_patch", "image_generate", "video_generate"],
}
```

**模型**：`zhipu/glm-4-plus`

### 3.3 Reflector — 新创建

**核心身份**：安静的观察者，事后分析引擎，长期记忆治理者。

**AGENTS.md 核心职责**：

```markdown
## 职责

### 1. 方案反思（主要）
- 读 handoff/ 和 long-term/ 中的近期记录
- 分析：矛盾点、未决问题、趋势变化
- 输出到 reflections/ 目录（按日期命名）

### 2. 长期记忆治理
- 定期扫描 long-term/ 目录
- 标注矛盾决策（同一话题上 status: active 的互斥记录）
- 标注过时内容（超过 30 天且被后续决策覆盖的记录）
- 输出治理建议到 reflections/long-term-maintenance/（注意：本 Agent 不直接修改 long-term/ 文件）

### 3. 触发方式
- **自动触发**：cron 每日 03:00 运行全量反思
- **手动触发（优先）**：先生执行 `openclaw cron run --job reflector` 立即启动
  - 启动后先检查 handoff/ 中是否有给自己的触发指令（仅有 .md 文件、无对应的 .resolved.md）
  - 如有，按指令中的范围/重点执行定向反思
  - 如无，执行全量反思
```

**工具权限**（严格限制）：

```json5
{
  allow: ["read"],
  deny: ["write", "exec", "edit", "apply_patch", "cron",
         "sessions_send", "sessions_list", "sessions_history",
         "session_status", "gateway", "nodes",
         "image_generate", "video_generate"],
}
```

Wait — Reflector 需要 write 来写入 reflections/。但 OpenClaw 的 `write` 工具不支持路径限制（它是文件级工具，不是目录级）。有两种方案：

**方案 A（推荐）**：放开 `write`，在 AGENTS.md 的约束中写明"仅限 reflections/ 和 handoff/ 目录"

```json5
{
  allow: ["read", "write"],
  deny: [/* ... 其余全部 deny */],
}
```

AGENTS.md 追加：
```markdown
### write 工具使用约束
- 允许写入 `reflections/` 目录（反思输出）
- 允许写入 `handoff/` 目录（接受反思指令时标记已处理）
- 禁止写入 `long-term/`、`project/`、以及其他 agent 的 workspace 目录
```

**方案 B**：Reflector 通过 handoff 传递治理建议，由 DeepSeek 或先生写入 reflections/。但太绕了不实用。

采用方案 A。

**模型**：`zhipu/glm-4-plus`

---

## 四、跨 Agent 协作协议

### 4.1 handoff 文件名状态机（核心机制）

v3 改用**文件名后缀**来追踪消息状态，不再修改文件内部字段：

| 状态 | 文件名模式 | 创建者 |
|------|-----------|--------|
| open（待处理） | `xxx-from-A-to-B.md` | 发送方 |
| in-progress（处理中） | `xxx-from-A-to-B.in-progress.md` | 接收方（可选） |
| resolved（已完成） | `xxx-from-A-to-B.resolved.md` | 接收方 |
| rejected（拒绝） | `xxx-from-A-to-B.rejected.md` | 接收方（可选） |

**检查规则**：接收方扫描 handoff/ 时，查找发给自己的文件：
- 有 `xxx-to-glm.md` 但无 `xxx-to-glm.resolved.md` → 待处理
- 有 `xxx-to-glm.in-progress.md` → 对方正在处理中（继续等待或检查）
- 有 `xxx-to-glm.resolved.md` → 已处理

**优点**：
- 接收方只需 `write`（创建新文件），不需 `edit`/`apply_patch`
- 文件级操作天然原子性，不会出现"改状态到一半"的竞态
- 保留完整的处理日志（所有标记文件共存，可追溯时间线）

### 4.2 直接通信（sessions_send）

```python
# DeepSeek → GLM
sessions_send(
    sessionKey="agent:glm:main",
    message="""## Context
<3-5 句话概括讨论背景，包含前因后果>

## Question
<具体要问的问题或要评审的内容>
""",
    timeoutSeconds=30
)
```

- 发送方必须在 message 中附带 Context 摘要
- ping-pong 上限 15 轮，任一方可用 `REPLY_SKIP` 提前终止
- 因上限截断时，发送方自动写 handoff 归档剩余讨论

### 4.3 反思触发完整链路

```
先生："反思一下最近的讨论"
  │
  ▼
DeepSeek 理解意图：
  1. 写 handoff/xxx-trigger-reflect-from-deepseek.md
     （内容：反思范围、重点关注事项）
  2. 回复先生：写入了 handoff 定向反思指令
                建议执行：openclaw cron run --job reflector 立即触发
                或等待今晚 03:00 自动运行
  │
  ▼ [先生或执行 cron run，或等待]
  │
Reflector 启动：
  1. 检查 handoff/ 中是否有给自己的定向指令
  2. 有 → 按指令范围执行定向反思
  3. 无 → 执行全量反思
  4. 输出到 reflections/<日期>.md
  5. 标记 handoff 指令为已处理（创建 .resolved.md）
```

### 4.4 长期记忆治理闭环

```
[定期]
  │
  ▼
Reflector 扫描 long-term/：
  - 识别矛盾决策、过期记录
  - 输出治理建议到 reflections/long-term-maintenance/<日期>.md
  │
  ▼ [DeepSeek 下次被唤醒时]
  │
DeepSeek 检查治理建议：
  - 读取 reflections/long-term-maintenance/ 中新文件
  - 向先生简要汇报
  │
  ▼ [先生确认]
  │
先生确认后 DeepSeek 执行：
  - 在过时记录中追加 maintained_by 和 maintained_date
  - 矛盾记录请先生决策后，按决策执行
  - 在治理建议文件中标注 processed
```

---

## 五、openclaw.json 配置

```json5
{
  agents: {
    defaults: {
      workspace: "~/.openclaw/workspace",
      model: "deepseek/deepseek-v4-flash",
    },
    list: [
      { id: "main", default: true },
      {
        id: "glm",
        workspace: "~/.openclaw/workspace-glm",
        model: "zhipu/glm-4-plus",
        agentDir: "~/.openclaw/agents/glm/agent",
        tools: {
          allow: ["read", "write", "sessions_send", "sessions_list",
                  "sessions_history", "memory_search", "session_status"],
          deny: ["exec", "cron", "gateway", "nodes", "edit",
                 "apply_patch", "image_generate", "video_generate"],
        },
      },
      {
        id: "reflector",
        workspace: "~/.openclaw/workspace-reflector",
        model: "zhipu/glm-4-plus",
        agentDir: "~/.openclaw/agents/reflector/agent",
        tools: {
          allow: ["read", "write"],
          deny: ["exec", "edit", "apply_patch", "cron", "sessions_send",
                 "sessions_list", "sessions_history", "session_status",
                 "gateway", "nodes", "image_generate", "video_generate"],
        },
        heartbeat: {
          enabled: false,
        },
      },
    ],
  },

  tools: {
    agentToAgent: {
      enabled: true,
      allow: ["main", "glm"],
    },
  },

  session: {
    agentToAgent: {
      maxPingPongTurns: 15,
    },
  },
}
```

**Reflector 的 cron job 定义**（需注册）：

```bash
openclaw cron add \
  --name reflector \
  --schedule "0 3 * * *" \
  --tz Asia/Shanghai \
  --agent reflector \
  --mode agentTurn \
  --message "执行定期反思：扫描 handoff/ 和 long-term/ 最近的记录，输出分析报告到 reflections/ 目录。同时检查 long-term/ 中的矛盾决策和过时内容，输出治理建议。"
```

然后先生按需手动触发：
```bash
openclaw cron run --job reflector --mode force
```

---

## 六、实施步骤

| # | 操作 | 关键细节 | 耗时 |
|---|------|---------|:----:|
| 1 | 创建 shared/ 目录 | `mkdir -p ~/.openclaw/shared/{handoff,long-term,project,reflections,reflections/long-term-maintenance}` | 1 分钟 |
| 2 | 创建 agent workspace | `mkdir -p ~/.openclaw/{workspace-glm,workspace-reflector}` | 1 分钟 |
| 3 | 三个 workspace 加软连接 | `ln -s ~/.openclaw/shared/* ~/.openclaw/workspace-glm/`（同理 main、reflector） | 1 分钟 |
| 4 | 配置智谱 API Key | `openclaw config set ZHIPU_API_KEY=你的key` | 1 分钟 |
| 5 | 修改 openclaw.json | 加 glm、reflector、agentToAgent、session 配置 | 5 分钟 |
| 6 | 注册 Reflector cron job | `openclaw cron add ...` | 1 分钟 |
| 7 | 创建 GLM 核心文件 | AGENTS.md、SOUL.md、USER.md、IDENTITY.md | 5 分钟 |
| 8 | 创建 Reflector 核心文件 | AGENTS.md、SOUL.md | 3 分钟 |
| 9 | DeepSeek AGENTS.md 追加协作规则 | 追加上述第 3.1 节 4 条规则 | 2 分钟 |
| 10 | Gateway 重启 | `openclaw gateway restart` | 30 秒 |
| 11 | 验证通信 | 切到 GLM 对话 → 能正常回复；DeepSeek sessions_send → GLM 收到 | 3 分钟 |
| 12 | 验证 handoff 状态机 | DeepSeek 写 handoff → 切到 GLM 能看到 → 处理后标记 resolved | 3 分钟 |

**总计约 25 分钟。**

---

## 七、风险与应对

| 风险 | 概率 | 应对 |
|------|:----:|------|
| GLM API 连接失败 | 中 | `openclaw status -v` 验证；备选 deepseek 模型 |
| 跨 agent 消息权限不足 | 低 | 逐步放开，从严到宽 |
| Reflector cron 未注册导致不触发 | 低 | 手动 `cron run` 兜底 |
| handoff 无心跳时 GLM 启动延迟 | 低 | 启动时扫 handoff 兜底 |
| long-term 条目混乱 | 中 | Reflector 定期治理 + DeepSeek 执行 + 先生审查 |
| 文件名后缀状态机有人写大写下划线不一致 | 低 | 规范文件名格式，统一用小写 + 英文句点 + 英文后缀 |
| Gateway 重启失败 | 低 | 备份当前 openclaw.json 再修改 |
