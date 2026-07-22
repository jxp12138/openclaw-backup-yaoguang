# Feedback Log — 关键决策记录

> 类型：feedback
> 最后更新：2026-07-22

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

### 2026-06-09 — 微信通道接入 [channel:weixin]
- 插件：`@tencent-weixin/openclaw-weixin`
- 扫码登录完成
- 状态：enabled, configured, running

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

### 2026-06-10 — Embedding 迁移 [decision:embedding-provider]
- 旧：OpenAI（无 API key）
- 尝试：local（node-llama-cpp 卡死）、DeepSeek（无 embedding endpoint）
- 现：**GitHub Copilot**（text-embedding-3-small，设备登录完成）
- 备选：Ollama
- 选择理由：已就绪 + 零成本 + 质量好，目前够用

**2026-07-12 更新 [decision:embedding-deprecated]：** embedding 模式已弃用。
- memorySearch.provider 设为 none
- 改用 FTS5 trigram 做中文全文检索
- 原因：embedding 在低频个人场景下收益不大，FTS5 trigram 对中文检索够用

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
