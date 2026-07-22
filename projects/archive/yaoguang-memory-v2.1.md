# 瑶光记忆系统 v2.1 — 修订方案

> 基于 v2.0 草案 + GLM 5.2 评估反馈 + 环境调研，修订版。
>
> 构建日期：2026-07-09
> 状态：待评估 v2

---

## 一、环境上下文（回答 GLM 5 个问题）

### Q1. 现有记忆系统现状

| 文件 | 大小 | 运作方式 |
|------|------|---------|
| `MEMORY.md` | 5.8KB | 通过 AGENTS.md 的 project context 注入，会话启动时一次性读入 |
| `memory/YYYY-MM-DD.md` | 5 篇，共 ~6KB | 手动维护的 daily log，非自动生成 |
| `memory/pending-memory.md` | 334B，空 | 暂存池模板，设计为不确定信息先放此处，暂未使用 |
| `~/self-improving/` | 32KB | 执行教训、纠正、规则，由主代理主动写入 |
| `~/proactivity/` | 20KB | 任务状态、下一步，由主代理主动写入 |

**关键结论**：目前没有子代理之间任何形式的记忆共享。子代理跑完即丢。

### Q2. 代理通信机制

- 通信方式：**`sessions_spawn`**（OpenClaw 内置工具）
- 子代理是独立 session，上下文由主代理在 spawn 时编写 task 分发
- 子代理返回结果文本，**非结构化 result 对象**
- 支持**后台异步任务**：`sessions_spawn mode="run"` + `cron` 定时触发
- **结论**：记忆模块做主代理内模块完全可行，无需跨进程通信

### Q3. 可用模型

| 模型 | 角色 | contextWindow | 成本 | 能否做后台 |
|------|------|:------:|:----:|:---------:|
| **DeepSeek V4 Flash** | 主模型，推理 | 1M | input 0.14/1M tokens | 主线链路 |
| **Qwen 3.6 Plus** | 视觉副驾，不支持 reasoning | 1M | **零成本（免费额度）** | ✅ |
| **MiniMax M3** | 备用，推理 | 1M | input 0.6/1M tokens | ❌ 太贵 |

**结论**：Qwen 3.6 Plus 最适合后台轻量任务（prefetch、background review），零成本。

### Q4. 上下文压缩现状

**OpenClaw 目前没有 LLM 摘要式压缩。** 只有简单的**会话重置（session reset）**：
- 按时间重置（每日/空闲自动清空上下文）
- 当前配置：`dmScope: "main"`，所有 DM 走同一个主 session
- reset = 清空消息，不保留旧会话的逐步摘要
- session_status 确认：**`compactions: 0`**

**结论**：Flash Memories、Continuation Session、Session Memory 都要自己实现，不能依赖框架。

### Q5. 核心痛点优先级

按痛苦程度排序：

1. **C. 子代理之间记忆不互通** — 核心诉求，驱动整个项目的根本原因
2. **A. 跨会话记不住偏好，需重复说明** — 次核心痛点
3. **D. 上下文太长导致遗忘** — 主代理+子代理混在一起放大了这个问题
4. **B. 记不住上次改了什么** — 子代理结果没有持久化
5. **E. 信噪比下降** — 提前意识到的潜在问题

---

## 二、GLM 评估指出的问题及修订

### 已补上的缺失机制

#### ✅ 缺失1：Flash Memories（压缩前知识抢注）

**位置**：补入层C后台，压缩触发时前置执行。

**流程**：
1. 压缩条件达成 → 触发 Flash Memories
2. 在消息列表末尾临时追加一条 system 风格消息："上下文即将丢失，请保存值得长期记住的内容，特别是用户偏好、纠正和重复模式"
3. 发起**仅开放 memory 工具**的额外模型调用（**优先走 Qwen 3.6 Plus 零成本模型**）
4. 如果产生 memory tool call → 执行写入
5. 把临时追加的消息和调用痕迹从消息列表中剥离，**不污染 transcript**
6. 然后才执行压缩（用 Session Memory 替代摘要）

**与 Session Memory 的关系**：
- Session Memory = 对话中持续做笔记，**被动维护**
- Flash Memories = 压缩前最后一刻，**主动抢救**来不及记的关键信息
- 两者是**互补关系，不是替代关系**

#### ✅ 缺失2：压缩即分支（Continuation Session）

**位置**：补入层C，取代"直接覆盖旧历史"的做法。

**规则**：
- 压缩 ≠ 覆盖旧 session
- 结束旧 session，生成新的 session ID
- 创建带 `parent_session_id` 的 continuation session
- 压缩后的消息写入新 session
- 旧 transcript 完整保留，不丢失

**为何必要**：
- Session search 的"排除当前链路"逻辑依赖 `parent_session_id` 链路感知
- 如果压缩覆盖旧历史，后续搜索会丢失之前的内容
- Claude Code 的 `calculate_messages_to_keep_index` 只解决"保留哪些消息"，不解决"保留旧历史"

#### ✅ 缺失3：双轨注入（Dual-track Injection）

**位置**：补入层A，明确注入通道。

```
通道A — 指令记忆（用户可变内容）
  载体：claude.md 指令文件组
  注入方式：对话消息通道（作为对话列表第一条 user meta message）
  缓存特性：指令修改 → 通道A 缓存失效 → 需重建
  优先级规则：后加载的优先级更高

通道B — 行为规范（系统稳定内容）
  载体：系统内建的 memory 操作指引
  注入方式：system prompt 数组（system prompt section）
  缓存特性：整个会话只计算一次，不因指令修改而重算
```

**目的**：两条通道缓存独立管理。通道B 稳定不变，整个会话只算一次，**保住 prefix cache**。这是 Hermes 花大力气避免的问题。

#### ✅ 缺失4：System Prompt 快照冻结

**位置**：补入层B，明确生命周期。

| 事件 | 快照行为 |
|------|---------|
| Session 启动 | 读取当前磁盘 memory 文件，冻结为快照，注入 system prompt |
| 中途写入 memory | 立即落盘，**不刷新**当前 session 的 system prompt 快照 |
| 新内容可见时机 | **下次 session 启动**才生效 |
| Context Compression 触发 | 缓存失效，重建 system prompt（加载最新的 memory 文件） |
| Session Reset | 重建 system prompt |

**例外**：如果实现**session 内 overlay 层**（见下文的待定设计），可在当前 session 即时看到新写入内容，同时不破坏 system prompt 前缀缓存。overlay 层走对话消息通道注入，不走 system prompt。

#### ✅ 缺失5：Chronos 日志模式

**状态**：列为 **P3 待规划项**。当前场景（个人 agent，非长周期持续运行服务）不需要立即实现。

**预留方式**：在层C 增加一个 `mode` 字段，默认 `standard`，后续可切 `chronos`（追加式日志，index.md 只读，夜间 dream 整理）。

#### ✅ 缺失6：团队同步记忆

**状态**：**已确认不需要。** 个人 agent 完全无此需求。

**但保留**：threat scanning（prompt injection 检测）和密钥检测——因为记忆内容最终注入 system prompt，恶意内容一旦写入会持久污染。这个是个人 agent 也需要保留的安全机制。

---

### 已解决的设计矛盾

#### 🔸 矛盾1：层A vs 层B 边界模糊 → 已解决

| 层 | 内容 | 举例 |
|----|------|------|
| **层A**（指令记忆） | **纯静态指令**：行为准则、项目约定、工具使用规范 | "修改代码前先运行测试"、"遵循 React 组件规范" |
| **层B**（长期事实） | **动态记忆**：用户画像、feedback、项目上下文、外部引用 | "先生偏好简洁回答"、"上次在 src/utils 改过 parseDate" |

- `MEMORY.md` 完全归**层B**
- 层A 的优先级2改为加载层B 的 `index.md` 摘要，不再直接引用 `MEMORY.md`

#### 🔸 矛盾2：记忆子代理物理形态 → 已决策

**第一版：主代理内模块**（非独立 agent）
- 通信：进程内调用，无需跨进程
- 并发：天然串行，无需锁机制
- 延迟：低
- 复杂度：低
- 未来的独立 agent 升级路径已预留

#### 🔸 矛盾3：Background Review 触发策略 → 已统一

- **主触发**：Hermes 式 **10 轮阈值**（连续 10 轮无 memory 写入时触发），不要每轮都跑
- **互斥逻辑**（从 Claude Code）：主代理手动写入了 → 跳过本轮 review
- **执行模型**：fork 轻量子代理，走 **Qwen 3.6 Plus（零成本）**
- **时机**：用户收到最终回复后异步执行，不抢注意力

#### 🔸 矛盾4：召回结果注入方式 → 已明确

采用 **Hermes 的 API call time injection 方式**：

1. 用**原始用户消息**（未被技能说明、附加内容加工过的版本）做 prefetch
2. 召回结果包进 `memory context` 标记
3. 拼到当前 user message 后面，仅在 API call 边界生效
4. **不写入 transcript**，不写入 session_memory
5. **不写入真实会话历史**

理由：如果召回结果被再次写进 transcript，后续 session search 会把系统自己的召回结果误当成真实历史，造成**自我污染**。

#### 🔸 矛盾5：成本模型 → 已补上

| 后台任务 | 推荐模型 | 成本 | 触发频率 |
|---------|---------|:----:|---------|
| Prefetch 召回 | **Qwen 3.6 Plus** | 零成本 | 每轮（异步，不阻塞） |
| Background Review | **Qwen 3.6 Plus** | 零成本 | 10 轮阈值 |
| Session Memory 更新 | **Qwen 3.6 Plus** | 零成本 | 双阈值（token + 内容变化） |
| Flash Memories | **Qwen 3.6 Plus** | 零成本 | 压缩触发时 |
| Auto Dream（第二版） | **DeepSeek V4 Flash** | 正常 | 24h + 5 会话 |

**全局约束**：设 token 预算上限，超限暂停所有后台任务，仅保持核心读写。

---

## 三、修订版架构（v2.1）

```
主代理 (Main Agent)
│
├─ 记忆模块 (Memory Module, 主代理内模块, 非独立agent)
│ │
│ ├─ 层A: 指令记忆
│ │ ├─ 四层优先级加载 (全局→用户→项目→本地)
│ │ ├─ @include 递归(最多5层) + 条件规则(glob匹配) + 嵌套附件
│ │ └─ 注入通道: 对话消息通道(通道A) ← 双轨注入
│ │
│ ├─ 层B: 长期事实
│ │ ├─ 四类封闭分类: user / feedback / project / reference
│ │ ├─ index.md 索引(200行/25KB上限) + 独立记忆文件(front matter)
│ │ ├─ 异步 prefetch 召回 (Qwen 轻量, 最多5篇, 不阻塞)
│ │ ├─ 新鲜度系统 (自然语言年龄 + 超1天警告)
│ │ ├─ System prompt 快照冻结 (session启动冻结, 中途写不刷新, 压缩才重建)
│ │ └─ 写入: 原子写 + threat scanning + 写入前重新读盘
│ │
│ ├─ 层C: 完整历史 (子代理运行轨迹)
│ │ ├─ SQLite + FTS5 (消息表 + FTS5 虚表)
│ │ ├─ Session Search (FTS5 → 分组 → transcript → 定向摘要)
│ │ │   ├─ 空query: cheap mode (标题+时间, 无LLM成本)
│ │ │   ├─ 最多总结5个session
│ │ │   └─ 自动排除当前链路 (resolve child→parent)
│ │ ├─ 召回结果: API call time injection, 不写回 transcript
│ │ ├─ Flash Memories (压缩前抢注) ← 补上
│ │ ├─ 压缩即分支 (Continuation Session with parent_session_id) ← 补上
│ │ └─ Session Memory (渐进式笔记, 双阈值触发)
│ │
│ ├─ 层D: 外部提供方 (占位)
│ │ └─ MemoryProvider 接口 (单活跃, prefetch不写transcript)
│ │
│ ├─ 安全层 (跨层)
│ │ ├─ 写入前 threat scanning (prompt injection / 角色劫持 / 密钥检测)
│ │ ├─ 原子写 (temp file + os rename)
│ │ └─ 写入前重新读盘吸收并发变更
│ │
│ └─ 成本控制 (跨层)
│     ├─ 后台任务优先走 Qwen 3.6 Plus (零成本)
│     ├─ 全局 token 预算上限
│     └─ 超限暂停全部后台任务
│
├─ 子代理 A ── recall() 只读, 无 store() 权限
├─ 子代理 B ── recall() 只读, 无 store() 权限
│
└─ 通信: onDelegation hook → task+result 回流主代理
     (子代理不自写记忆, 让主代理判断什么值得记)
```

---

## 四、交互协议（修订版）

### 主代理 ↔ 记忆模块 API

```
写入（仅主代理可写）：
  store(type, content, scope?)
    type: user|feedback|project|reference
    content: 记忆内容
    scope: global|project|local

读取（主代理 + 所有子代理可读）：
  recall(query, context?) → 最多5篇，async prefetch
  search(query)            → FTS5 全文搜索
  session_lookup(id)       → 某次运行轨迹（含 tool_calls、reasoning）

删除：
  forget(query)            → 标记过时或删除

压缩控制：
  flash_memories()         → 触发 compression 前抢救
  compress(session_id)     → 压缩=开分支，不覆盖

后台：
  trigger_review()         → 手动触发 background review
  status()                 → 缓存状态 / 未合并条目 / token 预算
```

### 关键约束

| # | 规则 | 来源 | 理由 |
|---|------|------|------|
| 1 | 子代理无 `store` 权限 | Hermes | 子代理上下文窄，容易把局部偶然当成长期事实 |
| 2 | 召回结果不写回 transcript | Hermes | 防自我污染：否则 future session search 会混淆"真实历史"和"系统召回" |
| 3 | 写入走原子写 | Hermes | 防多进程/多 session 并发读空文件 |
| 4 | 写入前 threat scanning | Hermes | 记忆注入 system prompt，恶意内容一旦写入持久污染 |
| 5 | 写入前重新读盘 | Hermes | 吸收并发变更，防止覆盖其他进程刚写的内容 |
| 6 | 新内容当前 session 不生效 | Hermes | 保住 system prompt prefix cache 稳定性 |
| 7 | 明确不存"代码可推导的内容" | Claude Code | 代码本身是最权威来源，存副本只会过时和产生矛盾 |

---

## 五、实现优先级（修订版）

| 优先级 | 模块 | 说明 |
|:------:|------|------|
| **P0** | 层A: 指令记忆 + 双轨注入 | 记忆系统的基础设施 |
| **P0** | 层B: 长期事实 + 快照冻结 + prefetch | 核心记忆读写，元数据索引 |
| **P0** | 层C: FTS5 transcript + session search | 子代理运行轨迹，子代理记忆的本质 |
| **P1** | Flash Memories + Continuation Session | 压缩边界的完整性 |
| **P1** | Background Review（10轮阈值） | 自动提取保障，Qwen 零成本 |
| **P2** | Session Memory（渐进式笔记） | 提高压缩质量，但不做也能用 |
| **P3** | Auto Dream（离线整合） | 锦上添花，P0 不通它也没用 |
| **待定** | 层D 外部 provider + Chronos 模式 | 预留接口，需要时再接入 |

---

## 六、与现有系统的兼容性

| 现有文件 | 归宿 | 操作 |
|----------|------|------|
| `MEMORY.md` | 层B 主索引，兼容旧条目 | 保留，后期可逐步迁移到 index.md |
| `memory/YYYY-MM-DD.md` | 主代理 daily log | 保留不动 |
| `memory/pending-memory.md` | 暂存池 | 保留不动 |
| `~/self-improving/` | 执行教训 → 逐步归入层B feedback-log | 逐步归入，不破坏原有 |
| `~/proactivity/` | 任务状态 → 由 session memory 支撑 | 保留不动 |

**原则**：全部向下兼容，不破坏任何现有数据。

---

## 七、来源对照表

| 设计元素 | 来源 |
|----------|------|
| 四层指令优先级 + 条件规则 + @include | Claude Code |
| 四种记忆类型 + 明确不存什么 | Claude Code |
| 异步 prefetch 召回 + 轻量模型判断 | Claude Code |
| 新鲜度系统 (自然语言年龄 + 超1天警告) | Claude Code |
| Session Memory 渐进式笔记 + 双阈值 | Claude Code |
| Auto Dream 离线整合 + 四阶段 + 锁机制 | Claude Code |
| 子代理两回合策略 (并行读/写) | Claude Code |
| 三层独立缓存体系 | Claude Code |
| 稳定事实 vs 完整历史硬拆分 | Hermes Agent |
| 外部 recall 不写回 transcript (防自我污染) | Hermes Agent |
| System prompt 快照冻结 + session 级缓存 | Hermes Agent |
| Background Review + 10 轮阈值触发 | Hermes Agent |
| 子代理无 store 权限 + onDelegation hook | Hermes Agent |
| FTS5 + session search 克制设计 | Hermes Agent |
| Flash Memories 压缩前抢注 | Hermes Agent |
| 压缩即分支 (Continuation Session) | Hermes Agent |
| 原子写 + threat scanning | Hermes Agent |
| 可插拔 MemoryProvider 接口 | Hermes Agent |
| 双轨注入 (通道A/通道B) | Claude Code |
| 成本模型 + 后台任务走轻量模型 | **自研（基于环境调研）** |
| 模块优先于独立 agent（第一版） | **GLM 评估建议** |
| 个人 agent 砍掉团队同步 | **先生决策** |

---

*本方案为「瑶光—记忆系统子代理设计与构建」项目的 v2.1 修订草案，待 GLM 5.2 评估后进入下一轮迭代。*
