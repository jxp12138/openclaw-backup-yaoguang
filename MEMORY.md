# MEMORY.md - 长期记忆索引

<!-- governance: pending promotion pool at governance/pending/promotion-pool.yaml -->

最后更新：2026-07-31

> 四类记忆索引文件。详情见 `long-term/` 目录下的对应文件。
> 当前 session 中看到的是启动时的快照。新写入的内容下次 session 才生效。

---

## 👤 user — 用户画像 & 行为准则

- [user-profile.md](long-term/user-profile.md) — 关于先生、交互黄金法则、执行纪律、信任与授权

## 💬 feedback — 关键决策记录

- [feedback-log.md](long-term/feedback-log.md) — Gateway 加固、微信接入、技能安装、Workboard、记忆系统设计、Qwen 接入、Embedding 迁移（含标签和时间戳）

## 📋 project — 项目上下文

- [project-context.md](long-term/project-context.md) — MEMORY.md 建设路线、定期复盘、已知优化点、活跃项目（含已归档地图子代理）

## 🔗 reference — 外部引用

- [references.md](long-term/references.md) — 微信 cron 配置、参考链接

---

## 记忆操作指引

### store 写入
写新内容到 `long-term/` 对应文件，然后更新本索引的摘要行（一行 ≤ 150 字符）。

### recall 读取
先看本索引，再用 `read` 工具加载对应的 `long-term/` 文件。优先加载最近 24 小时更新过的文件。

### search 搜索历史（transcript）
```bash
sqlite3 ~/.openclaw/workspace/transcripts/sessions.db \
  "SELECT snippet(messages_fts, 0, '<mark>', '</mark>', '...', 32) \
   FROM messages_fts WHERE content MATCH '关键词' \
   ORDER BY rank LIMIT 10;"
```

### 子代理 spawn 规范
spawn 子代理前，先 `read` 本索引和相关 `long-term/` 文件，将记忆注入子代理的 task prompt。

---

## 文件大小监控
- 本索引：≤ 200 行 / ≤ 25KB
- 单文件：≤ 20KB（contextInjection 单文件上限）
- 所有 long-term/ 文件总计：≤ 60KB（contextInjection 总计上限）
| 2026-07-27 | project | G26描述更正、地图子代理移至已归档 | project-context.md |
| 2026-07-27 | feedback | v3.1多Agent协作系统部署、验证完成反馈 | feedback-log.md |
| 2026-07-27 | reference | 服务器 & SSL 证书信息 | references.md |

## Promoted From Short-Term Memory (compiled 2026-07-25)

### 瑶光系统建设
- **06-09** Gateway 安全加固（折中方案）+ 核心原则录入。[source](memory/2026-06-09.md)
- **06-10** MEMORY.md 创建 + embedding 迁移。[source](memory/2026-06-10.md)
- **06-13** 四层记忆架构设计：前置过滤器+后置提取双保险。[source](memory/2026-06-13.md)
- **07-09** 记忆系统 v2 Phase 1 落地：MEMORY.md 四类分拆、long-term/ 创建。[source](memory/2026-07-09.md)
- **07-12** v2.6 修复：FTS5 trigram 中文搜索、flush/snapshot/store 三脚本。[source](memory/2026-07-12.md)
- **07-17/18** 网站搭建+公安备案+flush cron 配置。[source: daily logs]
- **07-20** 自动化脚本恢复 + Dreaming 由 cron 处理。[source](memory/2026-07-20.md)

### 多Agent协作
- **07-19** 三持久Agent架构上线（DeepSeek+GLM+Reflector）。[source](memory/2026-07-19.md)
- **07-25** v3.1升级：5 Agent + findings/ + Auditor 审计。[source](feedback-log.md)

### 方向
- **07-20** 全能私人管家方向提出：IoT/智能家居/自动化。[source](memory/2026-07-20.md)

## Promoted From Short-Term Memory (2026-07-27)

<!-- openclaw-memory-promotion:memory:memory/2026-07-20.md:1:16 -->
- ## 19:15 — 记忆系统自动化脚本恢复 - 恢复 session_flush.sh / session_snapshot.sh / memory_store.sh 三脚本 - 已验证语法正确 - Memory Dreaming 由 memory-core 插件 cron 处理，正常跑着 - 微信通道冲突已由先生解决（本地瑶光移除微信通道） ## 19:53 — 先生提出"全能私人管家"计划 先生表示从明天（2026-07-21）开始设计一个计划：**将瑶光打造成全能私人管家**，逐步连接真实物理世界。 ### 待办 - 明天 16:30 飞书通道搭建提醒（cron 已设） - 明天先生开始设计"全能私人管家"蓝图 - 技术方向：与真实物理世界连接（物联网/智能家居/自动化等） [score=0.863 recalls=3 avg=1.000 source=memory/2026-07-20.md:1-16]
<!-- openclaw-memory-promotion:merged:2026-07-27 -->
- **07-18** 公安备案待处理（周末不办公）。[source](memory/2026-07-18.md)
- **07-22** 每日cron/flush正常运行；治理框架v2落地（Reflector delivery修复 + 22:45 flush cron + 10项堆积清理）。[source](memory/2026-07-22.md)

## Promoted From Short-Term Memory (2026-07-28)

<!-- openclaw-memory-promotion:memory:memory/2026-06-13.md:43:55 -->
- ✅ memory/pending-memory.md 暂存池创建 - ✅ cron「设置cron维护任务提醒」- 95db2b33 - 时间：2026-06-20 21:00 GMT+8（下周六） - 投递：微信（announce 模式） - 内容：提醒评估是否需要注册每日/每周/每月维护任务 - 一次性，执行后自动删除 ### 备忘 - 禁止将密码等敏感信息写入记忆文件（USER.md 安全原则） - 暂存池不参与默认检索，仅正式记忆无结果时补充展示 - 前置过滤器 + 后置提取同时运行：前置兜底，后置补漏 - 下一次复盘：运行一周后评估是否需要加 cron 维护 [score=0.947 recalls=3 avg=1.000 source=memory/2026-06-13.md:43-55]
<!-- openclaw-memory-promotion:memory:memory/2026-07-22.md:1:58 -->
- ## [06:39] session: cron-daily-2026-07-22 ### 每日自动Flush **自动每日检查点** - 时间: 2026-07-22 06:39 - 今日已有日志条目: 0 - 今日日志文件大小: ? - 来源: daily-flush-snapshot cron trigger - 状态: 系统正常运行 --- ## [06:39] session 结束: cron-daily-2026-07-22 每日系统检查点 - 日期: 2026-07-22 - 时间: 06:39 - 已有会话轮次: 0 - 文件大小: ? _snapshot at ## [22:23] session: agent-main-feishu ### 治理框架v2落地 + 记忆系统整改 - 修复Reflector delivery配置（飞书通道） - 配置22:45每日flush cron - 清理10项堆积治理（G24-G34） - 建立治理闭环v2框架（tracker/whitelist/rules） - GLM评审整合，先生确认实施 - 通讯渠道统一：飞书唯一通道 - 3天验证期预设（07-25 08:00报告自动推送） - 先生全能管家计划延期至07-23 17:00 ## [22:45] session: cron-daily-2026-07-22 ### 每日自动Flush **自动每日检查点** - 时间: 2026-07-22... [score=0.946 recalls=3 avg=0.974 source=memory/2026-07-22.md:1-58]

## Promoted From Short-Term Memory (2026-07-29)

<!-- openclaw-memory-promotion:memory:memory/2026-07-19.md:1:14 -->
- ## 15:00 — 多持久Agent协作架构正式上线 **完成内容：** 1. 三持久Agent部署：DeepSeek (main) + GLM + Reflector 2. 跨Agent通信验证通过（sessions_send + handoff/ 文件名状态机） 3. 协作规则写入双方AGENTS.md：任务分级🔴🟡🟢、决策权边界、审查反馈闭环、防污染协议 4. Reflector首次反思产出优质报告（7844字节），4项治理建议已清理（G1/G3/G4/G5） 5. 架构健康度检查机制已内置，每次反思自动附带 **模型：** GLM-5.1（两个独立智谱API Key，分开计费） **协议：** 详细审走handoff/文件，sessions_send只发摘要 [score=0.840 recalls=3 avg=0.986 source=memory/2026-07-19.md:1-14]

## Promoted From Short-Term Memory (2026-07-30)

<!-- openclaw-memory-promotion:memory:memory/2026-07-17.md:1:18 -->
- # 2026-07-17 日志 ## 待办 - 公安备案重新提交（被退回：网站无法打开 + 交互服务选项） - 记忆系统自动化：补 cron 任务（flush/snapshot/Auto Dream） - 修复 GitHub 备份推送 ## 备注 - 今天给先生设了 9:00 提醒，未回复处理 - 网站已可正常访问（80+443） - Control 桌面端已可通过域名接入 ## 晚间维护 (22:45) - 会话 flush + snapshot 写入完成 - 长期记忆已更新：项目上下文 + 引用信息 - MEMORY.md 索引已同步 - 全天无主动对话，先生忙 [score=0.847 recalls=3 avg=1.000 source=memory/2026-07-17.md:1-18]

## Promoted From Short-Term Memory (compressed: 2026-07-22~07-31)

- 07-22~07-31 daily flush cron正常运行（模板日志已压缩）

## Promoted From Short-Term Memory (2026-08-01)

<!-- openclaw-memory-promotion:memory:memory/2026-07-25.md:13:13 -->
- 每日自动Flush: **自动每日检查点** [score=0.811 recalls=0 avg=0.620 source=memory/2026-07-25.md:13-13]
<!-- openclaw-memory-promotion:memory:memory/2026-07-27.md:10:10 -->
- 每日自动Flush: 状态: 系统正常运行 [score=0.803 recalls=0 avg=0.620 source=memory/2026-07-27.md:10-10]
<!-- openclaw-memory-promotion:memory:memory/2026-07-27.md:6:9 -->
- 每日自动Flush: 时间: 2026-07-27 22:45; 今日已有日志条目: 0; 今日日志文件大小: ?; 来源: daily-flush-snapshot cron trigger [score=0.803 recalls=0 avg=0.620 source=memory/2026-07-27.md:6-9]
<!-- openclaw-memory-promotion:memory:memory/2026-07-27.md:17:19 -->
- [22:45] session 结束: cron-daily-2026-07-27: 日期: 2026-07-27; 时间: 22:45; 已有会话轮次: 0 [score=0.803 recalls=0 avg=0.620 source=memory/2026-07-27.md:17-19]
