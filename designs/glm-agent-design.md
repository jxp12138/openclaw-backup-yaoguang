# GLM Agent 设计方案（终稿）

> 基于 2026-07-25 三轮探讨（先生初始设计 → 瑶光优化建议 → Cherry GLM 综合评审 → 先生裁决）
> 终稿日期：2026-07-25

---

## 一、Agent 定位与半白盒模型

GLM Agent（审查 Agent）是多 Agent 协作系统中的**方案审查节点**。不做探索、不做验证、不写长期记忆。唯一职责：围绕瑶光提交的方案方案检查包，执行结构化审查并产出裁决。

### 半白盒三层模型

GLM 理解"方案说了什么"，不推测"瑶光为什么这么说"。

| 层级 | 内容 | 审查类型 | Token消耗 |
|:----:|------|:--------:|:--------:|
| 第一层（机械对照）| C-001, C-002, C-003 | 事实匹配 | 低 |
| 第二层（内容推理）| C-004, C-005, C-006, C-007, C-008 | 概念推理 | 中 |
| 第三层（设计推理）| 推测瑶光的设计意图 | **不做** | — |

### 上下文损耗自修正

方案越差，GLM 越容易发现问题。检查包没写完整本身会成为 GLM 的审查发现，而不是审查失效的原因。

---

## 二、Agent 定义

### 激活机制

GLM 为持久 Agent，由瑶光通过 sessions_send 唤醒：

```
Step 1: 瑶光提交方案检查包后
        → sessions_send(sessionKey="agent:glm:main")
        → 消息："新方案检查：handoff/check-xxx-from-deepseek.md"

Step 2: GLM 收到消息 → 读取 handoff/ → 执行分层审查
        → 写完整裁决到 handoff/xxx.resolved.md
        → 写结构化结果到 findings/glm-review-xxx.json（先生查阅+审计）
        → sessions_send 回瑶光："审查完成，剩余🔴问题N个，见handoff/xxx.resolved.md"
```

### 工具白名单

```json5
{
  id: "glm",
  model: "zhipu-glm/glm-5.1",
  workspace: "~/.openclaw/workspace-glm",
  agentDir: "~/.openclaw/agents/glm/agent",
  tools: {
    allow: [
      "read",
      "write",
      "sessions_send",
      "memory_search",
      "web_search",        // 保留，加使用约束
      "web_fetch"
    ],
    deny: [
      "exec",
      "cron",
      "gateway",
      "nodes",
      "edit",
      "apply_patch",
      "sessions_spawn",
      "message",
      "image_generate",
      "video_generate",
      "feishu_chat",
      "feishu_doc",
      "feishu_drive",
      "feishu_wiki",
      "subagents",
      "sessions_list",
      "sessions_history",
      "session_status",
      "pdf",
      "tts"
    ]
  }
}
```

### web_search 使用规则

写入 GLM AGENTS.md：

```
web_search仅用于以下场景：
1. 方案中引用了某个技术概念，需要确认其含义才能完成第二层推理
2. 方案中的异常处理涉及某个不确定的技术机制

禁止用web_search做以下事情：
- 验证API参数是否正确（这是探索/验证Agent的职责）
- 查找库版本兼容性（这是探索Agent的职责）
- 搜索"更好的方案"替代瑶光的选择（这是第三层，不做）

如果发现方案中某个技术细节需要外部验证才能判断，
标注"⚠️ 方案中XXX未经探索阶段验证"，而不是自己去查。
```

---

## 三、Workspace 与积累机制

### 目录结构

```
~/.openclaw/workspace-glm/
├── AGENTS.md
├── TOOLS.md
├── review-history.md        ← 审查历史记录
└── plan-defects.md         ← 发现的模式缺陷库
```

### 初始状态

文件不存在则跳过，不阻塞审查执行。首次审查本身就是历史。

### 模式积累闭环

每条模式标注来源和状态：

```yaml
- pattern: "异常处理经常遗漏DB回滚"
  confidence: high
  source: "先生确认"
  confirmed_at: "2026-07-22"

- pattern: "超时配置被当作默认值跳过"
  confidence: medium
  source: "GLM自行发现"
  first_seen: "2026-07-25"
  status: "tentative"
```

- `source: "先生确认"` → 检索时直接引用
- `source: "GLM自行发现"` → 降低权重，可作为补充检查参考但不作为判定标准
- `status: "tentative"` → 先生确认后升格为 `active`
- 长时间未确认 → Auditor 提醒

tentative 模式可作为补充检查项参考，但不能作为 pass/fail 判定标准。

---

## 四、检查包格式

### 固定基线 7 条（检查包中恒有）

```
C-001: 需求覆盖 ↔ 方案内容
       第一层 — 需求中每一条是否在方案中有所体现
  
C-002: 方案设计 ↔ 实际落地/配置
       第一层 — 方案中每个设计点是否与配置/代码对应

C-003: 方案内部逻辑一致性
       第一层 — 方案各部分之间是否自洽

C-004: 概念完整性（边界/前置/后置/中断）
       第二层 — 功能边界、执行前置条件、后置恢复、中断处理是否完整

C-005: 异常场景（失败/超时/冲突/降级）
       第二层 — 错误路径、超时回退、资源冲突、降级策略是否覆盖

C-006: 潜在漏洞（安全/资源/重复/幂等）
       第二层 — 配置遗漏、状态泄漏、非幂等操作、安全暴露面

C-007: 回滚/撤销
       第二层 — 配置变更或操作失败后的回滚方案是否明确
```

### 自由补充（1 条，瑶光手动追加）

```
C-008: <按需填充>
```

额外补充数量由 2 条降为 1 条（C-007 升格后占了一条基线的位置）。

### 检查包模板（写入瑶光 AGENTS.md）

```
## 方案检查包
### 审查目标
<简述本次审查的核心目标>

### 需求原文
- <需求1>
- <需求2>
- ...

### 探索发现摘要
<直接引用探索Agent的产出>

### 检查项
| 编号 | 检查项 | PASS标准 | FAIL标准 | 证据要求 |
|:----:|--------|---------|---------|:--------:|
| C-001 | ... | ... | ... | ... |
```

---

## 五、审查流程：分层检查

```
瑶光提交方案检查包
    ↓
第一层审查（C-001, C-002, C-003）
    ├── 全部 PASS → 进入第二层
    └── 有 FAIL → 瑶光修方案，**不进第二层**
                    ↓
                   修完再提交 → 重新从第一层开始
    ↓
第二层审查（C-004, C-005, C-006, C-007, C-008）
    ↓
产出裁决 → 写 handoff/ + findings/
```

**分层理由：**
- 第一层发现的问题通常是基础性的（需求没覆盖、逻辑不自治），需修正后才能评估第二层
- 分开修比一起修质量更高——避免修需求覆盖时顺便修异常处理导致相互影响
- 不浪费 GLM 跑第二层深推的 Token

**迭代规则：**
- 每轮检查瑶光都会附上 `reviewed_plan_version` 字段
- 版本格式：`v1.0`（首次提交）、`v1.1`（第一轮修改）、`v1.2`（第二轮修改）...
- GLM 在裁决中标引 `reviewed_plan_version`，表明基于哪个版本审查
- 瑶光转述时检查版本是否一致，不一致则标注"⚠️ 此审查基于旧版方案"
- 最多 N 轮（按任务分级确定），超上限 escalate 到先生

---

## 六、结构化裁决格式（遵循v3.1统一格式）

```json
{
  "meta": {
    "source": "glm",
    "task_id": "glm-voice-light-001",
    "timestamp": "2026-07-25T11:20:00+08:00",
    "duration_seconds": 300,
    "status": "completed"
  },
  "summary": "审查摘要（3-5句话）",
  "overall_result": "PASS|FAIL|PARTIAL",
  "findings": [
    {
      "id": "GLM-001",
      "category": "review",
      "title": "C-005异常处理缺失",
      "detail": "具体描述（≤500字）",
      "evidence": "引用方案原文中的证据",
      "raw_file_path": "关联的方案文档路径",
      "priority": "high|medium|low",
      "actionable": true|false,
      "status": "new|extracted|archived"
    }
  ],
  "agent_specific": {
    "reviewed_plan_version": "v1.0",
    "check_results": [
      {
        "check_id": "C-001",
        "layer": 1,
        "verdict": "PASS|FAIL|WARN",
        "detail": "具体判断依据"
      }
    ],
    "remaining_critical": 0,
    "remaining_major": 1
  },
  "unexplored": [],
  "anomalies": []
}
```

### 输出流向

```
GLM 检查完成后：
1. handoff/xxx.resolved.md   ← 瑶光取走用（拾取盒/通信）
2. findings/glm-review-xxx.json  ← 先生查阅用（统一归档）

先生只需要读 findings/ 就能看到所有 Agent 的产出链：
findings/
├── exploration-xxx.json  (探索 Agent 的发现)
├── verifier-xxx.json     (验证 Agent 的核对)
└── glm-review-xxx.json   (GLM 的审查)

handoff/ 保留"通信"定位
findings/ 明确为"查阅+审计"双重定位
```

---

## 七、检查结果处理

```
GLM 裁决
    ↓
瑶光收到 sessions_send 摘要
    ↓
读取 handoff/xxx.resolved.md 获取完整审查结果
    ↓
逐条检查结果：
├── 🔴 问题数 = 0 → 方案确认通过
├── 🔴 问题数 > 0：
│   ├── 修方案 → 改版本号 → 提交新检查包
│   └── 超轮次上限 → escalate 到先生
└── 超轮次上限（按任务分级确定）：
    ├── 🔴 任务：≤10轮
    ├── 🟡 任务：≤5轮
    └── 🟢 任务：≤3轮
```

---

## 八、越界检测（瑶光执行）

瑶光转述 GLM 结果时，在回复中附加越界检测标注：

> 🔍 **越界检测**：上述 GLM 第 C-00X 条可能越界（推测了瑶光的设计意图/涉入第三层），请注意评估。

判断依据：半白盒边界准则——**"仅凭方案文档内容能完成这个判断吗？"**

---

## 九、设计决策记录

| 决策项 | 结论 | 裁决者 |
|:------:|:----:|:------:|
| 半白盒三层模型 | ✅ 采用 | 先生 |
| 7 条固定基线 + 1 条自由补充 | ✅ C-007 升格为固定基线 | 先生 |
| 分层检查流程 | ✅ C-001~003→PASS→C-004~008 | 先生 |
| findings/ 双重定位 | ✅ handoff/通信 + findings/查阅+审计 | 先生（瑶光分歧→GLM采纳） |
| web_search | ✅ 保留，加使用约束 | 先生（瑶光折中→GLM采纳） |
| reviewed_plan_version | ✅ 替代过期标记 | 先生 |
| 模式积累闭环 | ✅ tentative→confirmed | 先生 |
| 检查包模板化 | ✅ 写入瑶光 AGENTS.md | 先生 |
| workspace 初始状态 | ❌ 不存在则跳过，不阻塞 | 先生 |
| AI 约束行为（粘贴代码） | ✅ 软约束 + 先生监督 | 先生 |

---

## 十、相关文档

- 探索 Agent 设计：`designs/explorer-agent-deployment.md`
- 验证 Agent 设计：`designs/verifier-agent-design.md`
- Auditor Agent 设计：待审

---

*终稿：2026-07-25 · 待先生确认后落地*
