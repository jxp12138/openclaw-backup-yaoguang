# 瑶光记忆系统 v2.2 — 二次修订方案

> 基于 v2.1 修订版 + GLM 5.2 第二轮评估反馈，确认并修正。
>
> 构建日期：2026-07-09
> 状态：待评估 v3

---

## 一、第二轮 GLM 评估的问题及回应

### 🔴 架构级问题（3个）

#### 问题1：子代理 recall 路径断裂

**GLM 指出**：记忆模块是主代理内模块，子代理是独立 session，无法直接调用 recall()。三条路径需要选择（预注入/工具回调/共享文件）。

**瑶光的判断**：✅ 完全采纳，并细化为两阶段方案。

| 阶段 | 方案 | 机制 | 覆盖场景 |
|:----:|:----:|------|---------|
| **Phase 1** | **路径A：预注入** | 主代理 spawn 子代理时，先执行 `recall(task_desc)`，将相关记忆作为 task prompt 的一部分注入 | 子代理启动时需要的全部上下文（80% 场景） |
| **Phase 2** | **路径C：共享只读** | 子代理通过 `exec sqlite3 :db_path "SELECT ..."` 只读查询 FTS5 数据库 | 子代理执行过程中需要动态查询的场景 |

- **路径B（工具回调）**：OpenClaw 目前无子代理回调主代理的机制，放弃。
- Phase 2 的资格检查：子代理已有 exec 工具权限，`sqlite3` 是零依赖 CLI，无需额外框架支持。

---

#### 问题2：Session Reset 与 Flash Memories 时序竞争

**GLM 指出**：如果框架自动触发 session reset，Flash Memories 来不及跑，关键信息丢失。

**瑶光的调查与回应**：

现场确认：
- 当前 `session` 配置为**空**，使用 OpenClaw 默认值
- 当前 session **已持续 6 小时未被 reset**（从 11:40 到 18:00+）
- 默认不会频繁清除上下文

**最终方案**：
- **不禁用框架 reset**（当前没有自动 reset 问题）
- **全部由记忆模块内部管理上下文生命周期**
- 记忆模块主动监控 token 使用量，接近阈值时自行触发 Flash Memories → Continuation Session
- 如果未来启用框架自动 reset，保留"前置 hook 接入 Flash Memories"的预留设计

---

#### 问题3：Qwen 3.6 Plus（非 reasoning）能否胜任判断类任务

**GLM 指出**：Flash Memories 是最后一道防线，如果 Qwen 判断力不足，永久丢失关键信息。

**瑶光的回应**：✅ 完全采纳 GLM 的建议，重新分配任务模型：

| 后台任务 | 原方案 | 修订后 | 理由 |
|---------|:------:|:------:|------|
| **Flash Memories** | Qwen ❌ | **DeepSeek V4 Flash** ✅ | 最后一道防线，不能省。触发频率低，成本可控 |
| **Prefetch 召回** | Qwen | **Qwen 3.6 Plus** + 质量监控 | 先用，定期检查召回相关性，不达标则降级到 DeepSeek |
| **Background Review** | Qwen | **Qwen 3.6 Plus** + 质量监控 | 同上 |
| **Session Memory** | Qwen | **Qwen 3.6 Plus** ✅ | 摘要为主，判断需求低，Qwen 完全胜任 |

---

### 🟡 设计细节（4个）

#### 细节1：三层独立缓存体系 L1/L2 未展开

**瑶光的处理**：**第一版不做独立缓存实现。**
- L1（文件解析缓存）：由 OS 文件系统天然缓存覆盖，开销可忽略
- L2（指令拼接缓存）：数据量小（层A 指令文件最多 4 个，总计 < 50KB），直接每次重建
- L3（system prompt 快照）：✅ 已设计（session 启动冻结，中途写不刷新，压缩才重建）
- 只有 L3 明确实现，L1/L2 遇到性能瓶颈再补

#### 细节2：MEMORY.md 与 index.md 双索引

**GLM 指出**：两个索引并存会出问题。

**瑶光的处理**：**第一版直接用 MEMORY.md 做索引**，不创建新的 index.md。等后期需要迁移时一次性切。

#### 细节3：onDelegation hook 与纯文本结果

**GLM 指出**：主代理拿到非结构化文本，怎么判断值得记？

**瑶光的处理**：采纳 GLM 建议的流程。
1. 子代理返回结果文本
2. **不额外调用 LLM**，直接存入 transcript（层C）
3. 由 Background Review（10轮阈值触发时）统一回顾，含子代理结果
4. Review 判断值得长期保留的内容 → 写入层B

#### 细节4：Token 预算的约束来源

**GLM 指出**：Qwen 零成本，预算限制什么？

**瑶光的确认**：约束来源是 Qwen 的 **API 速率限制（RPM/TPM）**，不是费用。目前先不加硬上限，实际体验中遇到限流再调。

---

## 二、修订版架构（v2.2 最终版）

```
主代理 (Main Agent)
│
├─ 记忆模块 (Memory Module, 主代理内模块, 非独立agent)
│ │
│ ├─ 层A: 指令记忆
│ │ ├─ 四层优先级加载 (全局→用户→项目→本地)
│ │ ├─ @include 递归(最多5层) + 条件规则(glob匹配) + 嵌套附件
│ │ └─ 注入: 双轨注入
│ │     ├─ 通道A(指令内容): 对话消息通道, 第一条user meta message
│ │     └─ 通道B(行为规范): system prompt 数组, 会话只算一次
│ │
│ ├─ 层B: 长期事实
│ │ ├─ 四类封闭分类: user / feedback / project / reference
│ │ ├─ 索引: 直接用 MEMORY.md 做主索引 (不另建 index.md)
│ │ ├─ 独立存储: 按类型分文件, 带 front matter 元数据
│ │ ├─ 召回: 异步 prefetch (Qwen, 不阻塞, 最多5篇)
│ │ ├─ 新鲜度: 自然语言年龄 + 超1天警告
│ │ ├─ 快照冻结: session启动冻结 → 中途写不刷新 → 压缩才重建
│ │ └─ 写入: 原子写 + threat scanning + 写入前重新读盘
│ │
│ ├─ 层C: 完整历史 (子代理运行轨迹)
│ │ ├─ 存储: SQLite + FTS5 (消息表含 tool_calls/cost/reasoning)
│ │ ├─ Session Search:
│ │ │   ├─ 空query: cheap mode (标题+时间, 无LLM)
│ │ │   ├─ 最多5 session, 自动排除当前链路
│ │ │   └─ 定向摘要 (面向当前query)
│ │ ├─ 召回注入: API call time injection, 不写回 transcript
│ │ ├─ Flash Memories: 压缩前抢注, 走 DeepSeek V4 Flash
│ │ ├─ 压缩即分支: Continuation Session with parent_session_id
│ │ └─ Session Memory: Qwen 渐进式笔记, 双阈值触发
│ │
│ ├─ 层D: 外部提供方 (占位)
│ │ └─ MemoryProvider 接口 (单活跃, 预留团队同步位)
│ │
│ ├─ 安全层 (跨层)
│ │ ├─ 写入前 threat scanning (prompt injection/角色劫持/密钥)
│ │ ├─ 原子写 (temp file + os rename)
│ │ └─ 写入前重新读盘 (吸收多进程并发变更)
│ │
│ └─ 成本控制 (跨层)
│     ├─ 后台低判断任务 → Qwen 3.6 Plus (零成本, 但受速率限制)
│     ├─ 关键时刻(Flash Memories) → DeepSeek V4 Flash (触发频率低, 成本可控)
│     └─ 速率超限时暂停后台任务, 保持核心读写
│
├─ 子代理 A ── 只能读: Phase 1 预注入, Phase 2 共享只读
├─ 子代理 B ── 无 store() 权限, 不能写记忆
│
└─ 通信: onDelegation hook → 子代理结果存 transcript
     (不自写记忆, 由 Background Review 统一提取)
```

---

## 三、交互协议（v2.2）

```
写入（仅主代理可写）：
  store(type, content, scope?)
    type: user|feedback|project|reference
    content: 记忆内容
    scope: global|project|local

读取：
  recall(query, context?)          → 主代理 + 子代理(通过预注入)
  search(query)                    → FTS5 全文搜索
  session_lookup(id)               → 某次运行轨迹
  recent_sessions(limit?)          → cheap mode (标题+时间戳)

删除：
  forget(query)                    → 标记过时或删除

压缩控制：
  flash_memories()                 → 触发 compression 前知识抢注 (DeepSeek)
  compress(session_id)             → 压缩=开分支, 不覆盖旧历史

后台管理：
  trigger_review()                 → 手动触发 Background Review (Qwen)
  status()                         → 缓存状态 / 未合并条目 / 速率限流
```

### 关键约束（完整版）

| # | 规则 | 来源 | 理由 |
|---|------|------|------|
| 1 | 子代理无 `store` 权限 | Hermes | 子代理上下文窄，容易把局部偶然当成长期事实 |
| 2 | 召回结果不写回 transcript | Hermes | 防自我污染：否则 session search 混淆真实历史和系统召回 |
| 3 | 写入走原子写 | Hermes | 防多 session 并发读空文件 |
| 4 | 写入前 threat scanning | Hermes | 记忆最终注入 system prompt，恶意内容永久污染 |
| 5 | 写入前重新读盘吸收并发变更 | Hermes | 防覆盖其他进程刚写入的内容 |
| 6 | 新内容当前 session 不生效（快照冻结） | Hermes | 保住 system prompt prefix cache 稳定 |
| 7 | 明确不存"代码可推导的内容" | Claude Code | 代码本身是最权威来源，存副本只会过时 |
| 8 | 子代理结果为纯文本 → 存 transcript → Review 统一提取 | 自研 | 避免每次子代理返回都调用 LLM |

---

## 四、实现路线图（完整版）

```
Phase 1 — 地基（P0，解决核心痛点 C+A）
 ├─ 1.1 层B: MEMORY.md → 四类分类 + 索引 + 独立文件
 ├─ 1.2 层A: 四层指令优先级加载 + 双轨注入
 ├─ 1.3 快照冻结: session启动冻结, 中途写不刷新, 压缩才重建
 ├─ 1.4 store() / recall() API 实现
 ├─ 1.5 prefetch 召回 (Qwen, 异步, 每轮)
 ├─ 1.6 子代理预注入 (spawn 时 recall → 注入 task)
 └─ 1.7 层C: SQLite + FTS5 + session search + 子代理结果写入

Phase 2 — 压缩安全网（P1，解决痛点 D+B）
 ├─ 2.1 Flash Memories (DeepSeek, 压缩前抢注)
 ├─ 2.2 Continuation Session (压缩即分支)
 └─ 2.3 Background Review (10轮阈值, Qwen, 异步)

Phase 3 — 质量提升（P2）
 └─ 3.1 Session Memory (渐进式笔记, 双阈值, Qwen)

Phase 4 — 离线整合（P3）
 └─ 4.1 Auto Dream (24h+5会话, 四阶段, 锁机制)
```

---

## 五、与现有系统的兼容性

| 现有文件 | 归宿 | 操作 |
|----------|------|------|
| `MEMORY.md` | 层B 主索引 | 保留，直接作为索引使用 |
| `memory/YYYY-MM-DD.md` | 主代理 daily log | 保留不动 |
| `memory/pending-memory.md` | 暂存池 | 保留不动 |
| `~/self-improving/` | 执行教训 → 逐步归入层B feedback-log | 逐步归入，不破坏原有 |
| `~/proactivity/` | 任务状态 → 由 session memory 支撑 | 保留不动 |

**原则**：全部向下兼容，不破坏任何现有数据。

---

## 六、来源对照表（完整版）

| 设计元素 | 来源 |
|----------|------|
| 四层指令优先级 + 条件规则 + @include | Claude Code |
| 四种记忆类型 + 明确不存什么 | Claude Code |
| 异步 prefetch 召回 + 轻量模型判断 | Claude Code |
| 新鲜度系统 (自然语言年龄 + 超1天警告) | Claude Code |
| Session Memory 渐进式笔记 + 双阈值 | Claude Code |
| Auto Dream 离线整合 + 四阶段 + 锁机制 | Claude Code |
| 子代理两回合策略 (并行读/写) | Claude Code |
| 双轨注入 (通道A/通道B) | Claude Code |
| 三层独立缓存体系 (L1/L2 简化, L3 实现) | Claude Code |
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
| 成本模型 + 后台任务分模型 (Low→Qwen, Critical→DeepSeek) | **自研（基于环境调研）** |
| 子代理 recall 两阶段 (预注入→共享只读) | **自研（基于 OpenClaw 通信机制）** |
| 子代理结果→transcript→Review 统一提取 | **自研** |
| 第一版模块, 第二版独立 agent | **GLM 评估建议 + 确认** |
| 个人 agent 砍掉团队同步 | **先生决策** |

---

*本方案为「瑶光—记忆系统子代理设计与构建」项目的 v2.2 修订草案，待 GLM 5.2 评估后进入 Phase 1 实现阶段。*
