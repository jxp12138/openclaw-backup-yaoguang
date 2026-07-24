# MEMORY.md - 长期记忆索引

<!-- governance: pending promotion pool at governance/pending/promotion-pool.yaml -->

最后更新：2026-07-22

> 四类记忆索引文件。详情见 `long-term/` 目录下的对应文件。
> 当前 session 中看到的是启动时的快照。新写入的内容下次 session 才生效。

---

## 👤 user — 用户画像 & 行为准则

- [user-profile.md](long-term/user-profile.md) — 关于先生、交互黄金法则、执行纪律、信任与授权

## 💬 feedback — 关键决策记录

- [feedback-log.md](long-term/feedback-log.md) — Gateway 加固、微信接入、技能安装、Workboard、记忆系统设计、Qwen 接入、Embedding 迁移（含标签和时间戳）

## 📋 project — 项目上下文

- [project-context.md](long-term/project-context.md) — MEMORY.md 建设路线、定期复盘、已知优化点、活跃项目（含地图子代理待办）

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
| 2026-07-12 20:16 | project | 瑶光记忆系统 v2.6 修复方案：Phase 1 落地，flush+snapshot+store 三脚本就绪 | project-context.md |
| 2026-07-12 20:46 | project | 记忆系统 v2.6 Phase 1 验证测试 | project-context.md |
| 2026-07-17 | project | 网站搭建完成 + SSH 加固 + Control UI 远程连接就绪 | project-context.md |
| 2026-07-19 14:26 | feedback | 多持久Agent协作架构部署完成 | feedback-log.md |
| 2026-07-19 14:28 | project | Reflector首次反思产出6项治理建议，G1/G3/G4/G5已执行 | project-context.md |
| 2026-07-17 | reference | 服务器 & SSL 证书信息 | references.md |

## Promoted From Short-Term Memory (2026-07-20) — compressed

- **2026-07-09** 瑶光记忆系统 v2 Phase 1 落地：MEMORY.md 四类分拆、long-term/ 创建、FTS5 数据库、AGENTS.md 指引更新。五轮迭代后最终方案 v2.4。Auto Dream 脚本就绪。[source](memory/2026-07-09.md)
- **2026-06-09** Gateway 安全加固（折中方案，保留allowInsecureAuth）+ 核心原则录入 + 微信扫码登录完成。[source](memory/2026-06-09.md)
- **2026-06-10** MEMORY.md 创建 + embedding 迁移（最终选用 GitHub Copilot）+ 定期复盘机制确立。[source](memory/2026-06-10.md)

## Promoted From Short-Term Memory (2026-07-22) — compressed

- **2026-07-12** 记忆系统 v2.6 Phase 1 修复：FTS5 trigram 中文搜索恢复、flush/snapshot/store 三脚本创建、全链路 8 项验证通过。[source](memory/2026-07-12.md)
- **2026-06-13** 四层记忆架构设计完成：前置过滤器+后置提取双保险。研究 OpenViking。AGENTS.md 记忆章节更新。[source](memory/2026-06-13.md)

## Promoted From Short-Term Memory (2026-07-23)

<!-- openclaw-memory-promotion:compressed:2026-07-23 -->
- 07-17 / 07-18 低分维护记录已清理（score=0.803, recalls=0），压缩为：网站搭建+公安备案+flush cron配置 [source: memories 07-17/07-18, detail in daily logs]

## Promoted From Short-Term Memory (2026-07-24)

<!-- openclaw-memory-promotion:memory:memory/2026-07-19.md:11:12 -->
- 15:00 — 多持久Agent协作架构正式上线: **模型：** GLM-5.1（两个独立智谱API Key，分开计费） **协议：** 详细审走handoff/文件，sessions_send只发摘要 [score=0.803 recalls=0 avg=0.620 source=memory/2026-07-19.md:11-12]
<!-- openclaw-memory-promotion:memory:memory/2026-07-19.md:5:8 -->
- 15:00 — 多持久Agent协作架构正式上线: 三持久Agent部署：DeepSeek (main) + GLM + Reflector; 跨Agent通信验证通过（sessions_send + handoff/ 文件名状态机）; 协作规则写入双方AGENTS.md：任务分级🔴🟡🟢、决策权边界、审查反馈闭环、防污染协议; Reflector首次反思产出优质报告（7844字节），4项治理建议已清理（G1/G3/G4/G5） [score=0.803 recalls=0 avg=0.620 source=memory/2026-07-19.md:5-8]
<!-- openclaw-memory-promotion:memory:memory/2026-07-19.md:4:4 -->
- 15:00 — 多持久Agent协作架构正式上线: **完成内容：** [score=0.803 recalls=0 avg=0.620 source=memory/2026-07-19.md:4-4]
<!-- openclaw-memory-promotion:memory:memory/2026-07-19.md:9:9 -->
- 15:00 — 多持久Agent协作架构正式上线: 架构健康度检查机制已内置，每次反思自动附带 [score=0.803 recalls=0 avg=0.620 source=memory/2026-07-19.md:9-9]

## Promoted From Short-Term Memory (2026-07-25)

<!-- openclaw-memory-promotion:memory:memory/2026-07-20.md:13:15 -->
- 待办: 明天 16:30 飞书通道搭建提醒（cron 已设）; 明天先生开始设计"全能私人管家"蓝图; 技术方向：与真实物理世界连接（物联网/智能家居/自动化等） [score=0.803 recalls=0 avg=0.620 source=memory/2026-07-20.md:13-15]
<!-- openclaw-memory-promotion:memory:memory/2026-07-20.md:10:10 -->
- 19:53 — 先生提出"全能私人管家"计划: 先生表示从明天（2026-07-21）开始设计一个计划：**将瑶光打造成全能私人管家**，逐步连接真实物理世界。 [score=0.803 recalls=0 avg=0.620 source=memory/2026-07-20.md:10-10]
<!-- openclaw-memory-promotion:memory:memory/2026-07-20.md:3:3 -->
- 19:15 — 记忆系统自动化脚本恢复: 恢复 session_flush.sh / session_snapshot.sh / memory_store.sh 三脚本 [score=0.803 recalls=0 avg=0.620 source=memory/2026-07-20.md:3-3]
<!-- openclaw-memory-promotion:memory:memory/2026-07-20.md:5:6 -->
- 19:15 — 记忆系统自动化脚本恢复: Memory Dreaming 由 memory-core 插件 cron 处理，正常跑着; 微信通道冲突已由先生解决（本地瑶光移除微信通道） [score=0.803 recalls=0 avg=0.620 source=memory/2026-07-20.md:5-6]
