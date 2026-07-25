# MEMORY.md - 长期记忆索引

<!-- governance: pending promotion pool at governance/pending/promotion-pool.yaml -->

最后更新：2026-07-25

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
| 2026-07-25 23:00 | feedback | v3.1多Agent协作系统部署、验证完成反馈 | feedback-log.md |
| 2026-07-17 | reference | 服务器 & SSL 证书信息 | references.md |

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

## Promoted From Short-Term Memory (2026-07-26)

<!-- openclaw-memory-promotion:memory:memory/2026-06-13.md:22:47 -->
- 结论：定位是高频企业级 agent，目前个人低频场景收益不大 - 但 OpenViking 的"文件系统范式"和"后置提取"思路可借鉴 ### 关键认知突破 - OpenViking 没解决"该记什么"的元问题（它全量记录后异步提取） - 这个空缺由我们设计的前置过滤器填补 - 前置过滤器（对话中实时判断） + 后置提取（对话结束扫描） = 双保险 ### 四层记忆系统设计 先生主导，我与 DeepSeek 交互迭代后定稿。 架构： ``` 第零层：前置过滤器（对话中实时）→ 触发条件T1-T8 + 四维判断 + 行动路线 第一层：会话后提取 （对话结束时）→ 全局扫描 + 去重检查 第二层：自动存储 （提取后执行）→ 按时效/类型分级写入 第三层：自动维护 （定时 + 按需）→ 过期清理 + 暂存管理 ``` ### 已执行的落地步骤 - ✅ AGENTS.md「📝 记忆管理系统」章节更新（完整四层规则） - ✅ memory/pending-memory.md 暂存池创建 - ✅ cron「设置cron维护任务提醒」- 95db2b33 - 时间：2026-06-20 21:00 GMT+8（下周六） - 投递：微信（announce 模式） - 内容：提醒评估是否需要注册每日/每周/每月维护任务 [score=1.000 recalls=6 avg=0.887 source=memory/2026-06-13.md:22-47]
<!-- openclaw-memory-promotion:memory:memory/2026-07-14.md:1:14 -->
- # 2026-07-14 日志 ## 记忆系统检查与修复 - 执行了记忆系统架构全面检查（cron job） - 修复了 auto-dream 持续 SKIP 问题：旧版 dream.sh 将锁文件和时间戳文件混用，导致每次运行时 mtime 刷新，24h 检查永不通过。当前离线 v2 版本已分离，首次成功运行。 - 修复了 daily-git-backup push 分支错误（main → master）和超时保护 - 创建了 dream_last_run 时间戳基线文件（之前一直缺失） - 生成了 auto_dream:ready 标记（等待主对话执行 Consolidate + Prune） ## 遗留问题 - sessions.db 数据极少（仅 14 条），flush/snapshot 需要在会话中主动调用 - session_auto_flush.sh 缺少定时触发 cron [score=0.970 recalls=5 avg=1.000 source=memory/2026-07-14.md:1-14]
<!-- openclaw-memory-promotion:memory:memory/2026-06-10.md:28:39 -->
- 先生接受先用 Copilot，后续根据实际瓶颈再考虑 Ollama ### 信任积累 - 先生授权了 exec 和文件读写工具 ## 定时任务 - 设置 `cron` 任务「周六复盘提醒」 - 时间：2026-06-13 21:00 (GMT+8) - 推送至 last channel（当前 webchat） - 一次性，运行后自动删除 - cron job id: 61d1dd76-f930-4497-abb0-3d8a6bd79eab [score=0.943 recalls=3 avg=1.000 source=memory/2026-06-10.md:28-39]
<!-- openclaw-memory-promotion:memory:memory/2026-06-10.md:1:36 -->
- # 2026-06-10 ## 修復事項 - ✅ 创建 MEMORY.md（之前缺失） - ✅ 修复 memory 索引（迁移至 GitHub Copilot embedding） - ✅ GitHub Copilot 设备登录完成 ## 讨论纪要：MEMORY.md 建设路线 ### 核心共识 - MEMORY.md 是双方默契的基础，不能靠单一方法论一劳永逸 - 应当实践中摸索，逐步迭代，不照搬理论 - 先生提出定期复盘机制：**每周六、日 21:00-23:00** 专门研究 ### 分阶段行动方案（大框架） | 阶段 | 内容 | 状态 | |------|------|------| | **零** | 基础设施就绪（MEMORY.md 存在 + embedding 可用） | ✅ 完成 | | **一** | 结构化整理：按实体分类、决策带标签、信息带时间戳 | 🎯 **当前** | | **二** | 建立老化/压缩机制 | ⏳ 待定 | | **三** | 评估是否需要 memory-wiki 插件或其他工具 | ⏳ 待定 | ### 关于 embedding 方案 - 当前：GitHub Copilot（已配置完成） - 放弃 local embedding（node-llama-cpp 卡死） - 放弃 DeepSeek 路径（无 embedding endpoint） - 先生接受先用 Copilot，后续根据实际瓶颈再考虑... [score=0.908 recalls=3 avg=1.000 source=memory/2026-06-10.md:1-36]
<!-- openclaw-memory-promotion:memory:memory/2026-06-13.md:1:27 -->
- # 2026-06-13 ## 定时任务 - 创建 cron「找李强老师签字提醒」854152d2 - 时间：2026-06-14 08:00 GMT+8 - 投递渠道：openclaw-weixin（announce 模式） - 一次性，执行后自动删除 ## 记忆管理系统设计完成 ### 背景 之前构建 MEMORY.md 遵循三步走框架：①划分记忆标准 ②建立记忆存储机制 ③建立流程维护机制。 先生与 DeepSeek 讨论完成了 Step 1（记忆划分标准），并与我讨论后完成了 Step 2+3 的设计融合。 ### 研究 OpenViking - 仓库：github.com/volcengine/OpenViking（25.6K stars） - 字节跳动火山引擎团队开源，Rust+Python 实现 - 核心：用文件系统范式管理 agent 上下文（viking:// 协议） - L0/L1/L2 三层上下文加载 + 会话后自动提取记忆 - 有现成的 OpenClaw 插件（contextEngine 槽位） - 基准测试：OpenClaw + OpenViking 准确率从 24% 提升至 82%，Token 降 91% - 结论：定位是高频企业级 agent，目前个人低频场景收益不大 - 但 OpenViking 的"文件系统范式"和"后置提取"思路可借鉴 ### 关键认知突破 - OpenViking... [score=0.907 recalls=4 avg=0.960 source=memory/2026-06-13.md:1-27]
<!-- openclaw-memory-promotion:memory:memory/2026-06-14.md:1:23 -->
- # 2026-06-14 ## 记忆系统重构 - 先生质疑前置过滤器的必要性 → 分析 OpenClaw 自带记忆系统与我自定义系统的差异 - 结论：冲突检测、跨系统路由（memory/self-improving/proactivity）、暂存池是独有的核心价值 - 四维判断矩阵、cron 维护计划等被识别为过度设计，砍掉 - **AGENTS.md 记忆系统章节从 ~150 行精简到 ~60 行** ## Qwen 视觉模型接入 - 先生要求接入 Qwen3.6-plus 作为视觉副驾 - 方案 A：DeepSeek 做主模型 + Qwen 按需切换 - Qwen 国内区 Standard 端点配置完成 - API Key 由先生提供（sk-ws-开头） - 踩坑：sed 误替换了 models 节中的 key name，导致 UI 不显示 DeepSeek 选项 - 修复：用 python 直接操作 JSON 结构，重写 models 节 - 最终配置：`primary: deepseek/deepseek-v4-flash` + Qwen 作为视觉副驾 - Gateway 重启后正常运行 ## 确认的规则 - 决策思考 → DeepSeek V4 Flash - 看图分析 → 切 Qwen（不影响主模型） - UI 模型选单和 reasoning 选单已确认正确配置 [score=0.891 recalls=5 avg=0.855 source=memory/2026-06-14.md:1-23]
