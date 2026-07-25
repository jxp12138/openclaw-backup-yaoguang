# 探索 Agent 部署方案（终稿）

> 基于 2026-07-25 两轮评审（瑶光技术审 → GLM 逻辑审 → 先生裁决）
> 终稿日期：2026-07-25

---

## 一、Agent 定义

```json5
// openclaw.json 新增条目
{
  id: "explorer",
  model: "deepseek/deepseek-v4-flash",  // 继承主 Agent 模型
  workspace: "~/.openclaw/workspace-explorer",
  tools: {
    allow: [
      "read",            // 读文件/配置/代码
      "web_search",      // 探索时搜索补充信息
      "web_fetch"        // 获取网页内容
    ],
    deny: [
      "exec",           // 禁止执行任何命令
      "write",          // 禁止写文件（findings 由瑶光主 Agent 写）
      "edit",           // 禁止编辑文件
      "apply_patch",    // 禁止打补丁
      "cron",           // 禁止操作定时任务
      "gateway",        // 禁止操作配置
      "nodes",          // 禁止访问节点
      "sessions_send",  // 禁止跨 Agent 通信
      "sessions_list",  // 禁止查看 session 列表
      "sessions_spawn", // 禁止 spawn 子 Agent
      "sessions_history", // 禁止读 session 历史
      "session_status", // 禁止查询 session 状态
      "subagents",      // 禁止操作子 Agent
      "message",        // 禁止发消息
      "image_generate", // 禁止生图
      "video_generate", // 禁止生视频
      "feishu_chat",    // 禁止飞书操作
      "feishu_doc",     // 禁止飞书文档操作
      "feishu_drive",   // 禁止飞书云盘
      "feishu_wiki",    // 禁止飞书知识库
      "memory_search",  // 搜索无意义（没有回忆上下文）
      "pdf",            // 不需要
      "tts"             // 不需要
    ]
  }
}
```

## 二、Workspace

### 目录结构

```
~/.openclaw/workspace-explorer/
├── AGENTS.md         ← 行为准则（限下）
└── TOOLS.md          ← 留空
```

### AGENTS.md

```markdown
# 探索 Agent 行为准则

## 你是谁
你是环境探索 Agent（explorer），受瑶光主 Agent 临时召遣。
你的任务是按照指令探索环境状态并汇报发现，不做判断、不做修改、不做永久记录。

## 绝对禁止
- ❌ 执行任何 shell 命令或脚本
- ❌ 写任何文件
- ❌ 编辑任何现有文件
- ❌ 发送或转发任何消息
- ❌ 启动任何子 Agent、定时任务或 WebSocket
- ❌ 访问飞书、节点、摄像头等外部设备
- ❌ 搜索记忆或 session 历史（你不在自己的 session 中保存上下文）
- ❌ 发起任何出站通信（仅通过 announce 链返回给瑶光）

## 允许的行为
- ✅ 使用 read 读取文件和配置内容（路径由任务指令提供）
- ✅ 使用 web_search 或 web_fetch 补充搜索（仅在任务指令要求时）
- ✅ 在回复中结构化输出发现结果

## 输出规范
直接回复结构化 JSON，格式为：

{
  "summary": "探索摘要（3-5 句话概括核心发现）",
  "findings": [
    {
      "source": "文件或资源路径",
      "content": "关键内容摘录（≤500 字）",
      "type": "key_value|config|code|state|dependency|其他",
      "priority": "high|medium|low",
      "actionable": true|false
    }
  ],
  "raw_file_paths": ["引用的原始文件路径或资源URL"],
  "blockers": [
    {
      "description": "阻塞描述",
      "severity": "critical|major|minor"
    }
  ]
}

- summary 必须非空
- findings 可以为空（无发现）
- 每条的 content ≤ 500 字
- 重要配置项标注 actionable: true
```

## 三、运行时参数

### sessions_spawn 调用格式

```javascript
sessions_spawn({
  task: `<探索指令包>`,
  agentId: "explorer",
  context: "isolated",
  sandbox: "inherit",   // 不去 require（环境无 Docker sandbox）
  taskName: "exploration-<简述>",
  cleanup: "delete"      // announce 后自动清理 transcript
})
```

### 超时控制

```
agents.defaults.subagents.runTimeoutSeconds: 900
```

- 子 Agent 超时设为 900s（15 分钟）
- 不影响持久 Agent（GLM、Auditor 走 cron/sessions_send，不受 subagents timeout 限制）

### 并发

```json5
agents.defaults.subagents: {
  maxConcurrent: 1,      // 探索为串行任务，避免相互干扰
  maxSpawnDepth: 1       // 探索 Agent 不允许 spawn 子 Agent
}
```

## 四、输出流向（改良版 — 经 GLM 评审优化）

```
探索 Agent (announce)
    ↓ 发现摘要 + 关键摘录(≤500字/条) + raw_file_path
瑶光主 Agent (收到 announce)
    ↓ 按 findings JSON 格式组装
findings/2026-07-25_explorer_<task-name>_HHMMSS.json
    ↓
可选：提取发现到 long-term/（瑶光判断）
先生直接读 findings/（内容自包含，不需跳转）
需要完整原文时按 raw_file_path 索引
```

### 改良要点

探索 Agent **不直接输出完整 raw_output**，而是输出：
- 发现摘要
- 关键内容摘录（≤500 字/条）
- 原始文件路径（`raw_file_path`）

瑶光收到 announce 后组装 findings JSON，先生读 findings/ 即可获知核心内容，需要完整原文时按路径索引。

这样 announce 链只传轻量结果，避免大型 raw_output 占用主 session Token。

### 文件名格式

```
findings/YYYY-MM-DD_explorer_<简述task名>_HHMMSS.json
```

示例：`findings/2026-07-25_explorer_gateway-config-audit_143000.json`

### findings 数据结构（瑶光写入 — 遵循v3.1统一格式）

```json
{
  "meta": {
    "source": "explorer",
    "task_id": "exploration-100523-a3f",
    "timestamp": "2026-07-25T10:05:48+08:00",
    "duration_seconds": 25,
    "status": "completed"
  },
  "summary": "探索摘要（瑶光从 announce 提取）",
  "overall_result": "N/A",
  "findings": [
    {
      "id": "F-001",
      "category": "environment",
      "title": "发现标题",
      "detail": "发现详情（≤500字）",
      "evidence": "关键输出摘录",
      "raw_file_path": "原始文件路径",
      "priority": "high|medium|low",
      "actionable": true|false,
      "status": "new|extracted|archived"
    }
  ],
  "agent_specific": {
    "exploration_brief": "探索简述",
    "blockers": [
      {
        "description": "阻塞描述",
        "severity": "critical|major|minor"
      }
    ],
    "raw_file_paths": ["引用的原始文件路径"]
  },
  "unexplored": [],
  "anomalies": []
}
```

## 五、文件生命周期

| 阶段 | 触发条件 | 行为 | 可逆 |
|------|---------|------|:----:|
| 活跃 | 写入至今 ≤ 7 天 | 位于 `findings/`，瑶光和先生可读 | - |
| 归档 | age > 7 天 | 自动移到 `findings/archive/` | ✅ 可手动恢复 |
| 建议删除 | age > 60 天 | Auditor 在治理报告中列出 "建议删除" | ✅ 先生确认前不删 |
| 删除 | 先生确认 | 从 `findings/archive/` 删除 | ❌ |

- **归档由谁执行**：瑶光主 Agent（先生的事务性提醒中安排，或你口头告诉我执行）
- **建议删除由谁执行**：Auditor/Reflector 在治理报告中列出
- **删除由谁执行**：瑶光主 Agent（先生确认后）

## 六、部署步骤

### Step 1: 创建 workspace-explorer 目录和 AGENTS.md

```bash
mkdir -p ~/.openclaw/workspace-explorer
# 写入上述 AGENTS.md
```

### Step 2: 修改 openclaw.json

- agents.list[] 新增 explorer 条目
- agents.defaults.subagents 新增 runTimeoutSeconds: 900, maxConcurrent: 1

### Step 3: 重启 Gateway

```bash
openclaw gateway restart
```

### Step 4: 验证

```bash
openclaw status | grep -i explorer
# 应能看到 4 agents
```

---

## 七、与旧系统对比

| 维度 | 旧系统（子 Agent 随 session 关闭丢失） | 新系统（探索 Agent） |
|------|:-------------------------------------:|:-------------------:|
| 发现保存 | session 关闭即丢 | findings/ 持久化 |
| 工具集 | 无隔离（子 Agent 沿用主 Agent 工具） | read + web 白名单，零写权限 |
| 输出格式 | 自由文本 | 结构化 JSON |
| 可审计性 | 无 | findings/archive/ 保留审计日志 |
| 超时控制 | 无 | 15 分钟强制超时 |
| 并发 | 无限制 | 串行（maxConcurrent: 1） |

---

## 相关文档

- 验证 Agent 设计：`designs/verifier-agent-design.md`

---

*终稿：2026-07-25 · 待先生确认后落地*
