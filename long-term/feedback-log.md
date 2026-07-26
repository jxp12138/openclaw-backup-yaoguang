# Feedback Log — 关键决策记录

> 类型：feedback
> 最后更新：2026-07-25

---

### 2026-06-09 — Gateway 安全加固 [decision:gateway-security]

**背景：** 首次部署后，基于 OpenClaw 安全文档实施加固。

**加固执行：**
- 按 [docs.openclaw.ai/gateway/security](https://docs.openclaw.ai/gateway/security) 全部配置项实施
- 执行 `openclaw security audit` / `--deep` / `--fix`
- 收紧文件权限至 700/600

**关键决策：** 先生选择了**折中方案**
- 保留 `allowInsecureAuth: true`（方便开发使用）
- 保留瑶光的 exec 和文件读写工具能力（不做完全锁死）
- 不是最安全的配置，但平衡了安全与可用性

---

### 2026-06-09 — 微信通道接入 [channel:weixin] [deprecated: 2026-07-22]
- 插件：`@tencent-weixin/openclaw-weixin`
- 扫码登录完成
- 状态：已弃用（所有推送转飞书）

---

### 2026-06-09 — 技能安装 & 心智文件更新 [skills:self-improving+proactivity]
- 安装 `self-improving` v1.2.16
- 安装 `proactivity` v1.0.1
- 更新 SOUL.md、AGENTS.md、HEARTBEAT.md、TOOLS.md 注入行为指引
- 创建 ~/self-improving/ 和 ~/proactivity/ 两级记忆目录结构
- 先生偏好：不用 😅 表情

---

### 2026-07-03 — Workboard 插件启用 [decision:workboard]
- 应先生询问要求，启用内置 workboard 插件
- `openclaw plugins enable workboard` → gateway 热重载生效
- Dashboard 新增 Workboard 标签页

---

### 2026-06-13 — 四层记忆系统设计 [decision:memory-system]
**背景：** 此前按三步走框架设计，先生主导完成完整方案。
**架构：**
```
第零层：前置过滤器（对话中实时）
第一层：会话后提取  （对话结束时）
第二层：自动存储    （提取后执行）
第三层：自动维护    （后台定时）
```
**关键设计：** 前置过滤器（T1-T7 触发条件 + 四维判断）+ 后置提取（对话结束全量扫描）
**6-14 复盘精简：** 砍掉过度设计的 cron 维护计划和四维矩阵标记，保留冲突检测、跨系统路由、暂存池

---

### 2026-06-14 — Qwen 视觉模型接入 [decision:model-config]
- 已接入 Qwen3.6-plus 作为视觉副驾
- 主模型：DeepSeek V4 Flash（决策思考）
- 看图分析时切换 Qwen
- API endpoint 使用 Qwen 国内区 Standard
- 踩坑修复：sed 误替换 key name → 改用 python 直接操作 JSON

---

### 2026-06-10 → 2026-07-12 — Embedding 尝试与弃用 [decision:embedding-provider → decision:embedding-deprecated]
- 尝试多方案均因不可用放弃（OpenAI 无 Key / local node-llama-cpp 卡死 / DeepSeek 无 endpoint）
- 最终选用 GitHub Copilot（text-embedding-3-small）→ 07-12 改用 FTS5 trigram（低频场景收益不大，中文检索够用）

---

### 2026-07-09 — 记忆系统子代理设计 [project:yaoguang-memory-v2]
- 基于 Hermes Agent + Claude Code 两套记忆架构设计记忆系统
- 经 GLM 5.2 三轮评估，架构评审通过
- 项目名：瑶光—记忆系统子代理设计与构建
- 最终方案：v2.4（后迭代升级至 v2.6）
- 状态：Phase 1 编码实现完成

### 2026-07-09 — Phase 1 落地验证 [status:verified]
- MEMORY.md 索引格式
- long-term/ 四类分类文件
- AGENTS.md 记忆操作指引
- SQLite + FTS5 数据库
- Session Memory 渐进式笔记
- Background Review 机制
- 状态：✅ 全部跑通

### 2026-07-12 — 记忆系统 v2.6 Phase 1 修复 [decision:memory-system-v2.6]
**背景：** v2.4 Phase 1 验证中发现 embedding 索引故障（中文检索失效）
**修复内容：**
- 数据库修复：FTS5 unicode61 → trigram → 中文搜索恢复
- 创建 session_flush.sh / session_snapshot.sh / memory_store.sh 三脚本
- AGENTS.md 转录规则更新（flush+snapshot+store 三策略）
**状态：** ✅ 全链路 8 项验证通过

---

### 2026-07-19 — 多持久 Agent 协作架构部署 [decision:multi-agent]
**背景：** 先生、DeepSeek、GLM 三方协作存在信息孤岛、GLM 无记忆、反思缺位
**方案：** GLM 转为持久 Agent + 新增 Reflector 反思代理
**架构：**
- main (DeepSeek V4 Flash)：主助手 + 协作调度
- glm (GLM-5.1)：技术评审者
- reflector (GLM-5.1)：反思与记忆治理
**关键设计：** 独立 workspace + handoff 文件名状态机 + agentToAgent
**状态：** ✅ 部署完成，首次反思已产出

---

### 2026-07-25 — v3.1 多Agent协作架构部署 [decision:multi-agent-v3]
**背景：** 旧三元协同流水线问题：子Agent发现丢失、治理反馈链条过长、GLM审查使用频率不达预期
**方案：** 五个Agent + 三条路径动态路由
- 瑶光（DeepSeek V4 Flash）：全上下文中枢 + 方案设计 + 执行
- 探索Agent：只读环境探索（临时spawn，仅🔴）
- GLM Agent（GLM-5.1）：半白盒方案审查（持久，仅🔴）
- 验证Agent：黑盒落地验证（持久，🔴强制🟡可选）
- Auditor（GLM-5.1）：黑盒系统审计A-E 20项（持久，每日03:00）
**关键设计：** findings/缓冲区统一归档、半白盒三层审查、检查分层执行、C-007回滚升格、tentative→confirmed模式积累、reviewed_plan_version版本追踪、五层安全约束
**部署：** 6个Agent注册（含旧reflector过渡保留）、Gateway重启
**验证：** 🟢→🟡→🔴 全部通过
**修复：** GitHub备份SSH修复、processed.json修复、MEMORY.md压缩、GLM AGENTS.md补全
**状态：** ✅ v3.1 系统完整运行正常
**待办：** 3天后删除旧reflector cron（已设 07-28 提醒）
**裁决：** G26/G49 已由先生 07-26 确认按 GLM 建议处理

---

### 2026-07-26 — 治理自动化 3 项边界决策 [decision:governance-boundaries]

**背景：** 治理自动化三层方案经 GLM 评审后提出 3 个需先生裁决的 🔴 问题。07-26 先生确认按 GLM 建议处理。

**决策内容：**
- 自执行白名单 → 仅限无害操作（更新索引、归档日志、合并重复条目），不在白名单内即使标 🟢 也需确认
- long-term 不可过期类别 → 先生决策记录、安全策略变更永久保留；老化基准用最后引用时间而非创建时间
- 🟡 级通知方式 → 每日摘要，不逐条推送

**后续：** 07-26 先生确认：治理自动化方案随 Reflector 一起归档，不独立落地。3 条边界规则直接写入操作规则，价值已内化。
