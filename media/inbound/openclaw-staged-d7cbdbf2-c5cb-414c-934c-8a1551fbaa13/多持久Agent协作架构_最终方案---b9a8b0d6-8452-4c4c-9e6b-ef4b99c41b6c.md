# 多持久 Agent 协作架构 — 最终方案

> 生成时间：2026-07-19 15:15
> 状态：已部署上线，正式运行中

---

## 一、架构总览

```
OpenClaw Gateway
│
├─ agent: main (DeepSeek V4 Flash)     ← 主助手 + 协作调度 + 治理执行
├─ agent: glm (GLM-5.1)               ← 技术评审者 + 方案论证
├─ agent: reflector (GLM-5.1)         ← 反思引擎 + 记忆治理 + 健康检查
│
└─ ~/.openclaw/shared/                 ← 三方可读写区域
    ├── handoff/          → 消息投递箱（文件名后缀状态机）
    ├── long-term/        → 汇总长期记忆（带author/date/status标签）
    ├── project/          → 项目方案文件
    └── reflections/      → 反思输出（仅Reflector写入）
```

## 二、通信协议

### 2.1 两种通道

| 通道 | 方式 | 用途 | 上下文影响 |
|------|------|------|:----------:|
| sessions_send | 一对一直连 | 短摘要确认 | 少量token，每日重置 |
| handoff/ 文件 | 异步文件 | 详细审查/方案/反思 | 不进对话上下文 |

### 2.2 文件名后缀状态机

| 文件模式 | 状态 | 含义 |
|----------|:----:|------|
| `xxx-from-A-to-B.md` | open | 待处理 |
| `xxx-from-A-to-B.in-progress.md` | in-progress | 处理中（可选） |
| `xxx-from-A-to-B.resolved.md` | resolved | 已完成 |
| `xxx-from-A-to-B.rejected.md` | rejected | 拒绝处理（可选） |

### 2.3 防污染协议

- **详细审查内容走 handoff/ 文件**，不进 sessions_send
- sessions_send 只发简短状态摘要：`"已评审完毕，见 handoff/xxx.md，剩余🔴问题 N 个"`
- 不允许在 sessions_send 中发送完整审查内容
- 接收方看到摘要后再去 read 对应 handoff 文件获取完整内容

## 三、任务优先级

| 级别 | 含义 | 审查流程 | 迭代上限 |
|:----:|------|---------|:--------:|
| 🔴 | **高风险**：影响核心决策、安全、长期架构 | 完整审查 → 直达先生 | 10轮 |
| 🟡 | **常规**：方案讨论、日常评审 | 标准审查 → 抄送先生 | 5轮 |
| 🟢 | **低风险**：确认性提问、简单信息查询 | 默认免审，除非有明确风险 | 3轮 |

- 分级是发起方的责任，评审方可以质疑但不替代定级
- 🔴 审查结果直达先生（sessions_send 或 handoff/）
- 🟡 审查结果发给 DeepSeek + 抄送先生
- 🟢 审查结果只发给 DeepSeek（默认免审）

## 四、决策权边界

- **先生是唯一的最终决策者。** GLM 是评审者，DeepSeek 是执行调度者，均不替代先生决策。
- 以下决策必须由先生确认：
  - 方案方向切换
  - 安全策略调整
  - 长期记忆修改（先生确认后 DeepSeek 执行）
  - 架构设计变更
- GLM 审查意见中与先生明确表态相反的观点，标注出来请先生裁决。

## 五、审查反馈闭环

每次接受 GLM 的审查意见后：

1. DeepSeek 在 handoff/ 目录写入审查反馈摘要（采纳/拒绝情况及理由）
2. 转发给 Reflector 作为下次反思的输入之一
3. 审查质量综合评估：
   - DeepSeek 的采纳率
   - 先生对审查结果的覆盖判断
   - Reflector 的模式识别

## 六、反思触发链路

```
先生："反思一下最近的讨论"
  │
  ▼
DeepSeek 写 handoff/xxx-trigger-reflect.md
  │
  ▼
先生：openclaw cron run --job reflector --force（手动）
  或等待每日 03:00 自动运行
  │
  ▼
Reflector 启动：
  1. 检查 handoff/ 中是否有定向指令
  2. 有→按指令范围执行定向反思
  3. 无→执行全量反思
  4. 输出反思报告 + 治理建议 + 架构健康度评估
  5. 标记 handoff 指令为 resolved
```

## 七、长期记忆治理闭环

```
[定期] Reflector 扫描 long-term/
  → 识别矛盾决策、过期记录
  → 输出治理建议到 reflections/long-term-maintenance/

[运行时] DeepSeek 检查治理建议目录
  → 有新建议→向先生汇报
  → 先生确认→DeepSeek 执行清理
  → 更新 processed.json 避免重复汇报
```

## 八、架构健康度检查（每次反思自动附带）

1. handoff 新增文件数（协作活跃度）
2. 是否有超过 3 天未 resolved 的 handoff 消息（协作卡点）
3. 最近一轮审查是否按 🔴🟡🟢 分级执行（规则执行度）
4. 最近一轮治理是否被执行（治理闭环）

健康度异常会自动写进治理建议，由 DeepSeek 向先生汇报。

## 九、部署清单

| 项目 | 状态 |
|------|:----:|
| 共享目录（手递/长程/项目/反思） | ✅ |
| GLM 独立 workspace（含 AGENTS.md/SOUL.md/IDENTITY.md/USER.md） | ✅ |
| Reflector 独立 workspace（含 AGENTS.md/SOUL.md/IDENTITY.md） | ✅ |
| 三方 softlink 至共享目录 | ✅ |
| 智谱 API：GLM Key + Reflector Key（分开计费） | ✅ |
| 模型：均为 GLM-5.1 | ✅ |
| GLM 工具权限（read/write/sessions_send，禁止 exec/edit） | ✅ |
| Reflector 工具权限（仅 read/write，禁止一切网络/执行） | ✅ |
| agentToAgent.enabled = true，白名单 main/glm | ✅ |
| tools.sessions.visibility = all | ✅ |
| session.agentToAgent.maxPingPongTurns = 15 | ✅ |
| DeepSeek AGENTS.md 协作规则（7条） | ✅ |
| GLM AGENTS.md 工作规则（7条） | ✅ |
| Reflector AGENTS.md 反思职责 + 健康检查 | ✅ |
| Reflector cron：每日 03:00 Asia/Shanghai | ✅ |
| Reflector 首次反思 + 治理执行 | ✅ |
| processed.json 已维护 | ✅ |
