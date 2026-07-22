# 瑶光—记忆系统子代理设计与构建

> 项目执行报告
>
> 项目周期：2026-07-09 11:40 → 2026-07-09 18:55
> 状态：Phase 1-3 落地完成，Phase 4 待数据积累
> 最终方案：v2.4（经 Hermes Agent + Claude Code + GLM 5.2 三轮评审）

---

## 一、项目背景

### 痛点

之前所有任务挤在主代理运行 → 上下文混乱 → 分配给子代理后记忆不互通 → 先生需要一个专门的记忆系统来串联主代理和各个子代理的记忆。

### 核心痛点排序

1. **C. 子代理之间记忆不互通** — 核心诉求，驱动项目的根本原因
2. **A. 跨会话记不住偏好，需重复说明**
3. **D. 上下文太长导致遗忘**
4. **B. 记不住上次改了什么**
5. **E. 信噪比下降**

### 方案来源

基于两套公开记忆架构的优势提炼：
- **Hermes Agent**（Nous Research）：边界清晰的分层记忆设计
- **Claude Code**（Anthropic）：系统化的记忆治理体系

经 **GLM 5.2** 三轮严格评估后迭代定型。

---

## 二、架构设计（五轮迭代）

```
v2.0 → v2.1 → v2.2 → v2.3 → v2.4
```

| 版本 | 核心贡献 | 评审 |
|:----:|---------|:----:|
| v2.0 | 初版框架，四层分层 + 三后台守护 | 方向正确 |
| v2.1 | 补上 Flash Memories / 压缩即分支 / 双轨注入 等 6 个缺失机制，解决 5 个设计矛盾 | 设计完整 |
| v2.2 | 解决子代理 recall 路径 / Session Reset 时序 / Qwen 判断力 3 个架构级问题 | 落地可行 |
| v2.3 | 答复 5 个实现前置问题，发现 contextInjection 天然实现快照冻结 | 路径清晰 |
| v2.4 | 明确 Phase 1 边界，整合全部成果 | ✅ 通过，可编码 |

### 最终架构

```
主代理 (Main Agent)
│
├─ 记忆模块 (Memory Module, 主代理内模块, 非独立agent)
│ │
│ ├─ 层A: 指令记忆 — 四层优先级 + contextInjection 单通道注入
│ ├─ 层B: 长期事实 — 四类封闭分类 (user/feedback/project/reference)
│ ├─ 层C: 完整历史 — SQLite + FTS5 + Session Search
│ ├─ 层D: 外部提供方 — 占位，预留接口
│ │
│ └─ 后台守护
│     ├─ Background Review (10轮阈值触发)
│     ├─ Flash Memories (900K tokens 压缩前抢注)
│     ├─ Continuation Session (压缩即分支)
│     ├─ Session Memory (渐进式笔记)
│     └─ Auto Dream (离线整合, Phase 4)
│
├─ 子代理 A — Phase 1 预注入, Phase 2 共享只读
├─ 子代理 B — 无 store() 权限
│
└─ 关键约束
    ├─ 子代理不自写记忆 (onDelegation 回流)
    ├─ 召回结果不写回 transcript (防自我污染)
    ├─ 新内容当前 session 不生效 (快照冻结)
    └─ 代码可推导的不存
```

---

## 三、实施完成情况

### Phase 1：地基（P0）✅ 全部完成

| 模块 | 实现方式 | 落地物 |
|------|---------|--------|
| MEMORY.md 四类分拆 | 手动编辑 | `workspace/MEMORY.md` (1.8KB，索引格式) |
| long-term/ 目录 + 四类文件 | 创建 | `user-profile.md` / `feedback-log.md` / `project-context.md` / `references.md` |
| AGENTS.md 记忆操作指引 | 写入 | store/recall/search/forget/每轮必做/spawn规范全部录入 |
| SQLite + FTS5 数据库 | exec 创建 | `transcripts/sessions.db` (36KB，含 sessions / messages / FTS5 表) |
| daily log | 手动 | `memory/2026-07-09.md` |

**测试结果**：store / recall / search / transcript / turn counter 全部通过。

### Phase 2：压缩安全网（P1）✅ 全部就绪

| 模块 | 实现方式 | 落地物 |
|------|---------|--------|
| Background Review | AGENTS.md 指引 + turn counter + 模板 | `AGENTS.md` 章节 + `.memory/review-prompt.md` |
| Flash Memories | AGENTS.md 行为规范 | 接近 900K tokens 时触发，走 DeepSeek |
| Continuation Session | DB 端 + AGENTS.md 规范 | sessions 表已支持 parent_session_id |
| 子代理共享只读 | AGENTS.md 规范 | Phase 2 时通过 exec sqlite3 查询 |

### Phase 3：质量提升（P2）✅ 全部就绪

| 模块 | 实现方式 | 落地物 |
|------|---------|--------|
| Session Memory | AGENTS.md + 文件 | `.memory/session-memory.md` (已维护) |

### Phase 4：离线整合（P3）⏳ 待数据积累

| 模块 | 状态 | 理由 |
|------|:----:|------|
| Auto Dream | ⏳ 待做 | 需要积累足够多的新记忆后才跑整合 |

---

## 四、落地文件清单

```
~/.openclaw/workspace/
├── MEMORY.md                    (1.8KB)  ← 层B 索引（contextInjection 常驻）
├── AGENTS.md                    (16KB)   ← 含完整记忆系统指引
├── long-term/                             ← 层B 四类记忆文件
│   ├── user-profile.md          (1.3KB)  ← 用户画像 + 交互原则
│   ├── feedback-log.md          (3.3KB)  ← 8条关键决策记录
│   ├── project-context.md       (1.3KB)  ← 建设路线 + 活跃项目
│   └── references.md            (0.9KB)  ← 配置参考 + 链接
├── .memory/                               ← 记忆模块内部文件
│   ├── session-memory.md        (1.2KB)  ← 当前会话渐进笔记
│   └── review-prompt.md         (1.3KB)  ← Background Review 模板
├── transcripts/
│   └── sessions.db              (36KB)   ← 层C 完整历史（SQLite + FTS5）
└── memory/                                ← daily log
    ├── 2026-07-09.md            (0.4KB)  ← 今日记录
    ├── 2026-06-xx.md            (5篇)    ← 历史日志
    └── pending-memory.md        (0.3KB)  ← 暂存池
```

---

## 五、来源对照

| 设计元素 | 来源 |
|----------|:----:|
| 四层指令优先级 + 条件规则 + @include | Claude Code |
| 四种记忆类型 + 明确不存什么 | Claude Code |
| 异步 prefetch 召回 | Claude Code |
| 新鲜度系统 | Claude Code |
| Session Memory 渐进式笔记 | Claude Code |
| Auto Dream 离线整合 | Claude Code |
| 双轨注入 | Claude Code |
| 稳定事实 vs 完整历史硬拆分 | Hermes Agent |
| 外部 recall 不写回 transcript | Hermes Agent |
| System prompt 快照冻结 → 框架自带 | Hermes Agent → contextInjection |
| Background Review + 10 轮阈值 | Hermes Agent |
| 子代理无 store 权限 | Hermes Agent |
| Flash Memories 压缩前抢注 | Hermes Agent |
| 压缩即分支 | Hermes Agent |
| 原子写 + threat scanning | Hermes Agent |
| 分模型策略 (Low→Qwen, Critical→DeepSeek) | 自研（环境调研） |
| 模块优先, 独立 agent 第二版 | GLM 5.2 评估 |
| 个人 agent 砍团队同步 | 先生决策 |

---

## 六、已知风险

| 风险 | 等级 | 缓解措施 |
|------|:----:|---------|
| transcript 写入依赖模型自觉性 | 🟡 中 | Phase 2 升级 MCP Server 后自动执行 |
| FTS5 中文分词有限 | 🟢 低 | AGENTS.md 已配置中文用 LIKE 兜底 |
| Flash Memories 依赖手动监测 contextWindow | 🟢 低 | session_status 可实时查看 |

---

## 七、下一步

### 近期（2026-07-10）
- **地图子代理构建** — 先生指定的下一个项目
- 体验完整的 store → recall → spawn 预注入链路

### 中期（积累数据后）
- **Phase 4: Auto Dream** — 离线整合，清理合并，更新索引
- **Phase 2.5: MCP Server** — 代码级自动化 transcript / review

---

*这是我为先生执行的第一个落地项目。从上午 11:40 概念讨论到下午 18:55 全部跑通，历时约 7 小时。感谢先生一路的信任和推进。*
