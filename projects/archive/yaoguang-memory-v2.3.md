# 瑶光记忆系统 v2.3 — Phase 1 实现前问题答复

> GLM 最终评审通过 v2.2 架构后提出的 5 个 Phase 1 实现前置问题，现基于 OpenClaw 环境实际调研逐一答复。
>
> 构建日期：2026-07-09
> 状态：已答复，待 GLM 确认后可进入 Phase 1 实现

---

## 一、GLM 最终评审确认

| 维度 | 结果 |
|------|:----:|
| 架构级问题 | 3/3 已闭环 |
| 设计细节 | 4/4 已闭环 |
| 清理项 | 4 个（不阻塞实现） |
| 阻塞项 | 0 个 |
| **结论** | **✅ 架构通过，可进入实现阶段** |

### 4 个清理项的当前处理

| 清理项 | v2.3 状态 |
|--------|-----------|
| 清理1：层D 描述矛盾（"团队同步位"→"外部语义记忆后端"） | ✅ 已修正 |
| 清理2：缺少"turn"定义 | ✅ 明确为"1 turn = 1 次主代理完整 API 调用周期（含多步工具调用算 1 turn）" |
| 清理3：缺少压缩阈值定义 | ✅ 预警 800K / 压缩 900K，可配置参数 |
| 清理4：self-improving 迁移路径 | ✅ 第一版不动，Auto Dream 阶段自动归并 |

---

## 二、Phase 1 实现前的 5 个问题 — 详细答复

### Q1. 工具定义机制：如何实现 store() / recall() / search()？

**结论：三种可选路径，我建议两阶段方案。**

| 方案 | 复杂度 | 优缺点 |
|:----:|:------:|---------|
| **A. System Prompt + 现有工具** | ⭐ 最低 | 不需要任何构建或新代码。用现有 `read`/`write`/`edit`/`exec` 工具 + 系统 prompt 指引来实现记忆操作。Phase 1 推荐。 |
| **B. MCP Server** | ⭐⭐⭐ 中等 | 编写一个 Node.js MCP server，暴露 `store`/`recall`/`search`/`forget` 四个工具。通过 `mcp.servers` 配置注册。工具带完善 JSON schema，模型能更精确调用。Phase 2 推荐。 |
| **C. OpenClaw Plugin** | ⭐⭐⭐⭐⭐ 高 | 编写 OpenClaw 插件（`registerAgentTools`），注册自定义工具。功能最深入但需要插件 SDK 开发。暂不推荐。 |

**OpenClaw 的 MCP 配置格式**（已证实支持）：

```json5
{
  mcp: {
    servers: {
      "memory-server": {
        command: "node",
        args: ["/path/to/memory-server.mjs"],
        toolFilter: {
          include: ["store_*", "recall", "search", "forget"],
        },
      },
    },
  },
}
```

**我的建议：两阶段方案**

```
Phase 1 — System Prompt + 现有工具（快速落地）
  系统 prompt 指引 + read/write/exec：
    store    → write 写入记忆文件 → exec 更新 FTS5
    recall   → exec sqlite3 查询 FTS5
    search   → exec sqlite3 FTS5 全文搜索
    forget   → write 标记过时

Phase 2 — MCP Server（能力升级）
  可用 @modelcontextprotocol/sdk 构建命名 MCP server
  带 JSON schema 的标准化工具定义
  模型调用更精确，工具描述更完善
```

**Phase 1 的 System Prompt 指引示例**：

```
## 记忆模块

当前 session 中的记忆文件位于 ~/.openclaw/memory/。
- MEMORY.md: 长期记忆索引（200行/25KB上限）
- long-term/user-profile.md: 用户画像
- long-term/feedback-log.md: 纠正与确认
- long-term/project-context.md: 项目上下文
- long-term/references.md: 外部引用
- transcripts/sessions.db: SQLite FTS5 历史记录

写入记忆时使用 write/edit 工具。
查询历史时使用: exec sqlite3 ~/.openclaw/memory/transcripts/sessions.db "FTS5 QUERY"
```

---

### Q2. MEMORY.md 的内容结构

当前 MEMORY.md（5.8KB）的结构是**按主题分节 + 时间戳 + 标签**，不是扁平列表：

```
MEMORY.md
├─ 关于先生           (姓名/称呼/时区/环境/禁忌)
├─ 交互黄金法则        (4条: 真实性/安全/诚实反馈)
├─ 执行纪律            (表格: 5条阈值规则)
├─ 关键决策记录
│   ├─ 2026-06-09 Gateway 安全加固 [decision:gateway-security]
│   ├─ 2026-06-09 微信通道接入 [channel:weixin]
│   ├─ 2026-06-09 技能安装 [skills:self-improving+proactivity]
│   ├─ 2026-07-03 Workboard 插件启用 [decision:workboard]
│   ├─ 2026-06-13 四层记忆系统 [decision:memory-system]
│   ├─ 2026-06-14 Qwen 视觉模型 [decision:model-config]
│   └─ 2026-06-10 Embedding 迁移 [decision:embedding-provider]
├─ 信任与授权
├─ MEMORY.md 建设路线  (3阶段表格)
├─ 定期复盘            (周六日21:00-23:00)
├─ 已知优化点
└─ 关键配置参考
    └─ 微信 Cron 任务投递配置
```

**迁移评估**：现有结构天然适合四类分类。
- `关于先生` + `交互黄金法则` + `执行纪律` → **user** 类型
- `关键决策记录` → **feedback** 类型（决策本身既包含纠正也包含确认）
- `MEMORY.md 建设路线` + `定期复盘` → **project** 类型
- `关键配置参考` → **reference** 类型

**工作量**：低。不需要重写内容，只需要按类型分拆到对应文件 + 更新 MEMORY.md 为索引格式。

---

### Q3. AGENTS.md 注入机制

**OpenClaw 的 workspace 文件注入机制如下：**

```
Agent 启动时 →
  OpenClaw 读取 workspace 中的 bootstrap 文件：
    AGENTS.md、SOUL.md、USER.md、MEMORY.md、HEARTBEAT.md、IDENTITY.md
  →
  通过 `contextInjection` 配置控制注入策略：
    "always" (默认): 每次都注入
    "continuation-skip" (当前配置): 安全续接会话跳过，压缩/心跳后重建
    "never": 完全禁用
  →
  文件内容截断：
    maxFileChars: 20000（单文件上限）
    maxTotalChars: 60000（所有文件总计上限）
  →
  作为 "Workspace Files (injected)" 区块注入 system prompt
```

**当前主 session 的配置**：

```
contextInjection: "continuation-skip"
```

这意味着：
- 每次会话启动/重置时，MEMORY.md 等文件自动注入 system prompt
- 会话中途的续接对话（如长时间空闲后的续接）跳过注入，节省 token
- 压缩后重建上下文时会重新注入最新版本
- **文件大小限制允许 20KB/60KB**，当前 5.8KB 的 MEMORY.md 空间充裕

**对记忆架构的意义**：
- 层B 的长期事实已通过此机制自动注入，无需额外实现
- 层B 快照冻结对应的是"session 启动时读盘注入 → 中途写不刷新"
- contextInjection 压缩重建对应快照的失效触发条件

---

### Q4. sessions_spawn 的 task prompt 格式

**当前实际使用的是纯文本描述格式：**

```
// 实际调用的简化结构
sessions_spawn({
  task: "请完成以下任务：\n\n1. 分析 src/parser.ts 中的 parseDate 函数\n2. 检查它是否正确处理了 ISO 8601 格式\n3. 输出分析报告\n4. 如果发现 bug，请给出修复方案\n\n当前项目信息：\n- 项目目录：/home/ubuntu/.openclaw/workspace\n- 语言：TypeScript",
  mode: "run"   // 后台运行，不阻塞主流程
})
```

**字段说明**：
- `task`：纯文本，是子代理收到的第一条消息（相当于子代理的初始 prompt）
- `mode: "run"`：后台模式，子代理完成后自动通知主代理
- 没有结构化参数格式，没有任何 schema

**预注入的实现方式**：

```
Phase 1 的预注入实现：
  1. 主代理先调用 recall(task_desc) 得到相关记忆文本
  2. 拼接 task prompt：

  task: `请完成以下任务：\n\n${task_description}\n\n${task_detail}\n\n相关上下文记忆：\n${recall_results}\n\n注意：本任务执行过程中如果需要更多历史信息，可以 exec sqlite3 查询转录数据库。请不要修改记忆文件。`
```

**关于子代理 exec 读取转录库**：子代理默认拥有 exec 工具权限。通过主代理的 spawn 机制，子代理继承主的工作目录环境。在 Phase 2 的共享只读模式下，子代理可以通过 `exec sqlite3 ~/.openclaw/memory/transcripts/sessions.db "SELECT ..."` 读取 FTS5 数据。

---

### Q5. SQLite 数据库路径与权限

**建议路径**：

```
~/.openclaw/memory/transcripts/sessions.db
```

**路径分析**：

| 条件 | 状态 |
|------|:----:|
| 目录是否已存在 | ❌ `memory/` 目录尚未创建 |
| 子代理可读性 | ✅ 子代理继承工作环境，可以访问 `~/.openclaw/` 路径 |
| `workspace` 目录权限 | `drwx------ ubuntu netdev`（700，用户独占） |
| 文件系统空间 | Tencent Cloud Linux VM，空间充足 |
| sqlite3 是否已安装 | ⏳ 需要确认，但可以通过 `npx` 或包管理器安装 |

**子代理访问路径**：
- 子代理继承主的工作环境 `~/.openclaw/workspace`
- 子代理的 exec 工具可以执行任意 shell 命令，包括 `sqlite3`
- 路径 `~/.openclaw/memory/` 在主代理的 home 下，子代理以同一用户 (`ubuntu`) 运行，有权限访问

**安装依赖**（如果 sqlite3 未预装）：
```bash
# 检查是否已安装
which sqlite3
# 如果未安装
sudo apt-get install -y sqlite3
```

---

## 三、修正后的架构图（v2.3 最终版）

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
│ │ ├─ 索引: 直接用 MEMORY.md (不另建 index.md)
│ │ ├─ 文件结构:
│ │ │   ~/.openclaw/memory/
│ │ │   ├── MEMORY.md          ← 主索引 (现有文件, 沿用)
│ │ │   ├── long-term/
│ │ │   │   ├── user-profile.md
│ │ │   │   ├── feedback-log.md
│ │ │   │   ├── project-context.md
│ │ │   │   └── references.md
│ │ │   ├── pending/           ← 暂存池 (保留)
│ │ │   └── archived/          ← 已归档
│ │ ├─ 召回: 异步 prefetch (Qwen, 不阻塞, 最多5篇)
│ │ ├─ 新鲜度: 自然语言年龄 + 超1天警告
│ │ ├─ 快照冻结: session启动注入 → 中途写不刷新 → 压缩才重建
│ │ └─ 写入: 原子写 + threat scanning + 写入前重新读盘
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
│ │ └─ Session Memory: Qwen, 渐进式笔记, 双阈值
│ │
│ ├─ 层D: 外部提供方 (占位)
│ │ └─ MemoryProvider 接口 (单活跃, 预留外部语义记忆后端)
│ │     (已移除"团队同步"描述)
│ │
│ ├─ 安全层
│ │ ├─ 写入前 threat scanning
│ │ ├─ 原子写
│ │ └─ 写入前重新读盘吸收并发变更
│ │
│ └─ 成本控制
│     ├─ 低判断任务(L1/L2/Prefetch/Review) → Qwen 3.6 Plus
│     ├─ 关键时刻(Flash Memories) → DeepSeek V4 Flash
│     └─ 速率超限时暂停后台任务
│
├─ 子代理 A ── Phase 1: 预注入 (spawn 时 recall→注入 task)
│              Phase 2: 共享只读 (exec sqlite3 查询)
│              无 store() 权限
│
├─ 子代理 B ── (同上)
│
└─ 通信: onDelegation hook → 子代理结果存 transcript
     (不自写记忆, 由 Background Review 统一提取)
```

---

## 四、关键指标一览

| 指标 | 值 |
|------|:---:|
| Phase 1 实现路径 | System Prompt + 现有工具 (read/write/exec) |
| Phase 2 升级路径 | MCP Server (Node.js, @modelcontextprotocol/sdk) |
| 记忆存储 | `~/.openclaw/memory/` (700 权限, 同 workspace) |
| FTS5 路径 | `~/.openclaw/memory/transcripts/sessions.db` |
| 子代理预注入 | spawn 时 `task` 字符串拼接 |
| 子代理动态查询 | exec sqlite3（Phase 2） |
| Background Review 模型 | Qwen 3.6 Plus（零成本） |
| Flash Memories 模型 | DeepSeek V4 Flash（关键判断） |
| 压缩预警阈值 | 800K / 1M（可配置） |
| 压缩触发阈值 | 900K / 1M（可配置） |
| turn 定义 | 1 次主代理完整 API 调用周期 |

---

## 五、来源对照表

| 设计元素 | 来源 |
|----------|:----:|
| 四层指令优先级 + 条件规则 + @include | Claude Code |
| 四种记忆类型 + 明确不存什么 | Claude Code |
| 异步 prefetch 召回 + 轻量模型判断 | Claude Code |
| 新鲜度系统 | Claude Code |
| Session Memory 渐进式笔记 | Claude Code |
| Auto Dream 离线整合 | Claude Code |
| 子代理两回合策略 | Claude Code |
| 双轨注入 | Claude Code |
| 稳定事实 vs 完整历史硬拆分 | Hermes Agent |
| 外部 recall 不写回 transcript | Hermes Agent |
| System prompt 快照冻结 | Hermes Agent |
| Background Review + 10 轮阈值 | Hermes Agent |
| 子代理无 store 权限 | Hermes Agent |
| FTS5 + session search | Hermes Agent |
| Flash Memories | Hermes Agent |
| 压缩即分支 | Hermes Agent |
| 原子写 + threat scanning | Hermes Agent |
| MemoryProvider 接口 | Hermes Agent |
| 模块优先, 独立 agent 第二版 | GLM 5.2 评估建议 |
| 个人 agent 砍团队同步 | 先生决策 |
| 两阶段工具实现 (prompt→MCP) | 瑶光（环境调研） |
| 子代理 recall 两阶段 (预注入→只读) | 瑶光（环境调研） |
| 分模型策略 (Qwen→DeepSeek) | 瑶光 + GLM |
| 三层缓存简化 (L1/L2 缓建, L3 实现) | 瑶光（环境调研） |
| MEMORY.md 直接做索引，不另建 | 瑶光（尊重现有数据） |
| Phase 1 实现路线图 + 清理项 | GLM 5.2 三轮评审 |

---

*本方案为「瑶光—记忆系统子代理设计与构建」项目的 v2.3 最终设计草案，Phase 1 实现前置问题已全部答复。GLM 确认后可进入编码实现阶段。*
