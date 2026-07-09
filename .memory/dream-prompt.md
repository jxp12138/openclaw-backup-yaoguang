# Auto Dream — 离线整合执行指引

## 触发时机
当主代理在对话或 heartbeat 中检测到 `auto_dream:ready` 标记时执行。

## 四阶段流程

### 1. Orient（定向探索）
- 读取 MEMORY.md 索引，了解当前文件结构
- 列出 long-term/ 下所有文件
- 检查有没有重复或近似的主题

### 2. Gather（信息收集）
- 查看最近新增的记忆（读取 long-term/ 文件内容）
- 与现有记忆对比，发现矛盾或重复
- 必要时查询 transcripts/sessions.db 验证旧信息是否还成立

### 3. Consolidate（整合）
- 重复的记忆 → 合并为一条，保留最新的时间戳
- 矛盾的信息 → 保留最近确认的，旧的事实直接删除（不是标注[deprecated]）
- 跨文件分散的同主题 → 归类到正确文件
- 执行规则：
  - 相对日期 → 转为绝对日期
  - `~/self-improving/` 中的执行教训 → 按类型归入 feedback-log
  - `~/proactivity/` 中的任务状态 → 保留不动

### 4. Prune（修剪索引）
- 检查 MEMORY.md 索引：
  - ≤ 200 行
  - 每行 ≤ 150 字符
  - 删除指向已删除/已归档文件的指针
- 过时内容移入 `long-term/archived/`
- 索引行按主题分组，保持可读性
