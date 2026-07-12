# 瑶光记忆系统 v2.5 — 修复方案

> 基于 v2.4 落地三个月后的实际运行问题 + GLM 两轮评审反馈。
> 构建日期：2026-07-12
> 心智模式：先修好能走的路，再考虑跑。

---

## 一、根因分析

实际遇到的所有 7 个问题，根因只有三个：

```
问题                                       根因
───────────────────────────────────────────
1. Transcript 停了                         → ① 执行纪律失效（最核心）
2. memory_search 坏了                      → ② 工程盲点（embedding 迁移未重建索引）
3. FTS5 中文搜不到                         → ③ 工程盲点（默认 tokenizer 不支持中文）
4. Background Review 一次没触发             → ① 执行纪律失效 + ① transcript 为空自然触不了
5. 7/9 后无 daily note                     → ① 执行纪律失效
6. Session Memory / Flash Memories 没用过  → ① 执行纪律失效
7. 子代理预注入未验证                       → ① 先生没继续推 + 我也没有主动催

总结：三个根因中，① 是最大问题，②③ 是具体工程点。
```

**执行纪律失效的原因：** 方案设计了"每轮必做"，但它是靠我在 prompt 指引中的自觉性来保证的，没有技术层面的强制执行或提醒机制。三天不写，惯性就断了。

**核心改进方向：** 让记忆系统从"靠瑶光自觉"过渡到"有自动保障 + 最低执行门槛"。

---

## 二、整体修复路线

```
Phase 1 Fix（今晚 ~1小时）—— 恢复基础设施
├── 1.1 重建 memory 索引（3分钟的命令）
├── 1.2 修复 FTS5 中文分词（10分钟改表）
├── 1.3 写前备份 + 定时备份 cron（5分钟）
└── 1.4 最小写入脚本（15分钟）

Phase 2 Fix（本周）—— 让机制真正跑起来
├── 2.1 修复 Background Review（降低门槛）
├── 2.2 子代理预注入体积限制 + 首次验证
├── 2.3 pending/ TTL + 清理规则
└── 2.4 冲突检测（Review 时自动比对）

Phase 3（长期，不急）—— 扩容与度量
├── 3.1 MEMORY.md 20KB 预案（高频/低频拆分）
├── 3.2 Phase 1→Phase 2 迁移路径文档
├── 3.3 记忆质量度量体系（跑起来再谈）
└── 3.4 Auto Dream / Flash Memories / Session Memory（按需启用）
```

---

## 三、Phase 1 Fix — 今晚修复清单 (~1小时)

### 1.1 重建 memory 索引（3分钟）

```bash
openclaw memory index --force
```

**原因：** embedding provider 从 OpenAI 迁移到 GitHub Copilot 后索引 metadata 不匹配，语义搜索完全不可用。重建后立刻恢复层 B 的 semantic recall。

**验证方法：** 重建后调 `memory_search(query="记忆系统")` 确认返回结果。

---

### 1.2 修复 FTS5 中文分词（10分钟）

**方案：** 从 unicode61 tokenizer 切换到 **trigram tokenizer**。

trigram 将文本切为连续 3 字符的子串。对中文效果：
- "瑶光记忆系统" → "瑶光记" "光记忆" "记忆系" "忆系统"
- 搜索"记忆" → 匹配"光记忆"、"记忆系"等含"记忆"的 trigram

```sql
-- 1. 备份旧 FTS 表
ALTER TABLE messages_fts RENAME TO messages_fts_old;

-- 2. 用 trigram 重建（trigram 原生支持 CJK 子串匹配）
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

**验证方法：**
```sql
SELECT id, substr(content,1,60) FROM messages
WHERE rowid IN (SELECT rowid FROM messages_fts WHERE messages_fts MATCH '记忆');
```
应返回之前 MATCH 搜不到的内容。

**兜底方案：** 如果 trigram 效果不满意（短词搜不到），退回 `LIKE` 搜索作为层 C 主搜索方式，FTS5 仅做英文/代码搜索。

---

### 1.3 写前备份 + 定时备份（5分钟）

**写前备份**（配合 1.4 的脚本自动执行）：
```bash
# 写入前自动备份
cp ~/.openclaw/workspace/long-term/*.md ~/.openclaw/workspace/long-term/*.md.bak 2>/dev/null
```

**定时备份（cron，每天 03:00 自动执行）：**
```bash
0 3 * * * tar -czf ~/memory-backup-$(date +\%Y\%m\%d).tar.gz ~/.openclaw/workspace/MEMORY.md ~/.openclaw/workspace/long-term/ ~/.openclaw/workspace/transcripts/ ~/.openclaw/workspace/memory/ 2>/dev/null; find ~/ -name "memory-backup-*.tar.gz" -mtime +7 -delete
```

---

### 1.4 最小写入脚本（15分钟）

`~/.openclaw/workspace/scripts/memory_store.sh`：

```bash
#!/bin/bash
# 记忆写入脚本 — 层B 长期事实写入 + 写前备份 + 索引同步
# Usage: ./memory_store.sh <type> <content>
#   type: user | feedback | project | reference

if [ $# -lt 2 ]; then
    echo "Usage: $0 <type> <content>"
    echo "  type: user | feedback | project | reference"
    exit 1
fi

TYPE="$1"
shift
CONTENT="$*"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
WORKSPACE=~/.openclaw/workspace
LONGBASE="$WORKSPACE/long-term"
INDEX="$WORKSPACE/MEMORY.md"

case "$TYPE" in
    user|feedback|project|reference)
        TARGET="$LONGBASE/${TYPE}-profile.md"
        [ "$TYPE" = "feedback" ] && TARGET="$LONGBASE/${TYPE}-log.md"
        [ "$TYPE" = "project" ] && TARGET="$LONGBASE/${TYPE}-context.md"
        [ "$TYPE" = "reference" ] && TARGET="$LONGBASE/${TYPE}s.md"
        ;;
    *)
        echo "Error: type must be user|feedback|project|reference"
        exit 1
        ;;
esac

# 写前备份
cp "$TARGET" "${TARGET}.bak" 2>/dev/null || true

# 写入目标文件
echo "" >> "$TARGET"
echo "### $TIMESTAMP" >> "$TARGET"
echo "$CONTENT" >> "$TARGET"

# 更新索引（只更新摘要行，保证不超过 150 字符）
SHORT="${CONTENT:0:120}"
REL_PATH="$(basename "$TARGET")"
echo "| $TIMESTAMP | $TYPE | $SHORT | $REL_PATH |" >> "$INDEX"

echo "Written to $TARGET"
```

**执行方式：** 我（瑶光）每次要写层B记忆时，不再自己 `edit` 文件，而是调 `exec ./scripts/memory_store.sh user "用户偏好XXX"`。这样自动保证了：
- 写前备份
- 统一格式
- 索引同步
- 减少 LLM 格式错误的概率

---

## 四、Phase 2 Fix — 本周修复清单

### 2.1 降低 Background Review 门槛

**当前问题：** 10 轮阈值的 Background Review 从未触发。原因是：
1. Transcript 都没写，触发不了
2. 即使用了三四天，每 session 轮数也不一定到 10

**修复方案：**

```
条件改为：transcript 中新增 >= 5 条消息 或 手动调用 trigger_review()
```

不用等 10 轮，5 条新消息就触发一轮 Review。同时增加一条启发式规则：每次 session 结束时（检测到 session_end 或对话中断 > 30min），自动触发一次 Review。

**Review 输出位置调整：** Qwen Review 的结果不直接写 long-term/，改为写：

```
~/.openclaw/workspace/long-term/pending/review-queue.md
```

下次 session 开始时，contextInjection 会注入这个 pending 列表，由主代理（我）内联判断后确认是否移入 long-term/。

---

### 2.2 子代理预注入体积限制

**当前漏洞：** 方案说子代理"上下文窄"所以不给 store，但预注入时没有限制注入量，可能反而把子代理的上下文撑爆。

**修复：** spawn 子代理时，注入的记忆不超过 **500 字符**（约 250 汉字）：

```
主代理 recall → 筛选最相关的前 3-5 条记忆
→ 拼接时字符数 <= 500
→ 如果超过，按关联度截断，保留最相关的
→ 拼接到 task prompt 末尾
```

**验证：** 今晚 Phase 1 修复后，下一轮会话中 spawn 一个最小的子代理（如"查一下 systemctl status"），看预注入是否正常工作。

---

### 2.3 pending/ TTL + 清理规则

7 天自动过期标记：

```
pending/ 中超过 7 天的条目：
  自动标记为"已过期（未确认）" 
  移入 archived/ 或删除
```

在 Background Review 脚本或独立 cron 中执行清理检查。

---

### 2.4 冲突检测

**思路：** Background Review 检测到与现有 MEMORY.md 条目矛盾的内容时，不自动写入，不自动覆盖，而是：

```
1. 检出矛盾 → 同时保留新旧两条
2. 标记为 "conflict: [topic]" 
3. 写入 pending/conflicts.md
4. 手动确认
```

这个比直接合并或覆盖安全。我会在我手动确认时处理冲突。

---

## 五、不做的事情（保留到 Phase 3+）

| 事项 | 理由 |
|------|------|
| Session Memory 渐进式笔记 | 目前单 session 时长不足以触发双阈值 |
| Flash Memories 抢注 | 没有压缩事件发生，抢注无从谈起 |
| Auto Dream 离线整合 | 数据量太小（transcript 才 9 条），无整合意义 |
| 向量数据库 | 数据量远不到需要向量检索的程度 |
| 质量度量体系 | 无实际运行数据可度量，强制做是数字游戏 |
| MCP Server | OpenClaw 框架的 MCP 支持还不成熟 |

**核心原则：先跑起来，跑出问题再修。** 现在最大的问题不是"缺什么功能"，而是"已有的功能没有在跑"。

---

## 六、执行计划

### 今晚（Phase 1 Fix，~1小时）

```
[立即执行]
 1.1 openclaw memory index --force         → 恢复 semantic recall
 1.2 重建 FTS5 表，trigram tokenizer        → 恢复中文搜索
 1.3 配置 cron 定时备份                      → 防数据丢失
 1.4 创建 memory_store.sh                    → 标准化写入

[之后恢复执行纪律]
 - 每轮回复后 → 写 transcript（INSERT INTO messages）
 - 每天结束 → 写 daily note
 - 有记忆需要保存 → 调 memory_store.sh
```

### 本周

```
 - 配置 Background Review 降门槛（5 条触发 + session_end 触发）
 - 子代理预注入 + 首次验证
 - 确认 pending/ 清理规则
 - 创建 ~/.openclaw/workspace/long-term/pending/ 目录
```

---

*本方案为 v2.4 落地问题的修复计划。核心思路：先修路，再跑车，不修赛车。*
