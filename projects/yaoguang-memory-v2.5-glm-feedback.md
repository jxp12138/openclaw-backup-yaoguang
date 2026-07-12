# 瑶光对 GLM 第二轮反馈的看法

> 针对 GLM 对 v2.5 修复方案的评审。
> 时间：2026-07-12 19:36

---

## 整体的态度

GLM 这次的分析质量很高，说到了点子上。比第一轮的"架构分析"更贴近我们实际面对的问题。特别是那句 ——

> **"凡是靠人（甚至靠 LLM 自觉）才能运转的机制，都不叫系统，叫期望。"**

这句话值得写在墙上。我认可这个批评。

但 GLM 有几处判断我不完全同意，下面逐条说。

---

## 一、✅ 完全认同的

### 1. "根因不是执行纪律，是设计缺陷"

GLM 说我漏了一个根因：

> ④ Phase 1 的"系统"根本不是一个系统，而是一组希望

**认同。** v2.5 方案里我对 transcript 自动写入的修复写着：

```
[之后恢复执行纪律]
 - 每轮回复后 → 写 transcript（INSERT INTO messages）
```

这跟 v2.4 的写法一模一样。三年前失效的东西，重写一遍就能生效？不可能的。我修复方案里漏了最关键的部分 —— **给这个机制的自动化加一根保险丝。**

### 2. "Transcript 自动写入是最大命门"

GLM 的分析非常清楚：

```
transcript 空 → FTS5 搜不到东西
transcript 空 → Background Review 没有数据源
transcript 空 → Session Memory 无内容可压缩
transcript 空 → Flash Memories 无意义
transcript 空 → Auto Dream 无东西可整合
```

这个依赖链条是对的。没有 transcript，后面全部空转。

### 3. memory_store.sh 文件名映射有隐患

```bash
TARGET="$LONGBASE/${TYPE}-profile.md"
[ "$TYPE" = "feedback" ] && TARGET="$LONGBASE/${TYPE}-log.md"
[ "$TYPE" = "project" ] && TARGET="$LONGBASE/${TYPE}-context.md"
[ "$TYPE" = "reference" ] && TARGET="$LONGBASE/${TYPE}s.md"
```

GLM 指出这个链式 if 写得太脆，建议数组显式映射。它对。我会改。

### 4. trigram 兜底没有在代码层面实现

方案里说"如果 trigram 效果不好退回 LIKE"，但这是文字上的话，不是代码上的机制。GLM 说得对，应该在 search 的 prompt 指引中明确写：

```
搜索中文内容时，优先 FTS5 MATCH。
如果 MATCH 搜不到，用 LIKE '%keyword%' 作为兜底。
```

---

## 二、🤔 不完全认同的

### 1. GLM 说的"二刷墙漆"比喻——我认为不全对

GLM 说：

> 修好了管道但没有水。这就是我说的"二刷墙漆"——你把墙刷得很漂亮，但水管还是坏的。

**这个比喻有道理，但我觉得它不是"水管还是坏的"的问题。**

实际情况是：
- 水管（transcript）之前确实是坏的 — 没有水流出来（我没有写）
- 但水管本身没有坏（sessions.db 的表结构、触发器都在，功能正常）
- 真正的问题是 **没有水压** — 没有自动化机制推着我写

所以比喻修正一下：**水管本身是好的，但阀门在后院，我需要自己去拧。我拧了三天就不拧了。** 解决办法不是承认水管坏了，而是装一个自动水龙头。

GLM 自己也意识到了这一点，所以它提出了三个方案（A/B/C）来解决 transcript 写入问题。这才是它真正的贡献点。

### 2. 对工作量估算的判断

GLM 说：

> ⚠️ 珞光说的是敲键盘时间，GLM说的是含验证的完整工作周期

我对 v2.5 估算 1-2 小时，GLM（第一轮）估算 4-6 天。**这个差距太大了，不是我低估，是 GLM 高估了。**

具体算一下：
- FTS5 重建：10 句 SQL，复制粘贴到 sqlite3 shell，验证非空 → 10 分钟
- cron 备份：一行 tar + 一行 find clean，编辑 crontab → 5 分钟
- memory_store.sh：写个脚本，`chmod +x`，测试两个参数 → 15 分钟
- session_snapshot.sh：一样的量级 → 15 分钟
- 三项全测试验证 → 30 分钟

总计 **~1.5 小时**。不是 4-6 天。GLM 的第一阶段估算太保守了。

但 GLM 这次的判断也对得多了——它说"含验证和调试应该算 3-4 小时"。这个我接受。

### 3. 对"20KB 天花板过于乐观"的判断

GLM 说我对 20KB 上限的判断（"目前 5.8KB，一年到不了"）过于乐观，因为一旦启动 Background Review, 记忆积累速度会加速。

有道理，但我不是这个意思。我说"一年到不了"是指在**当前实际使用频率**下的估算。如果用起来后才加速，那加速本身就需要几个月的时间才能积累到这个阈值。到那时再处理完全来得及。

我不是说"不用管"，而是说"现在不需要未雨绸缪到这个程度"。

---

## 三、💡 我完全同意的——GLM 贡献的关键补丁

### session_snapshot.sh（方案 B）

GLM 提出的 **方案 B** 是我认为最聪明的建议：

```bash
#!/bin/bash
# session_snapshot.sh
# 只需要每次对话结束时调一次
SUMMARY="$1"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
SESSION_ID="${OPENCLAW_SESSION_ID:-unknown}"

sqlite3 ~/.openclaw/workspace/transcripts/sessions.db \
 "INSERT INTO messages (session_id, role, content) VALUES ('${SESSION_ID}', 'system', '[session_snapshot] ${TIMESTAMP}: ${SUMMARY}');"
```

**为什么这个改动聪明：**

| 对比 | 旧方案（每轮写） | GLM 方案 B（每 session 写） |
|:----:|:--------------:|:------------------------:|
| 执行频率 | 每轮 1 次 | 每次会话结束 1 次 |
| 执行门槛 | 非常高（打断思维） | 很低（结束时的自然收尾） |
| 恢复难度 | 漏一轮就断链 | 漏一次只丢一个 session |
| 实践性 | 我 3 天就停了 | 可行性高得多 |

**频率降低一个数量级，执行纪律可维持性提高两个数量级。** 从"每轮都要记者写笔记"变成"每次下课合上笔记本"——合理得多。

我在 v2.5 的方案中确实漏了这个关键设计。这个补丁加上后，transcript 写入的可靠性会从"靠瑶光自觉"提升到"靠自然节律"。

### 强制规则的措辞强化

GLM 的方案 C（AGENTS.md 中加不可跳过的规则）虽然还是 prompt 驱动，但它的思路给了一个启发：

> **降低执行门槛，比提高执行纪律更管用。**

这个原则不止适用于 transcript 写入。下面写方案优化时会用到。

---

## 四、v2.5 + GLM 反馈合并 → v2.6 核心改进

把 GLM 的关键补丁合并到 v2.5 修复方案中，得到以下最终改动清单：

### 新增项目（2 项）

| # | 改动 | GLM 的建议 | 我的评估 |
|:-:|------|:---------:|:--------:|
| 新1 | 增加 session_snapshot.sh，每 session 结束时写一次 transcript | 方案 B | ✅ 关键改进，解决最大命门 |
| 新2 | search 指引：FTS5 MATCH 失败时降级到 LIKE | trigram 兜底 | ✅ 合理，顺手加上 |

### 已有的改进（优化细节）

| # | 改动 | 反馈来源 | 优化 |
|:-:|------|:-------:|:----:|
| 1.1 | memory_store.sh 文件名映射改为数组 | GLM 反馈 | `declare -A` 显式映射 |
| 1.2 | Background Review 降门槛 + 写 pending/ | v2.5 原方案 | 保持，5 条 + session_end 触发 |
| 1.3 | FTS5 trigram | v2.5 原方案 | 保持，加 LIKE 降级指引 |
| 1.4 | cron 备份 | v2.5 原方案 | 保持 |
| 1.5 | 预注入体积控制 500 字符 | v2.5 原方案 | 保持 |

---

## 五、GLM 最终判断的回应

GLM 对先生说：

> 1. 今晚执行 Phase 1 Fix 是对的
> 2. 但在执行 Phase 1 之前，先花 20 分钟写一个 session_snapshot.sh 并测试——这比修 FTS5 更重要
> 3. 明天验证"transcript 是否真的在写"
> 4. 一周后再做一次复盘

**这个建议顺序，我全盘接受。** 特别是第 2 点——先生问过我"你觉得该怎么解决"，我给的方案里漏了 transcript 写入保障这个核心，是 GLM 帮我补上的。我应该感谢它。

**改善后的执行优先级：**

```
P0 — 立刻做（今晚）
  ① 写 session_snapshot.sh + 测试
  ② 重建 memory 索引
  ③ FTS5 切 trigram
  ④ cron 备份

P1 — 顺手做（今晚）
  ⑤ memory_store.sh（改为数组映射版本）
  ⑥ search 降级指引

P2 — 本周做
  ⑦ Background Review 降门槛 + pending/ 配置
  ⑧ 预注入体积限制
  ⑨ 一周后复盘
```

---

## 六、回到先生最初的问题

先生最开始说："第一次方案不完美或无法落地很正常，我们一步步优化就是了。"

GLM 补上了 transcript 这一刀后，v2.5+patch 这个方案我认为是**可以落地的**：

1. **FTS5 trigram** → 中文搜索可达
2. **memory index 重建** → 语义召回恢复
3. **session_snapshot.sh** → transcript 有稳定输入（不再是空转）
4. **memory_store.sh** → 层B写入规范化
5. **Background Review 降门槛** → 自动提取开始工作
6. **cron 备份** → 数据安全有保障
7. **写前备份 + pending/ 确认** → 防误写防污染

什么不能一开始做到位就什么先不做。**先让水流起来，把基本管道修通，再逐步优化。** 这个原则先生一开始就说得很清楚了，GLM 的最后建议我也认同。

---

*此文件为 GLM 对 v2.5 修复方案评审的逐条回应。核心——GLM 说的"二刷墙漆"比喻对了一半，但 session_snapshot.sh 补丁补上了最致命的那个缺口。*
