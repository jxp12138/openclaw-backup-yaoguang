# MEMORY.md - 长期记忆索引

最后更新：2026-07-17

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

## Promoted From Short-Term Memory (2026-07-20)

<!-- openclaw-memory-promotion:memory:memory/2026-07-09.md:1:19 -->
- # 2026-07-09 日常记录 ## 瑶光记忆系统 v2 — Phase 1 落地 - 完成 MEMORY.md 四类分拆（user/feedback/project/reference） - 创建 long-term/ 目录和四个分类文件 - 更新 AGENTS.md 记忆操作指引 - 创建 SQLite + FTS5 数据库（sessions.db） - 基于 Hermes Agent + Claude Code 架构，经 GLM 5.2 三轮评审 - 最终方案 v2.4，五轮迭代 ## 先生指示 - 2026-07-10 开始构建地图子代理 ## Auto Dream 离线整合 - dream.sh 脚本 + dream-prompt.md 指引 - cron 每日 03:00 触发检查 - 4 阶段流程：Orient → Gather → Consolidate → Prune - 锁机制：PID + CAS + 1h 超时回滚 - ⏳ 需要数据积累后才能跑出效果 [score=0.926 recalls=6 avg=1.000 source=memory/2026-07-09.md:1-19]
<!-- openclaw-memory-promotion:memory:memory/2026-06-09.md:1:25 -->
- # 2026-06-09 ## 完成事项 ### 1. Gateway 安全加固 - 基于 [docs.openclaw.ai/gateway/security](https://docs.openclaw.ai/gateway/security) 实施全部配置项 - 执行 `openclaw security audit` / `--deep` / `--fix` - 收紧文件权限：全部 700/600 - 保留 `allowInsecureAuth: true`（先生要求） - 最终选择折中方案：保留 exec、文件工具能力 - 已更新 USER.md 记录 ### 2. 核心原则录入 - 真实性至上、安全确认、隐私保护、诚实反馈、执行纪律（30min/3次/¥30）、交互逻辑 - 记录了先生不喜欢 😅 表情包、遇到问题要第一时间报告 ### 3. 微信连接 - 安装 `@tencent-weixin/openclaw-weixin` 插件 - 扫码登录完成 - 通道状态：enabled, configured, running ## 获得的信任 - 先生授权了 exec 和文件读写工具 - 先生选择了 A（折中加固方案） [score=0.810 recalls=3 avg=1.000 source=memory/2026-06-09.md:1-25]
<!-- openclaw-memory-promotion:memory:memory/2026-06-10.md:1:37 -->
- # 2026-06-10 ## 修復事項 - ✅ 创建 MEMORY.md（之前缺失） - ✅ 修复 memory 索引（迁移至 GitHub Copilot embedding） - ✅ GitHub Copilot 设备登录完成 ## 讨论纪要：MEMORY.md 建设路线 ### 核心共识 - MEMORY.md 是双方默契的基础，不能靠单一方法论一劳永逸 - 应当实践中摸索，逐步迭代，不照搬理论 - 先生提出定期复盘机制：**每周六、日 21:00-23:00** 专门研究 ### 分阶段行动方案（大框架） | 阶段 | 内容 | 状态 | |------|------|------| | **零** | 基础设施就绪（MEMORY.md 存在 + embedding 可用） | ✅ 完成 | | **一** | 结构化整理：按实体分类、决策带标签、信息带时间戳 | 🎯 **当前** | | **二** | 建立老化/压缩机制 | ⏳ 待定 | | **三** | 评估是否需要 memory-wiki 插件或其他工具 | ⏳ 待定 | ### 关于 embedding 方案 - 当前：GitHub Copilot（已配置完成） - 放弃 local embedding（node-llama-cpp 卡死） - 放弃 DeepSeek 路径（无 embedding endpoint） - 先生接受先用 Copilot，后续根据实际瓶颈再考虑... [score=0.810 recalls=3 avg=1.000 source=memory/2026-06-10.md:1-37]
