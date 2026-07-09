# 瑶光记忆系统 v2.4 — 最终方案

> 基于 v2.0 → v2.1 → v2.2 → v2.3 四轮迭代 + GLM 5.2 三轮评估反馈，最终版。
>
> 构建日期：2026-07-09
> 项目：瑶光—记忆系统子代理设计与构建
> 状态：架构评审通过，可进入 Phase 1 编码

---

## 一、背景与痛点

所有任务挤在主代理运行 → 上下文混乱 → 分配给子代理后记忆不互通 → 需要专门的记忆架构串联。

**核心痛点排序（按痛苦程度）：**

1. **C. 子代理之间记忆不互通** — 核心诉求，驱动项目的根本原因
2. **A. 跨会话记不住偏好，需重复说明** — 次核心痛点
3. **D. 上下文太长导致遗忘** — 主代理 + 子代理混在一起放大问题
4. **B. 记不住上次改了什么** — 子代理结果没有持久化
5. **E. 信噪比下降** — 提前意识到的潜在问题

---

## 二、架构设计

### 核心架构图

```
主代理 (Main Agent)
│
├─ 记忆模块 (Memory Module, 主代理内模块, 非独立agent)
│ │
│ ├─ 层A: 指令记忆
│ │ ├─ 四层优先级加载 (全局→用户→项目→本地)
│ │ └─ 注入: Phase 1 依赖 contextInjection 单通道
│ │          Phase 2 实现双轨注入 (通道A 对话/通道B system prompt)
│ │
│ ├─ 层B: 长期事实
│ │ ├─ 四类封闭分类: user / feedback / project / reference
│ │ ├─ 索引: 直接用 MEMORY.md (不另建 index.md)
│ │ ├─ 文件结构:
│ │ │   ~/.openclaw/memory/
│ │ │   ├── MEMORY.md           ← 索引 (常驻 contextInjection)
│ │ │   ├── long-term/
│ │ │   │   ├── user-profile.md
│ │ │   │   ├── feedback-log.md
│ │ │   │   ├── project-context.md
│ │ │   │   └── references.md
│ │ │   ├── pending/            ← 暂存池 (保留)
│ │ │   └── archived/           ← 已归档
│ │ ├─ 召回: Phase 1 主代理内联判断 + read 按需加载
│ │ │       Phase 2 Qwen 异步 prefetch (MCP Server)
│ │ ├─ 新鲜度: 自然语言年龄 + 超1天警告
│ │ ├─ 快照冻结: contextInjection "continuation-skip" 框架自带
│ │ └─ 写入: Phase 1 非原子写 (个人agent, 低并发)
│ │          Phase 2 原子写 (MCP Server temp file + os.rename)
│ │
│ ├─ 层C: 完整历史
│ │ ├─ 存储: ~/.openclaw/memory/transcripts/
│ │ │   ├── sessions.db       ← SQLite + FTS5
│ │ │   └── {session-id}.json ← 子代理运行轨迹
│ │ ├─ Session Search:
│ │ │   ├─ 空query: cheap mode (标题+时间, 无LLM)
│ │ │   ├─ 最多5 session, 自动排除当前链路
│ │ │   └─ 定向摘要 (面向当前query)
│ │ ├─ Flash Memories: DeepSeek, 压缩前抢注
│ │ ├─ 压缩即分支: Continuation Session with parent_session_id
│ │ └─ Session Memory: 渐进式笔记, 双阈值触发
│ │
│ ├─ 层D: 外部提供方 (占位)
│ │ └─ MemoryProvider 接口 (单活跃, 预留外部语义记忆后端)
│ │
│ ├─ 安全层
│ │ ├─ Phase 1: System Prompt 安全检查指引
│ │ └─ Phase 2: 代码级 threat scanning (MCP Server)
│ │
│ └─ 成本控制
│     ├─ 低判断任务 → Qwen 3.6 Plus (零成本)
│     ├─ 关键时刻(Flash Memories) → DeepSeek V4 Flash
│     └─ 速率超限时暂停后台任务
│
├─ 子代理 A ── Phase 1: 预注入 (spawn 时主代理 recall → 注入 task)
│              Phase 2: 共享只读 (exec sqlite3 查询 FTS5)
│              无 store() 权限
│
├─ 子代理 B ── (同上)
│
└─ 通信: onDelegation hook → 子代理结果存 transcript
     (不自写记忆, 由 Background Review 统一提取)
```

### 关键约束

| # | 规则 | 来源 | 理由 |
|---|------|:----:|------|
| 1 | 子代理无 `store` 权限 | Hermes | 上下文窄，易把局部偶然当成长期事实 |
| 2 | 召回结果不写回 transcript | Hermes | 防自我污染 |
| 3 | 新内容当前 session 不生效（快照冻结） | Hermes + framework | 保住 prefix cache 稳定 |
| 4 | 明确不存"代码可推导的内容" | Claude Code | 代码本身是最权威来源 |
| 5 | 子代理结果为纯文本 → 存 transcript → Review 统一提取 | 自研 | 避免每次子代理返回都调用 LLM |
| 6 | turn 定义 = 1 次主代理完整 API 调用周期 | 自研 | 含多步工具调用算 1 turn |
| 7 | 层A 为静态指令，层B 为动态记忆，严格分离 | 自研 | 防角色混淆 |

---

## 三、记忆交互协议

```
写入（仅主代理可写）：
  store(type, content, scope?)
    type: user|feedback|project|reference
    content: 记忆内容
    scope: global|project|local

读取：
  recall(query, context?)          → 主代理 + 子代理(预注入)
  search(query)                    → FTS5 全文搜索
  session_lookup(id)               → 某次运行轨迹
  recent_sessions(limit?)          → cheap mode (标题+时间戳)

删除：
  forget(query)                    → 标记过时或删除

压缩控制：
  flash_memories()                 → 压缩前知识抢注 (DeepSeek)
  compress(session_id)             → 压缩=开分支, 不覆盖旧历史

后台：
  trigger_review()                 → 手动触发 Background Review
  status()                         → 缓存状态 / 未合并条目
```

---

## 四、实现路线图

### Phase 1 — 地基（P0，解决核心痛点 C+A）

| 序号 | 模块 | 实现方式 | 依赖 |
|:----:|------|---------|:----:|
| 1.1 | MEMORY.md 四类分拆 + 索引格式 | 手动编辑 | 现有 MEMORY.md |
| 1.2 | long-term/ 目录 + 四类记忆文件 | 创建目录 + 分拆文件 | 1.1 |
| 1.3 | System Prompt 记忆操作指引 | 写入 AGENTS.md | 1.1, 1.2 |
| 1.4 | SQLite + FTS5 sessions.db | exec 创建 DB + 安装 sqlite3 | — |
| 1.5 | 主代理 transcript 自动写入 | System Prompt 指引 + exec | 1.4 |
| 1.6 | 子代理预注入 | spawn 时 recall + 拼接 task | 1.2 |
| 1.7 | 子代理结果写入 transcript | onDelegation hook + exec | 1.4 |

**Phase 1 交付后解决：**
- ✅ C. 子代理记忆互通（预注入）
- ✅ A. 跨会话记住偏好（层B + contextInjection 快照冻结）
- ⚠️ B. 记住上次改了什么（层C transcript，需习惯使用 search）

### Phase 2 — 压缩安全网（P1，解决痛点 D+B）

| 序号 | 模块 | 实现方式 |
|:----:|------|---------|
| 2.1 | Flash Memories (压缩前抢注) | DeepSeek, 系统 prompt 指引 |
| 2.2 | Continuation Session (压缩即分支) | 系统 prompt 指引 |
| 2.3 | Background Review (10轮阈值) | Qwen, sessions_spawn 后台子代理 |
| 2.4 | 子代理共享只读 (sqlite3 CLI) | exec 工具 |
| 2.5 | MCP Server 升级 | @modelcontextprotocol/sdk |

### Phase 3 — 质量提升（P2）

| 序号 | 模块 | 实现方式 |
|:----:|------|---------|
| 3.1 | Session Memory (渐进式笔记) | Qwen, 双阈值触发 |
| 3.2 | Qwen 异步 prefetch | MCP Server |
| 3.3 | 原子写 | MCP Server temp file + os.rename |
| 3.4 | 代码级 threat scanning | MCP Server |

### Phase 4 — 离线整合（P3）

| 序号 | 模块 | 实现方式 |
|:----:|------|---------|
| 4.1 | Auto Dream (24h+5会话, 四阶段, 锁机制) | DeepSeek, sessions_spawn |

---

## 五、Phase 1 做什么 vs 不做什么

| 做 ✅ | 不做（推迟到 Phase 2+） ❌ |
|------|---------------------------|
| MEMORY.md 四类分拆 + 索引格式 | Qwen 异步 prefetch（用主代理内联判断替代） |
| contextInjection 快照冻结（框架自带） | 双轨注入（用 contextInjection 单通道替代） |
| System Prompt 指引 + read/write/exec 工具 | MCP Server |
| SQLite + FTS5 + session search | @include 递归 + 条件规则 |
| 子代理预注入（spawn 时 task 拼接） | 子代理共享只读（sqlite3 CLI） |
| 主代理内联 recall（不调 Qwen） | 原子写（接受非原子风险） |
| transcript 写入 | 代码级 threat scanning（用 prompt 指引替代） |
| Background Review | Flash Memories |
| — | Session Memory |
| — | Auto Dream |
| — | Continuation Session |

---

## 六、环境上下文

### 运行环境
- **主机**：Tencent Cloud Linux VM（VM-0-14-ubuntu），非 WSL2
- **操作系统**：Linux 6.8.0-124-generic (x64)
- **OpenClaw**：2026.6.11 (e085fa1)
- **模型**：DeepSeek V4 Flash（主模型，1M context window，input 0.14/1M tokens）
- **副模型**：Qwen 3.6 Plus（零成本，不支持 reasoning，1M context window）
- **备用模型**：MiniMax M3（input 0.6/1M tokens，太贵不适合后台）

### 现有记忆文件
| 文件 | 大小 | 作用 |
|------|:----:|------|
| `MEMORY.md` | 5.8KB | 长期记忆主文件，按主题分节 + 时间戳 + 标签 |
| `memory/YYYY-MM-DD.md` | 5 篇 ~6KB | 手动 daily log |
| `memory/pending-memory.md` | 334B | 暂存池模板（空） |
| `~/self-improving/` | 32KB | 执行教训、纠正、规则 |
| `~/proactivity/` | 20KB | 任务状态、下一步 |

### 代理通信
- 通信方式：`sessions_spawn`（OpenClaw 内置）
- 子代理是独立 session，task 纯文本
- 子代理返回结果文本，非结构化
- 后台异步：`sessions_spawn mode="run"` + `cron`

### 上下文压缩现状
- OpenClaw 目前**没有 LLM 摘要式压缩**
- 只有 session reset（按时间/空闲清空）
- 当前 session 已持续 6 小时未被 reset
- **compactions: 0**

### contextInjection 机制（关键发现）
- `mode: "continuation-skip"`：安全续接跳过注入，压缩/心跳后重建
- 天然实现了 Hermes 的 System Prompt 快照冻结
- 单文件上限 20KB，总计上限 60KB
- workspace 文件（AGENTS.md, SOUL.md, USER.md, MEMORY.md 等）统一注入

---

## 七、来源对照表

| 设计元素 | 来源 |
|----------|:----:|
| 四层指令优先级 + 条件规则 + @include | Claude Code |
| 四种记忆类型 + 明确不存什么 | Claude Code |
| 异步 prefetch 召回 + 轻量模型判断 | Claude Code |
| 新鲜度系统 (自然语言年龄 + 超1天警告) | Claude Code |
| Session Memory 渐进式笔记 + 双阈值 | Claude Code |
| Auto Dream 离线整合 + 四阶段 + 锁机制 | Claude Code |
| 双轨注入 (通道A/通道B) | Claude Code |
| 稳定事实 vs 完整历史硬拆分 | Hermes Agent |
| 外部 recall 不写回 transcript (防自我污染) | Hermes Agent |
| System prompt 快照冻结 + session 级缓存 | Hermes Agent → 框架自带 |
| Background Review + 10 轮阈值触发 | Hermes Agent |
| 子代理无 store 权限 + onDelegation hook | Hermes Agent |
| FTS5 + session search 克制设计 | Hermes Agent |
| Flash Memories 压缩前抢注 | Hermes Agent |
| 压缩即分支 (Continuation Session) | Hermes Agent |
| 原子写 + threat scanning | Hermes Agent |
| 可插拔 MemoryProvider 接口 | Hermes Agent |
| contextInjection 快照冻结（框架原生） | OpenClaw 框架 |
| 模块优先, 独立 agent 第二版 | GLM 5.2 评估建议 |
| 个人 agent 砍团队同步 | 先生决策 |
| 两阶段工具实现 (prompt→MCP) | 瑶光（环境调研） |
| 子代理 recall 两阶段 (预注入→只读) | 瑶光（环境调研） |
| 分模型策略 (Low→Qwen, Critical→DeepSeek) | 瑶光 + GLM |
| MEMORY.md 直接做索引，不另建 | 瑶光（尊重现有数据） |
| Phase 1 适配调整 (单通道/内联/非原子) | GLM 5.2 第三轮评审 |
| 清理项处理 (层D描述/turn定义/阈值/迁移路径) | GLM 5.2 第三轮评审 |

---

*本方案为「瑶光—记忆系统子代理设计与构建」项目的最终设计稿。经过 v2.0 → v2.1 → v2.2 → v2.3 → v2.4 五轮迭代，架构评审通过，可进入 Phase 1 编码实现。*
