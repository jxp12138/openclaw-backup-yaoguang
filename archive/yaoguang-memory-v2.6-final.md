# 瑶光记忆系统 v2.6 — 最终落地方案

> 基于 v2.4 → v2.5 迭代 + GLM 三轮工程评审 + 实际运行 3 天发现的 7 个问题。
> 状态：架构+工程评审通过，可进入落地实施。
> 时间：2026-07-12
> 本文件为主要参考快照，供未来架构升级使用。

---

## 一、整体架构（不变）

```
主代理 (Main Agent)
│
├─ 记忆模块 (Memory Module, 主代理内模块, 非独立agent)
│ │
│ ├─ 层A: 指令记忆
│ │   └─ 四层优先级加载 (全局→用户→项目→本地)
│ │     └─ 注入: 依赖 contextInjection 单通道
│ │
│ ├─ 层B: 长期事实 (语义记忆)
│ │   ├─ 四类封闭分类: user / feedback / project / reference
│ │   ├─ 索引: MEMORY.md (常驻 contextInjection)
│ │   ├─ 文件: long-term/user-profile.md / feedback-log.md / project-context.md / references.md
│ │   ├─ 召回: Phase 1 主代理内联判断 + read 按需加载
│ │   ├─ 写入: memory_store.sh (脚本驱动, 写前备份)
│ │   └─ 快照冻结: contextInjection "continuation-skip" 框架自带
│ │
│ ├─ 层C: 完整历史 (情景记忆)
│ │   ├─ 存储: sessions.db (SQLite + FTS5 trigram)
│ │   ├─ 写入双策略:
│ │   │   ├─ flush: 每 ~5 轮写入原始对话消息 (session_flush.sh)
│ │   │   └─ snapshot: session 结束时写入摘要 (session_snapshot.sh)
│ │   ├─ 检索: FTS5 trigram + LIKE 兜底
│ │   └─ 生命周期: Flash Memories → 压缩分支 → Background Review → Auto Dream
│ │
│ ├─ 层D: 外部提供方 (占位)
│ │   └─ MemoryProvider 接口 (单活跃, 预留外部语义记忆后端)
│ │
│ ├─ 安全层
│ │   ├─ Phase 1: System Prompt 安全检查指引 + 写前备份
│ │   └─ Phase 2: 代码级 threat scanning (MCP Server)
│ │
│ └─ 成本控制
│       ├─ 低判断任务 → Qwen 3.6 Plus (零成本)
│       ├─ 关键时刻 → DeepSeek V4 Flash
│       └─ 速率超限时暂停后台任务
│
├─ 子代理 A/B — Phase 1: 预注入 (spawn 时主代理 recall → 注入 task, ≤500字符)
│               Phase 2: 共享只读 (exec sqlite3 查询 FTS5)
│               无 store() 权限
│
└─ 通信: onDelegation hook → 子代理结果存 transcript
     (不自写记忆, 由 Background Review 统一提取)
```

### 关键约束（不变）

| # | 规则 | 来源 | 理由 |
|---|------|:----:|------|
| 1 | 子代理无 `store` 权限 | Hermes | 上下文窄，易把局部偶然当成长期事实 |
| 2 | 召回结果不写回 transcript | Hermes | 防自我污染 |
| 3 | 新内容当前 session 不生效（快照冻结） | Hermes + framework | 保住 prefix cache 稳定 |
| 4 | 明确不存"代码可推导的内容" | Claude Code | 代码本身是最权威来源 |
| 5 | 子代理结果为纯文本 → 存 transcript → Review 统一提取 | 自研 | 避免每次子代理返回都调用 LLM |
| 6 | 层A 为静态指令，层B 为动态记忆，严格分离 | 自研 | 防角色混淆 |

### 相对于 v2.4 的关键变更

| 变更点 | v2.4 | v2.6 | 原因 |
|:------:|:----:|:----:|:------|
| FTS5 tokenizer | unicode61 | **trigram** | unicode61 不支持中文分词，已验证不可用 |
| Transcript 写入 | 纯 prompt 驱动 "每轮必做" | **flush + snapshot 双策略 + 脚本化** | 纯 prompt 驱动 3 天失效 |
| 层B 写入 | 靠 LLM 自觉 edit 文件 | **memory_store.sh 脚本（写前备份 + 统一格式 + 自动索引）** | 写前备份防崩溃污染，格式统一防止索引错乱 |
| 备份策略 | 无 | **cron 每日备份 + 7天轮换** | 单 VM 无冗余 |
| Background Review | 10 轮阈值，直接写入 long-term/ | **降为 5 条 + session_end 触发，写入 pending/ 待确认** | 10 轮太高从未触发；直接写入有噪音注入风险 |
| 子代理预注入 | 无体积控制 | **≤500 字符限制** | 自相矛盾：说子代理上下文窄但塞大量记忆 |
| 冲突检测 | 无 | **Review 检出矛盾 → 丢 pending/conflicts.md → 手动确认** | 先生偏好可能前后变化 |
| memory_store 路径映射 | 无 | **数组显式映射** | 链式 if 脆弱易错 |

---

## 二、脚本与工具

### 2.1 `scripts/session_flush.sh` — 核心：原始消息写入

```
功能：每 ~5 轮对话（或话题切换时），将最近几轮的对话原始消息写入 sessions.db
位置：~/.openclaw/workspace/scripts/session_flush.sh

核心逻辑：
  - 接收原始消息文本（非摘要）
  - 转义单引号 (sed "s/'/''/g")
  - 写入 sessions.db 的 messages 表
  - FTS5 触发器自动建立 trigram 索引
  - 写操作记录到 .heartbeat.log

执行时机：每完成 3-7 轮对话，或话题明显切换时
频率：每一轮 → 每 ~5 轮，降低了 80%
容错：正常结束和非正常结束（崩溃/断线）都至少有最近 5 轮的原始数据
```

### 2.2 `scripts/session_snapshot.sh` — 辅助：会话摘要

```
功能：session 结束时，将本次会话的整体摘要写入 sessions.db
位置：~/.openclaw/workspace/scripts/session_snapshot.sh

核心逻辑：
  - 接收会话摘要文本
  - 转义单引号
  - 写入 sessions.db（role = 'system', content = '[session_snapshot] ...'）
  - 作为 search 检索入口（摘要阅读比原文快）
  - 写操作记录到 .heartbeat.log

执行时机：每次对话自然结束时
注意：摘要仅为检索辅助，Background Review 的数据源是 flush 写入的原始消息
```

### 2.3 `scripts/memory_store.sh` — 层B 写入标准化

```
功能：将先生表达的偏好/决策/项目记录等写入 long-term/*.md，并同步更新 MEMORY.md 索引
位置：~/.openclaw/workspace/scripts/memory_store.sh

用法：./memory_store.sh <type> <content>
  type: user | feedback | project | reference

核心逻辑：
  - 写前备份：cp TARGET TARGET.bak（防崩溃污染）
  - 数组映射路径（防链式 if 错误）
  - 写入目标文件（含时间戳）
  - 同步更新 MEMORY.md 索引（≤150 字符摘要）
  - 写操作记录到 .heartbeat.log

相比 v2.4 的改进：
  - 不再靠 LLM 自觉 edit 文件，而是调脚本
  - 写前备份保底
  - 索引同步自动化
  - 格式统一可预测
```

### 2.4 `scripts/.heartbeat.log` — 执行状态追踪

```
功能：记录所有脚本的执行状态，方便每日/每周回顾
位置：~/.openclaw/workspace/scripts/.heartbeat.log（隐藏文件）

格式：
  2026-07-12 20:30:00 | flush | OK | session_xyz | 3 rows
  2026-07-12 21:00:00 | flush | FAIL | session_xyz | exit code 1

阅读方式：每天结束时 read 一次，快速确认所有机制是否正常运行
```

### 2.5 cron 定时备份

```bash
0 3 * * * tar -czf ~/memory-backup-$(date +\%Y\%m\%d).tar.gz \
  ~/.openclaw/workspace/MEMORY.md \
  ~/.openclaw/workspace/long-term/ \
  ~/.openclaw/workspace/transcripts/ \
  ~/.openclaw/workspace/memory/ \
  ~/.openclaw/workspace/scripts/ \
  2>/dev/null; \
  find ~/ -name "memory-backup-*.tar.gz" -mtime +7 -delete
```

---

## 三、修改的数据库对象

### 3.1 FTS5 表重建（关键修复）

```sql
-- 旧表（不可用）：tokenize='unicode61' → 不支持中文
-- 新表（可用）：tokenize='trigram' → 支持中文字串匹配

-- 执行顺序：
-- 1. 备份旧表
ALTER TABLE messages_fts RENAME TO messages_fts_old;

-- 2. 重建
CREATE VIRTUAL TABLE messages_fts USING fts5(
    content,
    content=messages,
    content_rowid=id,
    tokenize='trigram'
);

-- 3. 从已有数据重建索引
INSERT INTO messages_fts(rowid, content)
SELECT id, content FROM messages WHERE content IS NOT NULL;

-- 4. 重建触发器
DROP TRIGGER IF EXISTS messages_ai;
DROP TRIGGER IF EXISTS messages_ad;
DROP TRIGGER IF EXISTS messages_au;

CREATE TRIGGER messages_ai AFTER INSERT ON messages BEGIN
    INSERT INTO messages_fts(rowid, content) VALUES (new.id, new.content);
END;
CREATE TRIGGER messages_ad AFTER DELETE ON messages BEGIN
    INSERT INTO messages_fts(messages_fts, rowid, content) VALUES('delete', old.id, old.content);
END;
CREATE TRIGGER messages_au AFTER UPDATE ON messages BEGIN
    INSERT INTO messages_fts(messages_fts, rowid, content) VALUES('delete', old.id, old.content);
    INSERT INTO messages_fts(rowid, content) VALUES (new.id, new.content);
END;

-- 5. 删旧表
DROP TABLE messages_fts_old;
```

### 3.2 memory 索引重建

```bash
openclaw memory index --force --agent main
```

---

## 四、AGENTS.md 新增指引

在 AGENTS.md 的记忆系统章节中替换为以下内容：

```markdown
## Transcript 写入规则（v2.6）

两种写入方式，互补使用：

### 方式1：session_flush.sh（每隔 ~3-7 轮写入原始消息）
每完成 3-7 轮对话，或话题明显切换时，执行：
  exec ~/.openclaw/workspace/scripts/session_flush.sh "{最近几轮的关键原始消息}"
不需要精确计数。粗糙但持续的 flush > 精确但从不执行的 flush。
这是 Background Review 的主要数据源。

### 方式2：session_snapshot.sh（每次会话结束写入摘要）
每次对话自然结束时，执行：
  exec ~/.openclaw/workspace/scripts/session_snapshot.sh "{本次会话摘要}"
主要用作 search 检索的入口。

### 层B 写入（需要保存长期记忆时）
当先生表达了明确的偏好、决策或项目信息时，执行：
  exec ./scripts/memory_store.sh user "{具体内容}"
  exec ./scripts/memory_store.sh feedback "{具体内容}"
  exec ./scripts/memory_store.sh project "{具体内容}"
  exec ./scripts/memory_store.sh reference "{具体内容}"

### 搜索中文内容时
优先 FTS5 MATCH 搜索，如果搜不到，用 LIKE '%keyword%' 作为兜底。
```

---

## 五、落地方案执行顺序（今晚）

### Step 0 — 基础验证（~2分钟）

```bash
# 0.1 确认环境变量
echo $OPENCLAW_SESSION_ID

# 0.2 记录基线状态
sqlite3 ~/.openclaw/workspace/transcripts/sessions.db "SELECT COUNT(*) FROM messages;"
ls -lh ~/.openclaw/workspace/MEMORY.md
ls ~/.openclaw/workspace/long-term/

# 0.3 确认 AGENTS.md 已加载
# （我知道 transcript 写入规则：flush + snapshot 双策略）
```

### Step 1 — 脚本编写（~25分钟）

1.1 `scripts/session_flush.sh` — 写入原始消息
1.2 `scripts/session_snapshot.sh` — 写入会话摘要
1.3 `scripts/memory_store.sh` — 层B写入标准化（数组映射版）
1.4 全部脚本加单引号转义 + `.heartbeat.log` 记录

### Step 2 — 数据库修复（~13分钟）

2.1 `openclaw memory index --force`（~3分钟）
2.2 FTS5 trigram 重建（~10分钟）

### Step 3 — 配置（~5分钟）

3.1 cron 每日备份
3.2 AGENTS.md 更新（转录规则 + flush/snapshot/store 指引）

### Step 4 — 验证（~10分钟）

4.1 flush 调用 → 检查 sessions.db 有数据
4.2 FTS5 MATCH '记忆' → 有结果
4.3 memory_search('记忆') → 有结果
4.4 .heartbeat.log 有 OK 记录

### 总耗时估算

| 阶段 | 操作 | 耗时 |
|:----:|:----:|:----:|
| Step 0 | 基础验证 | 2 分钟 |
| Step 1 | 4 个脚本 | 25 分钟 |
| Step 2 | 2 个数据库修复 | 13 分钟 |
| Step 3 | 2 个配置 | 5 分钟 |
| Step 4 | 4 项验证 | 10 分钟 |
| **合计** | | **~55 分钟** |

---

## 六、GLM 三轮评审贡献摘要

| # | 评审点 | GLM 发现 | 瑶光之前的认知 | 是否采纳 |
|:-:|:------:|:--------:|:-------------:|:--------:|
| 1 | FTS5 中文分词 | 🔴 不可用，unicode61 不支持 | 不知道，工程盲点 | ✅ |
| 2 | 崩溃恢复 / 写前备份 | 🔴 无原子写 + 无备份 | 估低了风险 | ✅ |
| 3 | Transcript 写入保障 | 🟠 纯 prompt 驱动不可靠 | 3 天失效 | ✅ flush+snapshot |
| 4 | snapshot 数据粒度 | 🟠 摘要丢失细节，Review 无法提取 | 没评估副作用 | ✅ flush 补充 |
| 5 | 子代理预注入体积 | 🟠 自相矛盾（说窄但还是塞） | 没注意 | ✅ ≤500 字符 |
| 6 | memory_store 路径映射 | 🟡 链式 if 脆弱 | 写死了就没管 | ✅ 数组显式映射 |
| 7 | 记忆冲突检测 | 🟡 没有处理矛盾条目 | 盲区 | ✅ pending/conflicts |
| 8 | SQL 注入风险 | 🟢 单引号会断裂 | 知道但觉得不重要 | ✅ 转义处理 |
| 9 | SESSION_ID 验证 | 🟢 环境变量不一定存在 | 没验证 | ✅ Step 0 确认 |
| 10 | contextInjection 加载 | 🟢 可能没加载 AGENTS.md | 知道但不常见 | ✅ Step 0 确认 |
| 11 | 心跳日志 | 🟢 脚本状态要可追踪 | 没设计 | ✅ .heartbeat.log |
| 12 | Phase1→Phase2 迁移 | 🟡 数据格式无保障 | 没规划 | ⏳ Phase 2 再处理 |
| 13 | 20KB 天花板 | 🟡 长期积累后会触顶 | 合理但不到时候 | ⏳ 到了再处理 |
| 14 | 质量度量体系 | 🟢 无反馈闭环 | 先跑了再说 | ⏳ Phase 3 再处理 |

---

## 七、遗留项与后续规划

### 本周处理

| # | 事项 | 优先级 |
|:-:|:----:|:------:|
| 1 | Background Review 降门槛配置（5 条 + session_end 触发） | P1 |
| 2 | pending/ 目录创建 + conflicts.md 模板 | P1 |
| 3 | 子代理预注入首次验证（spawn 最小子代理） | P1 |
| 4 | 一周后复盘：.heartbeat.log 检查 + transcript 数据量 | P2 |

### 非本期处理

| # | 事项 | 理由 |
|:-:|:----:|:------|
| Session Memory 渐进式笔记 | 无压缩触发，数据量太小 |
| Flash Memories 抢注 | 无压缩事件 |
| Auto Dream 离线整合 | 数据量不够，无整合意义 |
| 向量数据库 | 当前规模完全不需要 |
| MCP Server | OpenClaw 框架不成熟 |
| Phase 1→Phase 2 迁移文档 | Phase 1 跑起来再说 |
| 20KB 天花板预案 | 目前 5.8KB，一年内到不了 |

---

## 八、落地宣誓

```
"粗糙但持续的机制 > 精确但从不执行的机制"

—— Phase 1 的信仰：
     不追求完美，追求可运行。
     先让水流起来，再逐步优化。
     任何设计如果让执行门槛变高，就是坏设计。
```

---

*本方案合并了 v2.4 架构设计 + v2.5 修复计划 + GLM 三轮工程评审的 14 项反馈。*
*是 v2.4 → v2.5 → v2.6 三次迭代的最终产物，不计划再出 v2.7。*
*讲完了，开始写代码。*
