# Auditor Agent 设计方案（终稿）

> 基于 2026-07-25 三轮探讨（先生初始设计 → 瑶光技术审 → Cherry GLM 综合评审 → 先生裁决）
> 终稿日期：2026-07-25

---

## 一、Agent 定位

Auditor Agent 是多 Agent 协作系统中的**审计节点**。不设计、不执行、不审查方案逻辑。唯一职责：通过量化指标和定性扫描，定期评估系统运行状态，将异常模式报告给先生。

Auditor 替代旧系统中的 Reflector，是持久 Agent。旧 Reflector 的 cron 保留过渡，Auditor 上线稳定后停用。

---

## 二、Agent 定义

### 激活机制

Auditor 为持久 Agent，通过 cron 定时触发 + 先生/瑶光手动触发的混合模式：

```
定时触发（每日 03:00 Asia/Shanghai）：
  cron job → isolated session → Auditor 执行日审计
  → 写审计报告到 audit-reports/
  → sessions_send 给瑶光 → 瑶光检查后反馈先生（或先生直查看）

手动触发：
  先生："审计一下近 3 天的系统运行"
  或瑶光："Auditor，帮我跑一次 E 组指标"
```

### 工具白名单

```json5
{
  id: "auditor",
  model: "zhipu-glm/glm-5.1",
  workspace: "~/.openclaw/workspace-auditor",
  tools: {
    allow: [
      "read",
      "write",              // 写入审计报告到 audit-reports/
      "sessions_send",      // 通知瑶光审计完成
      "web_search",         // 补充审计搜索
      "memory_search"       // 搜索长期记忆
    ],
    deny: [
      "exec",
      "cron",
      "gateway",
      "nodes",
      "edit",
      "apply_patch",
      "sessions_spawn",
      "sessions_list",
      "sessions_history",
      "session_status",
      "subagents",
      "message",
      "image_generate",
      "video_generate",
      "feishu_chat",
      "feishu_doc",
      "feishu_drive",
      "feishu_wiki",
      "pdf",
      "tts"
    ]
  }
}
```

### 其他运行时参数

```json5
{
  // 从 cron job 中启动时，它是 isolated session，不限制超时
  // cron timeoutSeconds: 1800 (30 分钟)
}
```

---

## 三、Workspace

```
~/.openclaw/workspace-auditor/
├── AGENTS.md
├── TOOLS.md
├── audit-reports/          ← 审计报告输出目录
│   ├── daily/              ← 日审计（A/B/C 组 + E 组）
│   └── weekly/             ← 周审计（A/B/C 组 + D 组 + E 组）
├── findings/               ← 审计异常记录（与 findings/ 共享格式）
└── review-feedback.json    ← GLM 审查疲劳检测日志
```

### findings/ 共享

Auditor 的 `findings/` 指向主 workspace 的 `findings/`（符号链接），与其他 Agent 产出存在同一目录。先生可在 findings/ 中一次性查看所有 Agent 产出。

---

## 四、审计分组（A-E）

### A 组：死信检测（占审计 20%）

扫描 findings/ 目录，检查未处理或超期的 finding：

| 编号 | 检查项 | 判断标准 |
|:----:|:------:|:--------:|
| A-01 | pending finding 超 24h | generated_at < (现在 - 24h) 且 status != resolved |
| A-02 | pending finding 超 72h | generated_at < (现在 - 72h) → upgrade 为「需关注」 |
| A-03 | findings/status分布异常 | new 占比过高（>50%）且超过72h无变化，说明提取流程阻塞 |
| A-04 | 连续 72h 无先生确认动作 | 从 handoff/ 检测最后resolved文件距现在 >72h |
| A-05 | 快速检查 findings/ 总量 | 超 100 个文件标记为膨胀预警 |

### B 组：遗漏检测（占审计 10%）

扫描 long-term/ 各文件，检查过期或不一致的内容：

| 编号 | 检查项 |
|:----:|:-------:|
| B-01 | 带有 `[deprecated: 日期]` 标记的条目是否仍存在于活跃内容中 |
| B-02 | 与被标注为超时的治理项（G26/G36）关联的记录 |
| B-03 | 被标注为矛盾的 record 是否已被先生裁决 |
| B-04 | 超过 60 天未被回顾的 accumulation 目录 |

### C 组：文件生命周期（占审计 15%）

扫描 handoff/ + findings/archive/ 目录：

| 编号 | 检查项 | 判断标准 |
|:----:|:------:|:--------:|
| C-01 | handoff/ resolved 文件 | 打开后超过 24h 未处理 |
| C-02 | findings/archive/ 积累 | 超过 60 天的文件清单，供先生确认删除 |
| C-03 | expired finding | findings/ 中标注了 deprecated 但未被清理的记录 |
| C-04 | 所有 resolved 文件 | 在 handoff/ 中完成仲裁确认 |

### D 组：Agent 产出质量（占审计 30% — 每周一次，非每日）

扫描 findings/ 中各 Agent 的产出，评估趋势：

| 编号 | 检查项 |
|:----:|:-------:|
| D-01 | 探索 Agent 通过率（findings.actionable 占比） |
| D-02 | 验证 Agent raw_output 覆盖率（是否有 findings 不带 raw_output） |
| D-03 | GLM 审查 通过率变化趋势 |

**审查疲劳检测（在 D-03 中）：**
检查 GLM 裁决 `review-feedback.json`，统计近一周的 PASS/FAIL 比例变化：
- 通过率连续上升超过 5% → 标注"⚠️ 审查疲劳：GLM 通过率异常上升"
- 但不确定原因，仅标注供先生关注

D 组每日不执行。日审计基于 A/B/C+E。

### E 组：汇总（占审计 25%）

| 编号 | 检查项 |
|:----:|:-------:|
| E-01 | 健康度总评分（基于 A/B/C 组 + D 组完成度） |
| E-02 | 优先级排序——按严重程度列出需要先生关注的异常 |
| E-03 | 完成度说明——D 组未完成时标注"指标部分计算" |

---

## 五、审计输出格式

### 审计发现 JSON（遵循v3.1统一格式）

```json
{
  "meta": {
    "source": "auditor",
    "task_id": "daily-audit-2026-07-25",
    "timestamp": "2026-07-25T03:00:00+08:00",
    "duration_seconds": 600,
    "status": "completed"
  },
  "summary": "日审计报告摘要",
  "overall_result": "PASS|PARTIAL|N/A",
  "findings": [
    {
      "id": "A-01-20260725",
      "category": "audit",
      "title": "pending finding 超24h",
      "detail": "exploration-xxx 状态为new超过24h",
      "evidence": "findings/2026-07-24_explorer_xxx.json last_updated",
      "raw_file_path": "关联文件路径",
      "priority": "high|medium|low",
      "actionable": true,
      "status": "new|extracted|archived"
    }
  ],
  "agent_specific": {
    "audit_type": "daily|weekly",
    "groups_completed": ["A", "B", "C", "E"],
    "health_score": 85,
    "recommend_actions": [
      {
        "action": "清理 findings/archive/ 中超 60 天的文件",
        "target_count": 3
      }
    ],
    "details": {
      "A": { "scanned": 5, "issues_found": 2 },
      "B": { "scanned": 4, "issues_found": 1 },
      "C": { "scanned": 4, "issues_found": 0 },
      "D": { "note": "D组每周执行" },
      "E": { "health_score": 85 }
    }
  },
  "unexplored": [],
  "anomalies": []
}
```

### 输出流向

```
审计完成后：
1. workspace-auditor/audit-reports/daily/2026-07-25.json  ← 本地存档
2. findings/auditor-2026-07-25.json                         ← findings/ 统一归档
3. sessions_send 通知瑶光                                    ← 通信
```

---

## 六、旧 Reflector 过渡方案

```
过渡期：
  旧 Reflector cron 保留（并行运行 3 天）
  Auditor 上线后，先生确认稳定
  → 删除旧 Reflector cron
  → 停用旧 workspace-reflector/
  → Auditor 接管 03:00 时段的治理自动化

Auditor workspace 不与 workspace-reflector 合并：
  新 workspace-auditor/ 从头积累 audit-reports/
  旧 audit-history、handoff 积累文件保留在 workspace-reflector/（可手动回查）
```

---

## 七、关键设计决策

| 决策项 | 结论 | 裁决者 |
|:------:|:----:|:------:|
| 替代 Reflector | ✅ 是，过渡期 3 天 | 先生 |
| 触发方式 | cron 定时 + 手动触发 | 先生 |
| 审计分组 | A(20%) B(10%) C(15%) D(30%周) E(25%) | 先生 |
| D 组频率 | 每周一次，非每日 | GLM 评审优化 |
| 审查疲劳检测 | ✅ D-03 中统计通过率变化 | GLM 评审补充 |
| findings 写入 | 符号链接共享 findings/ | GLM 评审确认 |
| processed.json | 沿用旧路径（非迁移） | 先生确认 |

---

## 八、⚠️ 待总方案阶段统一修正

GLM 评审指出：所有 Agent 的 findings JSON 需要定义统一核心字段（v3.1已实施，见总方案§6.2）：

```
统一核心字段：
  meta（source/task_id/timestamp/duration_seconds/status）
  summary
  overall_result（PASS/FAIL/PARTIAL/N/A）
  findings（id/category/title/detail/evidence/raw_file_path/priority/actionable/status）
  agent_specific
  unexplored
  anomalies
```

当前探索/验证/GLM/Auditor 四份方案的 findings JSON 字段定义不完全一致，需在总架构方案阶段一次性修正。

---

## 九、相关文档

- 探索 Agent 设计：`designs/explorer-agent-deployment.md`
- 验证 Agent 设计：`designs/verifier-agent-design.md`
- GLM Agent 设计：`designs/glm-agent-design.md`
- 瑶光主流程设计：待审

---

*终稿：2026-07-25 · ⚠️ findings 统一字段待总方案阶段修正 · 待先生确认后落地*
