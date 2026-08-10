# OpenClaw「代理（Agent）」学习计划书

> 整理日期：2026-08-10
> 内容来源：OpenClaw 官方文档中文站（docs.openclaw.ai/zh-CN，翻译基于 2026-07-26 版）
> 爬取页面：concepts/architecture · concepts/agent · concepts/agent-loop · concepts/system-prompt · concepts/memory · concepts/session · concepts/multi-agent
> 适用对象：OpenClaw 用户（想彻底理解"代理"是什么、如何运作、如何配置）
> 学习方式：边读边在真实环境验证（本文所有练习都可在你现有系统上完成）

---

## 0. 学习目标

学完后你将能够：

1. **讲清楚**：Agent（智能体/代理）在 OpenClaw 中是什么、由哪些部分组成
2. **解释机制**：一条消息进来后，Agent 内部经过哪些步骤变成回复
3. **看懂配置**：`agents.defaults`、`agents.entries`、引导文件、模型引用等配置含义
4. **管理会话与记忆**：理解会话路由、重置策略、记忆文件分工
5. **设计多智能体**：知道何时、如何在一个 Gateway 里跑多个隔离的 Agent
6. **动手实操**：用命令和界面检查自己系统的运行状态

> 术语说明：官方中文文档将 Agent 译为"智能体"，你习惯叫"代理/瑶光"，同一概念。

---

## 1. 学习路线总览（约 5~6 小时）

| 阶段 | 主题 | 官方文档 | 建议时长 |
|:----:|------|---------|:--------:|
| 一 | 宏观架构：Gateway 与 Agent 的关系 | concepts/architecture + concepts/agent | 45 分钟 |
| 二 | Agent 运行时：工作区与引导文件 | concepts/agent | 45 分钟 |
| 三 | Agent loop：一次运行的生命周期 | concepts/agent-loop | 60 分钟 |
| 四 | 系统提示词：Agent 的"大脑输入" | concepts/system-prompt | 45 分钟 |
| 五 | 记忆系统：Agent 如何跨会话记住 | concepts/memory | 60 分钟 |
| 六 | 会话管理：消息如何路由与隔离 | concepts/session | 45 分钟 |
| 七 | 多智能体：一个 Gateway 多个 Agent | concepts/multi-agent | 60 分钟 |
| 八 | 实战验收 | 全部 | 30 分钟 |

---

## 2. 阶段一：宏观架构——Gateway 与 Agent（45 分钟）

**官方文档**
- 《Gateway 网关架构》：https://docs.openclaw.ai/zh-CN/concepts/architecture
- 《Agent 运行时》：https://docs.openclaw.ai/zh-CN/concepts/agent

**核心知识点**

1. **Gateway 是常驻守护进程**：所有消息通道（WhatsApp/Telegram/Slack/Discord/WebChat/飞书）都连到它；它是每台主机唯一入口
2. **控制平面客户端**（macOS 应用、CLI、Web UI）通过 WebSocket 连接 Gateway（默认 `127.0.0.1:18789`）
3. **节点**（手机/桌面设备）也用 WebSocket 连接，但声明 `role: node`，可提供摄像头、屏幕录制、定位等能力
4. **Agent 是完整的"人格作用域"**：每个 Agent 有自己的工作区、认证配置、模型注册表、会话存储
5. **Agent 由 OpenClaw 提供嵌入式运行时**：内置 Agent loop、工具连接、提示词组装——不是外包给外部 harness
6. 关键路径：
   - 配置：`~/.openclaw/openclaw.json`
   - 默认工作区：`~/.openclaw/workspace`
   - 会话存储：`~/.openclaw/agents/<agentId>/agent/openclaw-agent.sqlite`
   - 归档转录：`~/.openclaw/agents/<agentId>/sessions/`

**动手练习**
```bash
openclaw status            # 看 Gateway 状态、会话存储路径、最近活动
openclaw agents list       # 看当前配置的 Agent（你应该看到 main）
ls ~/.openclaw/workspace   # 看工作区里的引导文件
```

**自测**：Gateway 和 Agent 的关系？一句话回答——Gateway 是"容器/身体"，Agent 是"人格/大脑"。

---

## 3. 阶段二：Agent 运行时——工作区与引导文件（45 分钟）

**官方文档**：《Agent 运行时》https://docs.openclaw.ai/zh-CN/concepts/agent

**核心知识点**

1. **工作区是 Agent 的唯一工作目录（cwd）**：`agents.defaults.workspace` 或每个 Agent 单独指定
2. **引导文件**（新会话第一轮注入系统提示词"项目上下文"）：

| 文件 | 用途 |
|------|------|
| `AGENTS.md` | 操作说明 + 记忆（行为总纲） |
| `SOUL.md` | 人格、边界、语气 |
| `TOOLS.md` | 工具使用约定 |
| `IDENTITY.md` | 名字/风格/表情符号 |
| `USER.md` | 用户资料 + 称呼 |
| `HEARTBEAT.md` | Heartbeat 专用说明 |
| `BOOTSTRAP.md` | 一次性首次运行仪式（完成后删除） |
| `MEMORY.md` | 根级长期记忆（存在才注入） |

3. **注入规则**：空文件跳过；大文件裁剪（单文件上限 20000 字符、总计 60000 字符，配置 `agents.defaults.bootstrapMaxChars`）；缺失文件注入"缺失标记"
4. **Skills 加载优先级**（高→低）：工作区 `<workspace>/skills` → 项目 `.agents/skills` → 个人 `~/.agents/skills` → 托管 `~/.openclaw/skills` → 内置 → 额外目录
5. **内置工具始终可用**：read/exec/edit/write 等核心工具受工具策略约束；`TOOLS.md` 不决定工具是否存在，只指导怎么用
6. **模型引用格式**：`provider/model`（如 `deepseek/deepseek-v4-flash`）；模型 ID 含 `/` 时必须带提供商前缀
7. **最小配置**：`agents.defaults.workspace` 必须设置

**动手练习**
```bash
# 看你的工作区引导文件（对照文档的表格逐一认识）
head -20 ~/.openclaw/workspace/SOUL.md
head -20 ~/.openclaw/workspace/USER.md
ls ~/.openclaw/workspace/skills/   # 看 Skills 目录
# 在对话里输入 /context list 或 /context detail 查看实际注入内容
```

**自测**：为什么 MEMORY.md 建议保持精简？——因为超过预算会被截断注入副本（磁盘文件完整，模型只看到截断版）；详细内容应放 `memory/*.md` 按需检索。

---

## 4. 阶段三：Agent loop——一次运行的生命周期（60 分钟）

**官方文档**：《Agent loop》https://docs.openclaw.ai/zh-CN/concepts/agent-loop

**核心知识点**

1. **定义**：Agent loop 是按会话串行执行的运行流程，把一条消息变成操作和回复：接收 → 上下文组装 → 模型推理 → 工具执行 → 流式传输 → 持久化
2. **入口**：Gateway RPC（`agent` / `agent.wait`）或 CLI（`openclaw agent`）
3. **运行顺序（5 步）**：
   1. `agent` RPC 验证参数、解析会话、立即返回 `{runId, acceptedAt}`
   2. `agentCommand` 解析模型/思考级别、加载 Skills 快照、调用 `runEmbeddedAgent`
   3. `runEmbeddedAgent` 排队执行、构建会话、订阅事件、流式输出、强制执行超时
   4. 事件桥接：工具事件→`stream:"tool"`，助手增量→`stream:"assistant"`，生命周期→`stream:"lifecycle"`
   5. `agent.wait` 等待结束事件，返回状态
4. **排队与并发**：按会话键串行 + 可选全局通道，防止工具/会话竞态；会话文件上有进程感知的写入锁（默认等 60 秒）
5. **提示词组装**：基础提示词 + Skills 提示词 + 引导上下文 + 按运行覆盖项；强制模型限制和压缩预留 token
6. **两套 Hook 系统**：
   - 内部钩子：`agent:bootstrap`（引导文件构建）、命令钩子
   - 插件钩子：`before_model_resolve`、`before_prompt_build`、`before_agent_reply`、`agent_end`、`before/after_tool_call`、`before/after_compaction`、`session_start/end`、`gateway_start/stop`、`message_received/sending/sent` 等
7. **流式传输**：助手增量以 `assistant` 事件流式发出；推理流可独立或阻塞回复
8. **工具执行**：工具开始/更新/结束事件在 `tool` 流发出；结果按大小和图像载荷清理
9. **回复成形**：助手文本 + 可选推理内容 + 工具摘要；过滤 `NO_REPLY` 静默 token
10. **压缩与重试**：自动压缩发出 `compaction` 事件，可触发重试（内存缓冲区和工具摘要重置防重复）
11. **超时体系**（重要）：

| 超时 | 默认值 | 说明 |
|------|--------|------|
| `agent.wait` | 30s | 仅等待，不停止运行 |
| Agent 运行时 | 172800s（48h） | `agents.defaults.timeoutSeconds`，0=无限 |
| 模型空闲 | 云端 120s / 自托管 300s | 无响应分块则中止 |
| 提供商 HTTP | `models.providers.<id>.timeoutSeconds` | 连接+响应+流看门狗 |

12. **卡住会话诊断**：`session.long_running`（活跃但慢）→ `session.stalled`（无进度）→ `session.stuck`（可恢复的陈旧记录）；中止阈值 ≥5 分钟且为警告阈值的 3 倍

**动手练习**
- 在对话里输入 `/status` 看当前会话的模型、上下文用量
- 观察一条消息的回复过程：工具调用开始→流式输出→结束（Control UI 可看到事件流）
- `openclaw agent "你好"` 试试 CLI 入口

**自测**：一条消息进来后按顺序经过哪 5 步？——RPC 验证/解析 → agentCommand 执行轮次 → runEmbeddedAgent 排队运行 → 事件桥接流式 → agent.wait 等待结束。

---

## 5. 阶段四：系统提示词——Agent 的"大脑输入"（45 分钟）

**官方文档**：《系统提示词》https://docs.openclaw.ai/zh-CN/concepts/system-prompt

**核心知识点**

1. **没有运行时默认提示词**：每次运行都按三层组装（渲染器 + 配置解析 + 运行时适配器收集实时信息）
2. **提示词固定结构**（从抓取内容提炼）：
   - 工具（真实来源提醒 + 使用指导）
   - 执行倾向（处理可执行请求、持续到完成、失败恢复、验证后结束）
   - 安全护栏（防止权力追求/绕过监督——但属于建议，硬性执行靠工具策略/审批/沙箱）
   - Skills 列表（`<available_skills>` 含路径和 sha256 版本标记）
   - OpenClaw 控制（gateway 工具优先，不虚构 CLI 命令）
   - 工作区路径、本地文档路径
   - 注入的引导文件（项目上下文）
   - 当前日期时间（仅时区，保持缓存稳定；实时时间用 `session_status`）
   - 助手输出指令（附件/语音/回复标签语法）
   - Heartbeats、运行时信息（主机/OS/模型/思考级别）
3. **缓存优化**：稳定内容（含项目上下文）在提示词缓存边界上方；每轮易变部分（消息传递/语音/群聊上下文/运行时）在下方——支持前缀缓存的本地后端跨轮复用
4. **提示词模式**（`promptMode`）：
   - `full`（默认）：完整结构
   - `minimal`（子智能体）：省略记忆提示、自我更新、用户身份等，保留工具/安全/Skills/工作区
   - `none`：仅基础身份行
5. **引导文件截断限制**：单文件 20000 字符 / 总计 60000 字符（`bootstrapMaxChars` / `bootstrapTotalMaxChars`），可用 `/context list` 查看实际注入量
6. **`memory/*.md` 每日文件不注入普通轮次**——通过 `memory_search` / `memory_get` 按需访问（省上下文）；仅 `/new`、`/reset` 后的第一轮可能预置近期日志
7. **子智能体会话只注入 `AGENTS.md` 和 `TOOLS.md`**（其余被过滤，保持上下文精简）

**动手练习**
- 对话中输入 `/context list`、`/context detail`：查看每个注入文件的原始/注入/截断情况
- 对比主会话与子代理的提示词差异（观察 `promptMode=minimal` 的效果）

**自测**：为什么提示词要区分"缓存边界上下"？——稳定前缀可被本地后端缓存复用，降低每轮 token 消耗。

---

## 6. 阶段五：记忆系统——Agent 如何跨会话记住（60 分钟）

**官方文档**：《记忆概览》https://docs.openclaw.ai/zh-CN/concepts/memory

**核心知识点**

1. **记忆 = 工作区里的纯 Markdown 文件**（默认 `~/.openclaw/workspace`）；"模型只记得保存到磁盘的内容，不存在隐藏状态"
2. **三个记忆相关文件**：
   - `MEMORY.md`：长期记忆（精选事实/偏好/决定），会话开始加载
   - `memory/YYYY-MM-DD.md`：每日笔记（详细记录、观察），`/new`、`/reset` 时自动加载今天和昨天；平时按需检索
   - `DREAMS.md`（可选）：梦境日记 + Dreaming 扫描摘要，供人工审阅
3. **分工原则**：`MEMORY.md` 精简整理；每日笔记是工作层；随时间为从每日笔记提炼到 MEMORY.md，同时移除过时条目（生成的工作区指令和 Heartbeat 流程定期做）
4. **记忆工具**：
   - `memory_search`：语义搜索（配置嵌入提供商后 = 向量相似度 + 关键词混合搜索）
   - `memory_get`：读取特定文件或行范围
   - 默认由 `memory-core` 插件提供
5. **记忆后端可选**：内置 SQLite（默认，开箱即用）· QMD（本地优先）· Honcho（AI 原生跨会话，需插件）· LanceDB（需插件）；另有 `memory-wiki` 知识库层
6. **操作敏感型记忆**：影响未来行动的笔记要记录行动边界（何时可行动、到期条件、来源权限、应避免什么）——但记忆只保留上下文，不强制策略；强制用审批/沙箱/cron
7. **自动记忆刷新**：压缩总结对话前会先跑一个静默轮次，把重要上下文存进记忆文件（默认开启，`compaction.memoryFlush.enabled` 可关）——防止压缩丢上下文
8. **Dreaming（做梦）**：可选后台整合流程，收集短期召回信号→评分→只晋升符合条件的到 MEMORY.md；默认禁用；输出到 DREAMS.md 供审阅
9. **CLI**：`openclaw memory status` / `openclaw memory search "query"` / `openclaw memory index --force`

**动手练习**
```bash
openclaw memory status                  # 看索引状态和提供商
openclaw memory search "记忆系统"        # 从命令行搜索
ls ~/.openclaw/workspace/memory/        # 看每日笔记
head -50 ~/.openclaw/workspace/MEMORY.md # 看长期记忆索引
```
- 对我说"记住 XXX"，观察我写入哪个文件（这是最直观的体验）

**自测**：MEMORY.md 和 memory/YYYY-MM-DD.md 的分工？——前者是精选长期摘要（每轮注入），后者是详细工作日志（按需检索，不占上下文）。

---

## 7. 阶段六：会话管理——消息如何路由与隔离（45 分钟）

**官方文档**：《会话管理》https://docs.openclaw.ai/zh-CN/concepts/session

**核心知识点**

1. **会话**：每条入站消息按来源路由到会话；所有会话状态由 Gateway 管理
2. **路由规则**：私信默认共享会话 · 群聊按群组隔离 · 房间/频道按房间隔离 · 定时任务每次新会话 · Webhooks 按 hook 隔离
3. **私信隔离**（多用户必须开）：`session.dmScope`：`main`（默认，所有私信共享）/ `per-peer`（按发送者）/ `per-channel-peer`（按渠道+发送者，推荐）/ `per-account-channel-peer`
4. **会话生命周期**：
   - 不自动重置（默认）：同一 sessionId，靠压缩管理长对话
   - 每日重置：`mode:"daily"` + `atHour`（默认 4 点）
   - 空闲重置：`mode:"idle"` + `idleMinutes`
   - 手动：`/new`（可切模型）、`/reset`
5. **状态存储**：SQLite `~/.openclaw/agents/<agentId>/agent/openclaw-agent.sqlite`；归档转录在 `sessions/` 目录
6. **会话维护**：`session.maintenance` 默认 `mode:"enforce"`、`pruneAfter:"30d"`、`maxEntries:500`；`openclaw sessions cleanup` 可手动执行
7. **检查命令**：`openclaw status`、`openclaw sessions --json`、对话内 `/status`、`/context list`

**动手练习**
```bash
openclaw sessions --json        # 看所有会话（对照：哪些是私信/群聊/cron/子代理）
openclaw sessions cleanup --dry-run   # 预览维护清理（只预览不执行）
```

**自测**：为什么说"所有私信共享会话"在多人环境是危险的？——Alice 的消息会对 Bob 可见，必须开 `dmScope: per-channel-peer`。

---

## 8. 阶段七：多智能体——一个 Gateway 多个 Agent（60 分钟）

**官方文档**：《多智能体路由》https://docs.openclaw.ai/zh-CN/concepts/multi-agent

**核心知识点**

1. **三个核心概念**：
   - `agentId`：一个"大脑"（工作区 + 每智能体认证 + 每智能体会话存储）
   - `accountId`：一个渠道账户实例（如 WhatsApp 的 personal 与 biz）
   - `binding`：按 `(channel, accountId, peer)` 把入站消息路由到 agentId
2. **每个 Agent 拥有**：独立工作区、`agentDir` 状态目录、SQLite 会话存储、auth-profiles.json、每智能体 Skills 允许列表
3. **单智能体模式（默认）**：agentId=`main`、会话键 `agent:main:main`、工作区 `~/.openclaw/workspace`
4. **添加新 Agent**：`openclaw agents add work`（可用 `--workspace`、`--model`、`--bind` 等）
5. **路由规则**：确定性、最具体匹配优先；同层多个匹配时配置顺序第一个获胜；多字段为 AND 语义
6. **常见模式**：
   - 按渠道拆分（WhatsApp 日常 + Telegram 深度工作）
   - 同一渠道把一个对端路由到专用 Agent（对端绑定优先于渠道级规则）
   - 家庭智能体绑定单个群组 + 更严工具策略
7. **每智能体沙箱与工具**：`sandbox.mode`（off/all）、`tools.allow`/`deny` 列表；elevated 权限需全局+每智能体双重门控
8. **安全警告**：切勿在 Agent 间复用 `agentDir`（认证/会话冲突）；工作区是默认 cwd 不是硬沙箱，绝对路径可访问主机其他位置
9. **Agent 间通信**：`tools.agentToAgent` 默认关闭，需显式启用 + 允许列表

**动手练习（只读为主）**
```bash
openclaw agents list --bindings   # 看当前 Agent 和绑定
# 思考题：如果给家人开一个独立 Agent，需要哪几步？
# （agents add → 配渠道账户 → 加 binding → restart → 验证）
```

**自测**：`agentId`、`accountId`、`binding` 三者关系？——agentId 是人格边界，accountId 是渠道账户实例，binding 把"哪个账户的哪条消息"路由给"哪个 Agent"。

---

## 9. 阶段八：实战验收（30 分钟）

完成以下全部项目即达成学习目标：

- [ ] 能说出 Gateway、Agent、Session、Binding 四个概念的一句话定义
- [ ] 能说出工作区 8 个引导文件的名字和用途
- [ ] 能画出 Agent loop 的 5 步流程（RPC→agentCommand→runEmbeddedAgent→事件桥接→wait）
- [ ] 能用 `/context list` 检查系统提示词实际注入内容
- [ ] 能说出 MEMORY.md / memory/ 日志 / DREAMS.md 的分工
- [ ] 能说出会话的 4 种重置方式
- [ ] 能说出多智能体路由的匹配优先级（对端 > 渠道级）
- [ ] 跑过 `openclaw status`、`openclaw agents list`、`openclaw memory status` 并理解输出
- [ ] 向瑶光说"记住 X"并验证记忆写入

---

## 10. 延伸阅读（按需深入）

| 主题 | 官方页面 |
|------|---------|
| Agent 工作区完整布局与备份 | /zh-CN/concepts/agent-workspace |
| 压缩（长对话总结） | /zh-CN/concepts/compaction |
| 流式传输与分块 | /zh-CN/concepts/streaming |
| 命令队列与并发 | /zh-CN/concepts/queue |
| 记忆搜索（提供商与调优） | /zh-CN/concepts/memory-search |
| Dreaming 记忆整合 | /zh-CN/concepts/dreaming |
| 子智能体 | /zh-CN/tools/subagents |
| Hooks 自动化 | /zh-CN/automation/hooks |
| 定时任务 | /zh-CN/automation/cron-jobs |
| 渠道路由 | /zh-CN/channels/channel-routing |
| Gateway 配置参考 | /zh-CN/gateway/configuration |
| 沙箱隔离 | /zh-CN/gateway/sandboxing |
| 工具与审批 | /zh-CN/tools、/zh-CN/tools/exec-approvals |
| 模型提供商与故障转移 | /zh-CN/concepts/model-providers、/zh-CN/concepts/model-failover |
| 会话搜索 | /zh-CN/concepts/session-search |
| 上下文引擎 | /zh-CN/concepts/context-engine |

> 所有链接前缀：https://docs.openclaw.ai

---

## 11. 学习方法建议

1. **每阶段都做练习**：文档 + 真实系统对照，理解最深
2. **带着问题读**：先看"自测题"再读正文，读完能答上就算过关
3. **善用对话**：遇到不懂的直接问我（瑶光），我可以现场解读任意文档段落
4. **本地文档兜底**：服务器上有完整英文原版 `/usr/lib/node_modules/openclaw/docs`，中文站没有的细节可以查它
5. **学完做输出**：试着向别人（或向我）讲解"Agent 是什么"，讲得清楚 = 真的懂了
