# 多持久 Agent 协作架构方案 v2（修订版）

> 生成时间：2026-07-19 13:30
> 修订说明：基于 GLM 首轮评审的 7 条建议调整

---

## 修订摘要

| # | 问题 | 原方案 | 修订后 |
|---|------|--------|--------|
| 1 | Reflector 模型偏弱 | glm-4-flash | **glm-4-plus**（反思认知密度高，频率低所以成本影响小） |
| 2 | handoff 轮询空白 | 未定义 | **启动时先扫 handoff/** 写进 AGENTS.md；cron 每 30 分钟检查一次 open 消息 |
| 3 | 反思触发链路空缺 | 未打通 | **DeepSeek 作为入口**：先生跟 DeepSeek 说"反思"→ DeepSeek 写 handoff → Reflector 读取执行 |
| 4 | ping-pong 截断无 fallback | 15 轮硬截断 | **补截断 handoff**：达到上限时自动写一条 handoff 记录未完成状态（+ 保留 15 轮上限） |
| 5 | long-term 语义冲突 | 仅文件层防冲突 | **Reflector 增加治理职责**：定期扫描 long-term/，标注矛盾决策和过时内容 |
| 6 | 跨 Agent 上下文缺失 | sessions_send 无 context | **强制 context 摘要模板**：规范写入双方 AGENTS.md |
| 7 | 扩展性 | 未提及 | **记录在案**，3 个 Agent 内无需处理 |

---

## 一、背景（同 v1）

当前先生同时使用 DeepSeek（OpenClaw WebChat）和 GLM（Cherry Studio 桌面端）进行项目方案研究。核心痛点：

1. **信息孤岛**：DeepSeek 看不到先生与 GLM 的讨论，反之亦然
2. **GLM 无记忆**：每次打开 Cherry Studio，之前的决策和经验无法保留
3. **反思缺位**：需要一个反思代理来分析三方讨论记录，但没有任何数据可读
4. **先生做中转**：需要人工在 DeepSeek 和 GLM 之间传话

**方案目标**：将 GLM 从临时桌面端助手升级为 OpenClaw 中的持久代理，同时创建反思代理作为后台分析引擎。

---

## 二、整体架构（结构不变，内容精炼）

```
OpenClaw Gateway
│
├─ agent: main (DeepSeek V4 Flash)     ← 主助手
├─ agent: glm (GLM-4-Plus)            ← 技术评审者
├─ agent: reflector (GLM-4-Plus)      ← 后台反思引擎
│
└─ ~/.openclaw/shared/                 ← 三方读写
    ├── handoff/          → 结构化消息投递
    ├── long-term/        → 长期记忆汇总
    ├── project/          → 项目方案文件
    └── reflections/      → 反思输出（仅 Reflector 写）
```

### 通信链路

```
先生 → WebChat → DeepSeek              ← 直接对话
先生 → WebChat → GLM                   ← 直接对话（切换聊天目标）
DeepSeek ↔ GLM 通过 sessions_send+handoff ← 双向协作
Reflector 读取 handoff + long-term → 输出反思报告
```

---

## 三、各 Agent 详细配置

### 3.1 DeepSeek (main) — 现有，不动

- 当前 workspace 不变
- 新增软连接指向共享区域
- AGENTS.md 中新增协作规则条目

### 3.2 GLM — 新创建

**核心身份**：技术评审者，逻辑推演与方案论证伙伴。

**AGENTS.md 核心规则**：

```markdown
## 工作规则

### 1. handoff 检查
- 每次先生切换到本 Agent 开始对话前，先扫 handoff/ 目录
- 查找发给自己的 status: open 消息并处理
- 处理完成后将状态改为 resolved

### 2. 与 DeepSeek 协作
- 通过 sessions_send 直接通信；通过 handoff/ 文件异步通信
- [Inter-session message] 来自 DeepSeek，不是先生本人
```

**工具权限**：
```
allow: read, write（限于 handoff/ 和 long-term/）, sessions_send, sessions_list, sessions_history, memory_search
deny: exec, cron, gateway, nodes, image_generate, video_generate, edit, apply_patch
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
- 输出到 reflections/ 目录

### 2. 长期记忆治理
- 定期扫描 long-term/ 目录
- 标注矛盾决策（如"A 方案"和"B 方案"同时存在且互斥）
- 标注过时内容（超过 30 天且被后续决策覆盖的记录）
- 输出清理建议到 reflections/long-term-maintenance/

### 3. 触发方式
- cron 每日 03:00 自动运行全量反思
- 先生按需「手动触发」：先生跟 DeepSeek 说"反思一下"→ DeepSeek 写 handoff 消息
- Reflector 检查 handoff/ 时发现有新指令 → 执行
```

**工具权限（严格限制）**：
```
allow: read（全局）, write（仅限 shared/reflections/ 子目录）
deny: exec, edit, apply_patch, cron, sessions_send, sessions_list, sessions_history, gateway, nodes
```

**模型**：`zhipu/glm-4-plus`（反思认知密度高，频率低，成本影响小）

---

## 四、跨 Agent 协作协议

### 4.1 直接通信（sessions_send）

```python
# 示例：DeepSeek 发给 GLM
sessions_send(
    sessionKey="agent:glm:main",
    message="""## Context
<3-5句话概括讨论背景，包含前因后果>

## Question
<具体要问的问题、要评审的内容>
""",
    timeoutSeconds=30
)
```
- 目标 session key 格式：`agent:<agentId>:main`
- **发送时必须附带 Context 摘要**（双方的 AGENTS.md 中的强制规则）
- 默认 ping-pong 上限 15 轮，双方可随时发 `REPLY_SKIP` 提前终止

### 4.2 异步通信（handoff/ 文件）

```markdown
# handoff/2026-07-19-1300-from-deepseek-to-glm.md
from: deepseek
to: glm
type: 方案评审请求
status: open
priority: medium
context: <简要背景说明>

## 内容
<具体要求>
```

**消息状态机**：
- `open` → 对方待处理
- `in-progress` → 对方正在处理
- `resolved` → 对方已完成
- `rejected` → 认为不需要处理

**轮询机制**：
- **启动时**：GLM 被切到对话时，先扫 handoff/ 查 open 消息（强制，写入 AGENTS.md）
- **运行时**：cron 每 30 分钟检查一次 handoff/（可选，初期建议开）
- **Fallback**：即使心跳关闭，启动时检查确保不丢消息

### 4.3 Ping-Pong 截断 Fallback

当 sessions_send 的 ping-pong 因达到上限（15 轮）而自动终止时，**DeepSeek 或 GLM 应在最后一轮回复中附上未完成状态**：

```markdown
[PING-PONG_LIMIT_REACHED]
对话因轮次上限截断，未讨论完的问题已归档至：
handoff/2026-07-19-pingpong-residue-from-deepseek-to-glm.md
```

### 4.4 长期记忆治理

**写入规范**：
每条 long-term 记录必须包含：
- `author: <agentId>`
- `date: YYYY-MM-DD`
- `status: active | superseded | draft`
- （可选）`supersedes: <引用旧记录ID>`

**治理机制**（Reflector 职责）：
- 每周扫描 long-term/，识别：
  - 同一话题上 status: active 的矛盾记录（如两条互斥的决策）
  - 超过 30 天的 status: active 记录，评估是否需要归档
  - 建议输出到 `reflections/long-term-maintenance/`

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
          deny: ["exec", "cron", "gateway", "nodes",
                 "image_generate", "video_generate", "edit", "apply_patch"],
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
          enabled: false,  // 不在聊天界面出现
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

---

## 六、实施步骤

| # | 操作 | 关键细节 | 耗时 |
|---|------|---------|:----:|
| 1 | 创建 shared/ 目录 | `mkdir -p ~/.openclaw/shared/{handoff,long-term,project,reflections}` | 1 分钟 |
| 2 | 创建 workspace-glm/ 和 workspace-reflector/ | `mkdir -p ~/.openclaw/{workspace-glm,workspace-reflector}` | 1 分钟 |
| 3 | DeepSeek workspace 加软连接 | `ln -s ~/.openclaw/shared/* ~/.openclaw/workspace/` | 1 分钟 |
| 4 | GLM workspace 加软连接 | 同上 | 1 分钟 |
| 5 | Reflector workspace 加软连接 | 同上 | 1 分钟 |
| 6 | 配置智谱 API Key | `openclaw config set ZHIPU_API_KEY=xxx` | 1 分钟 |
| 7 | 修改 openclaw.json | 加 glm、reflector、agentToAgent、session 配置 | 5 分钟 |
| 8 | 创建 GLM 核心文件 | AGENTS.md、SOUL.md、USER.md、IDENTITY.md | 5 分钟 |
| 9 | 创建 Reflector 核心文件 | AGENTS.md、SOUL.md | 3 分钟 |
| 10 | Gateway 重启 | `openclaw gateway restart` | 30 秒 |
| 11 | 验证通信 | 先生切到 GLM → 能对话；DeepSeek 发 sessions_send → GLM 收到 | 3 分钟 |

**总计约 25 分钟。**

---

## 七、风险与应对

| 风险 | 概率 | 应对 |
|------|:----:|------|
| GLM API 连接失败 | 中 | 先用 `openclaw status -v` 验证；备选 deepseek 模型 |
| 跨 agent 消息权限不足 | 低 | 逐步放开，从严到宽 |
| Reflector 触发频率浪费 Token | 低 | 先用每日 1 次 cron，稳定后再调 |
| handoff 无心跳时消息延迟 | 低 | 启动时扫 handoff 兜底 |
| long-term 条目混乱 | 中 | Reflector 定期治理，先生可人工审查 |
| Gateway 重启失败 | 低 | 备份当前 openclaw.json 再修改 |
