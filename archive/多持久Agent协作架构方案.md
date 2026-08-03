# 多持久 Agent 协作架构方案

> 生成时间：2026-07-19 13:03
> 背景：先生、DeepSeek（OpenClaw 主代理）、GLM 三方协作研究项目方案，反思代理缺位的问题

---

## 一、背景：为什么需要这个方案

### 问题现状

当前先生同时使用两个 AI 进行项目方案研究：

| 角色 | 运行位置 | 特点 |
|------|---------|------|
| DeepSeek V4 Flash | OpenClaw WebChat（服务器端） | 持久，但无法访问 GLM 的对话 |
| GLM（你） | Cherry Studio（本地桌面端） | 每次任务结束后对话消失 |
| 先生（人类） | 在两个环境间切换 | 需要在中间传递信息 |

### 核心痛点

1. **信息孤岛**：DeepSeek 看不到先生与 GLM 的讨论，GLM 也看不到 DeepSeek 与先生的讨论
2. **GLM 无记忆**：每次打开 Cherry Studio，之前的对话和决策经验无法保留
3. **反思缺失**：需要一个"反思代理"来分析三方的讨论记录，提炼洞察、发现矛盾、追踪未决问题——但目前没有任何数据可读
4. **先生做中转**：涉及重要项目时，先生需要人工在 DeepSeek 和 GLM 之间传话

### 方案目标

将 GLM 从一个临时的桌面端助手，升级为 OpenClaw 中的一个**持久代理**，与 DeepSeek 并列运行。同时创建一个**反思代理**作为后台分析引擎。三者通过共享文件系统进行结构化协作。

---

## 二、整体架构

```
OpenClaw Gateway（服务器端，云上持久运行）
│
├─ agent: main (DeepSeek)     ← 当前聊天
│   model:  deepseek/deepseek-v4-flash
│   workspace: ~/.openclaw/workspace
│   session: 持久在线
│
├─ agent: glm (新创建)        ← 技术评审者
│   model:  zhipu/glm-4-plus
│   workspace: ~/.openclaw/workspace-glm（独立新目录）
│   session: 持久在线
│
├─ agent: reflector (新创建)  ← 后台反思引擎
│   model:  zhipu/glm-4-flash（或 deepseek-v3，经济模型）
│   workspace: ~/.openclaw/workspace-reflector（独立新目录）
│   触发方式：cron 定时 / 先生按需
│
└─ ~/.openclaw/shared/        ← 共享区域（三方读写）
    ├── handoff/              ← 结构化消息投递
    ├── long-term/            ← 长期记忆汇总
    ├── project/              ← 项目方案文件
    └── reflections/          ← 反思输出（仅反思代理写入）
```

### 通信链路

```
先生 → WebChat → DeepSeek     ← 直接对话
先生 → WebChat → GLM          ← 直接对话（先生切换聊天目标即可）
DeepSeek ↔ GLM                ← sessions_send 直接通信 + handoff/ 文件异步传递
反思代理                        ← 读取三方文件 → 输出分析报告
```

---

## 三、各 Agent 详细配置

### Agent 1：DeepSeek（main）— 现有，不动

- 当前 workspace 不变
- 在 workspace 下新增软连接指向共享区域

```bash
ln -s ~/.openclaw/shared/handoff    ~/.openclaw/workspace/handoff
ln -s ~/.openclaw/shared/long-term  ~/.openclaw/workspace/long-term
ln -s ~/.openclaw/shared/project    ~/.openclaw/workspace/project
```

### Agent 2：GLM（新创建）

**核心身份**：技术评审者，逻辑推演与方案论证伙伴。

**AGENTS.md 核心内容**：
- 你是先生的技术评审伙伴，擅长逻辑推演、方案评审、风险发现
- 通过 `handoff/` 目录和 sessions_send 与 DeepSeek 协作
- 读到的 `[Inter-session message]` 来自 DeepSeek，不是先生本人
- 先生在 WebChat 切换聊天目标时与你直接对话

**工具权限**：
```
允许：read, write（仅限于 handoff/ 和 long-term/）, sessions_send, sessions_history, memory_search
拒绝：exec, cron, gateway, nodes, image_generate, video_generate
```

**模型**：`zhipu/glm-4-plus`

**workspace 结构**：
```
~/.openclaw/workspace-glm/
├── AGENTS.md
├── SOUL.md
├── USER.md（同 DeepSeek 的先生画像）
├── IDENTITY.md
├── TOOLS.md
├── HEARTBEAT.md（可选，初期可关）
├── handoff -> ~/.openclaw/shared/handoff/
├── long-term -> ~/.openclaw/shared/long-term/
└── project -> ~/.openclaw/shared/project/
```

### Agent 3：Reflector（新创建）

**核心身份**：安静的观察者，事后分析引擎。

**AGENTS.md 核心内容**：
- 你是协作反思代理，不在任何聊天界面中直接发言
- 通过 cron 定时触发或先生手动 `cron run` 触发
- 工作流程：读 handoff/ 和 long-term/ → 分析矛盾/趋势/未决问题 → 写反思到 reflections/

**工具权限**（严格限制）：
```
允许：read（全局），write（仅限 shared/reflections/ 子目录）
拒绝：exec, cron, gateway, nodes, sessions_send, edit, apply_patch
```

**模型**：`zhipu/glm-4-flash`（成本优先）

**触发方式**：
- cron 每日 03:00 自动运行一次
- 先生可随时通过 `cron run --jobId xxx` 手动触发
- 先生对话中直接说"反思一下最近的讨论"触发

---

## 四、跨 Agent 协作协议

### 4.1 直接通信（sessions_send）

DeepSeek 和 GLM 之间可以直接发消息：

```
sessions_send(
  sessionKey="agent:glm:main",
  message="请评审附件中的方案，关注风险点",
  timeoutSeconds=30
)
```

- 格式固定为 `agent:<目标agentId>:main`
- 支持最多 15 轮 ping-pong 来回对话（可配置）
- 目标 agent 回复 `REPLY_SKIP` 可提前终止

### 4.2 异步通信（handoff/ 文件）

适合结构化地给另一个 agent 留消息：

```markdown
# handoff/2026-07-19-1300-from-deepseek-to-glm.md
from: deepseek
to: glm
type: 方案评审请求
status: open
priority: high

## 内容

我最近和先生讨论了反思代理的架构...
需要你从 GLM 角度评审以下几个问题：
1. 信息隔离方案是否充分？
2. 反思代理的 read-only 权限是否合理？
...
```

消息规范：
- `status: open` → 对方处理中
- `status: resolved` → 对方已完成
- `status: rejected` → 认为不需要处理

每个 agent 通过 heartbeat 或 cron 定期检查 handoff/ 中是否有给自己的 `status: open` 消息。

### 4.3 长期记忆共享

任何 agent 在讨论中产出的有价值内容，写入 `long-term/`，格式带签名：

```markdown
# long-term/project/方案决策-2026-07-19.md
author: deepseek  |  review: glm  |  date: 2026-07-19

## 决策：采用独立 workspace + 共享手递目录架构
- 理由：防止 agent 间信息污染
- 替代方案被否决：统一 workspace（污染风险高）
- 影响：后续所有 agent 均需遵循此模式
```

---

## 五、openclaw.json 配置改动

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
          allow: ["read", "write", "sessions_send", "sessions_history", "memory_search"],
          deny: ["exec", "cron", "gateway", "nodes", "image_generate", "video_generate"],
        },
      },
      {
        id: "reflector",
        workspace: "~/.openclaw/workspace-reflector",
        model: "zhipu/glm-4-flash",
        agentDir: "~/.openclaw/agents/reflector/agent",
        tools: {
          allow: ["read", "write"],
          deny: ["exec", "edit", "apply_patch", "cron", "sessions_send",
                 "sessions_history", "gateway", "nodes"],
        },
      },
    ],
  },

  // 必须开启跨 agent 通信
  tools: {
    agentToAgent: {
      enabled: true,
      allow: ["main", "glm"],  // 只允许 DeepSeek 和 GLM 互相通信
    },
  },

  // 增加 ping-pong 来回轮次上限
  session: {
    agentToAgent: {
      maxPingPongTurns: 15,  // 默认 5，范围 0-20
    },
  },
}
```

---

## 六、实施步骤

| # | 操作 | 预计耗时 |
|---|------|:--------:|
| 1 | 创建 `~/.openclaw/shared/` 目录及 handoff/long-term/project/reflections 四个子目录 | 1 分钟 |
| 2 | 创建 `workspace-glm/` 和 `workspace-reflector/` 目录 | 1 分钟 |
| 3 | DeepSeek 的 workspace 下加软连接指向共享目录 | 1 分钟 |
| 4 | 配置智谱 API 环境变量：`ZHIPU_API_KEY` | 1 分钟 |
| 5 | 修改 `openclaw.json`：加 glm、reflector 两个 agent + agentToAgent 配置 | 5 分钟 |
| 6 | Gateway 重启 | 30 秒 |
| 7 | 验证：先生切换 WebChat 目标到 glm 对话，确认能收到 | 2 分钟 |
| 8 | 验证：从 DeepSeek 发一条 messages_send 给 GLM，确认能送达 | 2 分钟 |
| 9 | 创建 GLM 的核心身份文件（AGENTS.md、SOUL.md、USER.md、IDENTITY.md） | 5 分钟 |
| 10 | 创建 Reflector 的核心身份文件 | 3 分钟 |

**总计约 20-25 分钟。**

---

## 七、已知风险与应对

| 风险 | 概率 | 应对 |
|------|:----:|------|
| GLM API 连接失败 | 中 | 先配好 Key，gateway 日志 `/status` 可查 |
| 跨 agent 消息因权限不足被拒绝 | 低 | 逐步扩大工具权限，从严到宽 |
| 反思代理触发频率过高浪费 Token | 低 | 先用手动触发，稳定后再加 cron |
| 共享区域文件冲突 | 低 | 文件名带作者前缀 + 时间戳，互不覆盖 |
| gateway 重启失败 | 低 | 备份当前 openclaw.json 后再修改 |
