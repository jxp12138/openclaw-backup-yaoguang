# 瑶光记忆系统 v2 — 整合方案

> 基于 Hermes Agent + Claude Code 两套记忆架构的优势提炼，融入瑶光（OpenClaw DeepSeek V4 Flash）现有记忆体系。
>
> 构建日期：2026-07-09
> 状态：待评估

---

## 一、核心变化：从「单机」到「主存分离」

### 现状问题

所有任务挤在主代理运行 → 上下文混乱 → 分配给子代理后记忆不互通 → 需要一个专门的记忆子代理来串联。

### 新架构

```
主代理 (Main)
│  保留：工作记忆 + system prompt 快照缓存
│  调记忆子代理时：query → 注入结果（不写回 transcript）
│
├─ 子代理 A   ── 仅读记忆，不写
├─ 子代理 B   ── 仅读记忆，不写
│
└─ 记忆子代理 (Mem)
    ├─ 层A: 指令记忆  ← Claude Code 四层优先级系统
    ├─ 层B: 长期事实  ← Hermes curated memory + Claude Code 四种类型
    ├─ 层C: 完整历史  ← Hermes FTS5 transcript + 子代理运行轨迹
    ├─ 层D: 外部提供方 ← Hermes 可插拔 provider 接口
    │
    └─ 后台守护
       ├─ Background Review   ← 两套合并
       ├─ Session Memory      ← Claude Code 渐进式笔记
       └─ Auto Dream          ← Claude Code 离线整合
```

---

## 二、每一层的详细设计

### 层A — 指令记忆

从 Claude Code 的四层 CLAUDE.md 优先级系统。启动子代理时按以下顺序加载指令文件，**后加载的优先级更高**：

| 优先级 | 路径 | 用途 |
|--------|------|------|
| 1（最低） | `~/.openclaw/memory/instructions.md` | 全局行为准则 |
| 2 | `~/.openclaw/memory/MEMORY.md` | 现有长期记忆 |
| 3 | `./.openclaw/memory.md` | 项目级约定（新） |
| 4（最高） | `./.openclaw/memory.local.md` | 本地覆盖（新） |

**加载方式**：从 CWD 向上遍历，收集所有指令文件后反转顺序加载。

**扩展机制**（从 Claude Code）：
- `@include` 递归包含（最多 5 层深度，循环检测）
- 条件规则：通过 front matter 的 `path` 字段指定规则仅在访问特定目录时生效（glob 匹配）
- 嵌套记忆附件：访问子目录文件时自动加载该目录链上的额外规则

---

### 层B — 长期事实

Claude Code 的四种类型 + Hermes 的"稳定事实"理念，替换现有纯文本 MEMORY.md。

#### 存储结构

```
~/.openclaw/memory/
├── index.md              ← 类似 memory.md 索引，200行/25KB上限
├── user-profile.md       ← 类型:user（用户画像、偏好）
├── feedback-log.md       ← 类型:feedback（纠正 + 确认）
├── project-context.md    ← 类型:project（不可从代码推导的上下文）
├── references.md         ← 类型:reference（外部链接：issue、面板、Slack）
├── pending/              ← 暂存池（现有，保留）
└── archived/             ← 已归档（过时条目移入）
```

#### 四种记忆类型（从 Claude Code）

| 类型 | 记什么 | 例子 |
|------|--------|------|
| **user** | 关于用户本人的 | 角色、目标、技能水平、工作习惯 |
| **feedback** | 用户对AI行为的纠正和确认 | 做错了要记，做对了也要记（防过度保守） |
| **project** | 不可从代码推导的项目上下文 | 截止日期、设计目标、团队约定 |
| **reference** | 外部系统的指针 | Linear issue 链接、GitHub 面板地址 |

#### 明确不存什么（从 Claude Code）

- 代码模式、架构分析、文件路径、Git 历史、调试方案
- 原因：**代码就是最权威的来源**，存副本会过时、产生矛盾
- 相对日期 → 转为绝对日期（"下周五" → "2026年7月10日"）

#### 召回方式（从 Claude Code 的 prefetch）

- 每轮对话开始时，异步用轻量模型判断哪些记忆相关（不阻塞主流程）
- 每个文件只读前 30 行的 front matter 提取描述信息
- **最多召回 5 篇**，已展示的过滤掉
- 工具文档压低优先级，避免污染
- 全新风度系统：自然语言描述年龄（"昨天"、"47天前"），超过一天附带"引用前请验证"警告

#### 写入约束（从 Hermes）

- 字符预算硬上限
- 原子写（temp file + os rename），防并发读空文件
- 写入前 threat scanning（prompt injection、角色劫持、密钥检测）
- 写入前重新读盘，吸收多进程并发变更

---

### 层C — 完整历史

从 Hermes 拿 FTS5 + session search 作为子代理运行轨迹。**长期事实和历史轨迹硬拆分**。

#### 存储结构

```
~/.openclaw/memory/transcripts/
├── sessions.db           ← SQLite + FTS5（Hermes 的 state.db 模式）
│     ├─ messages 表（含 tool_calls、cost、finish_reason、reasoning）
│     └─ FTS5 虚表（通过 trigger 与 messages 表同步）
├── {session-id}.json     ← 子代理完整运行轨迹
└── {session-id}/
    └── session-memory.md ← Claude Code 的渐进式绘画笔记
```

#### Session Search 流程（从 Hermes）

1. FTS5 关键词搜索 → 命中消息
2. 归并到各自 session → 读完整 transcript（含上下文片段）
3. 辅助模型做**定向摘要**（focused summarization，面向当前 query）
4. 结果**不写回 transcript**（防自我污染）

**克制设计**：
- 空 query → **cheap mode**，只返回标题+时间戳，无 LLM 成本
- 最多总结 **5 个 session**
- 自动**排除当前链路**：resolve child→parent session，再把当前会话排除

---

### 层D — 外部提供方（占位）

从 Hermes 的 MemoryProvider/MemoryManager 接口标准，留好可插拔接口：

- 可声明是否可用
- 可在 session 初始化时连接资源
- 可提供静态 system prompt block
- 可做 prefetch recall
- 可在 turn 结束后同步数据
- 可暴露自己的工具接口

**限制**（从 Hermes）：同一时间只允许一个外部 provider 生效，防工具表膨胀和召回冲突。

---

## 三、后台守护机制

### 3.1 Background Review（两套合并）

| 来源 | 机制 | 融合方案 |
|------|------|---------|
| Claude Code | 每轮后子代理 extract memories | 主代理每轮后异步 review |
| Hermes | 10轮无写入触发 background review | 阈值触发：连续 10 轮无写入启动 |
| 两者 | 防写入冲突 | 主代理手动写了 → 跳过本轮提取 |

**子代理 prompt 设计**（从 Claude Code）：
- 两回合策略：第一轮并行读所有文件，第二轮并行写所有文件
- 最多 5 轮，**禁止调查验证**（不许 grep 源码、不许 get log）
- 工具权限：可读任意文件，写操作**只限记忆目录**
- 不可执行命令、不可调 MCP、不可触发其他 agent

**Hermes 补充**：review fork 一个轻量子代理，沿用当前模型，在用户收到最终回复后异步跑，不抢注意力。

### 3.2 Session Memory（从 Claude Code）

子代理运行时，后台维护的一份**渐进式绘画笔记**，解决压缩时临时生成摘要丢失细节的问题。

```
session-memory.md 固定章节：
├─ 会话标题
├─ 当前工作状态
├─ 涉及的关键文件和函数
├─ 工作流步骤
└─ 遇到的错误和修正
```

**触发条件**：双阈值——上下文 token 数达最小值 + 自上次更新以来有足够新内容或工具调用。
**压缩时**：直接用已维护好的 session-memory.md，不自生成摘要。
**保留边界**：遵守 API 不变量——不切断 tool call/result 对、不切断 thinking block。

### 3.3 Auto Dream 离线整合（从 Claude Code）

对应记忆系统的"老化/压缩机制"。模拟人类复盘思维过程。

**双重门控**：
1. 至少距上次整合 **24 小时**
2. 期间至少有 **5 个不同会话**产生了新记忆

**四阶段流程**：

```
① Orient（定向探索）
   浏览记忆目录，查看现有文件、index.md 索引、重复或近似主题

② Gather（信息收集）
   查看近期日志，检查是否有与当前事实矛盾的旧记忆
   必要时窄搜索转入文件（只用精确搜索词）

③ Consolidate（整合）
   将新信号合并到已有主题文件，不创建近似副本
   相对日期转绝对日期
   被推翻的旧事实直接删除（不标注过时）

④ Prune（修剪索引）
   保持 index.md 在 200 行以内
   每行索引 ≤ 150 字符
   删陈旧指针、压缩冗长条目、解决矛盾
```

**锁机制**（从 Claude Code）：PID 文件 + CAS 竞争检测，防止多实例同时触发。
- 文件修改时间 = 上次整合时间
- 文件内容 = 持有进程 PID
- 写入自己 PID 后读回来验证，不一致则退让
- 出错回滚修改时间

---

## 四、记忆子代理交互协议

### 主代理 ↔ 记忆子代理 API

```
写入（仅主代理可写）：
  store(type, content, scope?)
    type: user|feedback|project|reference
    content: 记忆内容
    scope: 作用域（global|project|local）

读取（主代理 + 所有子代理可读）：
  recall(query, context?) → 最多5篇相关记忆
  search(query)            → FTS5 全文搜索历史
  session_lookup(id)      → 某次子代理运行轨迹

删除：
  forget(query)           → 标记过时或删除

后台管理：
  trigger_review()        → 手动触发 background review
  status()                → 缓存状态、未合并条目数
```

### 关键约束

1. **子代理无 `store` 权限** — 只能通过 `onDelegation` hook 回流给父级判断（从 Hermes）
2. **召回结果不写回 transcript** — 在 API call 边界注入 `memory context` 标记，不作为真实会话历史存储（从 Hermes）
3. **写入走原子写** — temp file + os rename（从 Hermes）
4. **写入前 threat scanning** — 防止 prompt injection 污染持久化层（从 Hermes）

---

## 五、与现有系统的兼容

| 现有文件 | 新系统中的归宿 | 操作 |
|----------|---------------|------|
| `MEMORY.md` | 保留，作为层B的**主索引**（兼容旧条目） | 保留不动 |
| `memory/YYYY-MM-DD.md` | 保留，作为主代理 daily log | 保留不动 |
| `memory/pending-memory.md` | 保留，暂存池 | 保留不动 |
| `~/self-improving/` | 保留，执行教训 → 按类型归入层B feedback-log | 逐步归入，不破坏原有 |
| `~/proactivity/` | 保留，任务状态 → 由 session memory 支撑 | 保留不动 |

**原则**：全部向下兼容，不破坏任何现有数据。

---

## 六、两套架构来源对照

| 设计元素 | 来源 |
|----------|------|
| 四层指令优先级系统 + 条件规则 + `@include` | Claude Code |
| 四种记忆类型 + 明确"不存什么" | Claude Code |
| 异步 prefetch 召回 + 轻量模型判断相关性 | Claude Code |
| 新鲜度系统（自然语言年龄 + 超1天警告） | Claude Code |
| Session memory 渐进式笔记 + 双阈值触发 | Claude Code |
| Auto dream 离线整合 + 四阶段 + 锁机制 | Claude Code |
| 子代理两回合策略（并行读/写） | Claude Code |
| 团队同步安全防护（symlink + 敏感数据审查） | Claude Code |
| 三层独立缓存体系 | Claude Code |
| 稳定事实 vs 完整历史硬拆分 | Hermes Agent |
| 外部署 recall 不写回 transcript（防自我污染） | Hermes Agent |
| System prompt 快照化 + session 级缓存 | Hermes Agent |
| Background review + 10 轮无写入阈值触发 | Hermes Agent |
| 子代理无 store 权限 + onDelegation hook | Hermes Agent |
| FTS5 + session search 克制设计 | Hermes Agent |
| 原子写 + threat scanning | Hermes Agent |
| 可插拔外部 MemoryProvider 接口 | Hermes Agent |

---

## 七、待决策事项

1. **子代理是否能直接读层B（长期事实）** — 还是全走主代理转接？
2. **Background review 的触发频率** — 每轮都跑还是 Hermes 式 10 轮阈值？
3. **Auto dream 实现优先级** — 第一版就做还是先跑通核心读写再补？
4. **记忆子代理的物理形态** — 作为独立 agent 还是主代理内的一个模块？
5. **SQLite FTS5 vs 文件系统索引** — 需要评估在 WSL2 环境下的性能

---

*本文档作为「瑶光—记忆系统子代理设计与构建」项目的设计草案，待 GLM 5.2 评估后迭代。*
