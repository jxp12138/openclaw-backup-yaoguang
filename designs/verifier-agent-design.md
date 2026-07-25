# 验证 Agent 设计方案（终稿）

> 基于 2026-07-25 三轮探讨（瑶光技术审 → 旧 GLM 逻辑审 → Cherry GLM 综合审 → 先生裁决）
> 终稿日期：2026-07-25

---

## 一、Agent 定位

验证 Agent（verifier）是多 Agent 协作系统中的**机械核对节点**。不做探索、不做判断、不写长期记忆。唯一职责：按照三对照方法，核对需求↔方案↔实际产出的一致性。

验证 Agent 是**持久 Agent**（与 GLM 同级别），不是瑶光 spawn 的子 Agent。

---

## 二、Agent 定义

### 激活机制

验证 Agent 不轮询。由瑶光通过 `sessions_send` 通知：

```
Step 1: 瑶光写完 handoff/ 验证包
        → sessions_send(sessionKey="agent:verifier:main")
        → 消息摘要："新验证包：handoff/verify-xxx.md，待验证"

Step 2: 验证 Agent 收到消息 → 读取 handoff/ → 执行三对照核验
        → 把完整核查结果写入 findings/
        → sessions_send 回瑶光："验证完成，结果见 findings/xxx-verdict.md"
```

### 工具白名单

依据两方 GLM 评审共识 + 先生裁决：

```json5
{
  id: "verifier",
  model: "deepseek/deepseek-v4-flash",   // 继承主 Agent 模型
  workspace: "~/.openclaw/workspace-verifier",
  sandbox: {
    mode: "all",
    scope: "session",
    workspaceAccess: "rw"
  },
  tools: {
    allow: [
      "read",            // 读文件/配置/代码
      "write",           // 写 findings/（影响限在沙箱内）
      "exec",            // 执行 git diff/grep/curl（沙箱隔离）
      "web_search",      // 补充验证搜索
      "web_fetch",       // 获取参考文档
      "sessions_send",   // 用于接收唤醒消息 + 完成后回传状态
      "memory_search"    // 搜索记忆中的需求/方案参考
    ],
    deny: [
      "edit",            // 禁止编辑文件（隐蔽修改风险高）
      "apply_patch",     // 禁止打补丁
      "cron",            // 禁止操作定时任务
      "gateway",         // 禁止操作配置
      "nodes",           // 禁止访问节点
      "sessions_spawn",  // 禁止 spawn 子 Agent
      "sessions_list",   // 禁止查看 session 列表
      "sessions_history", // 禁止读 session 历史
      "session_status",  // 禁止查询 session 状态
      "subagents",       // 禁止操作子 Agent
      "message",         // 禁止发消息
      "image_generate",  // 禁止生图
      "video_generate",  // 禁止生视频
      "feishu_chat",     // 禁止飞书操作
      "feishu_doc",      // 禁止飞书文档
      "feishu_drive",    // 禁止飞书云盘
      "feishu_wiki",     // 禁止飞书知识库
      "pdf",             // 不需要
      "tts"              // 不需要
    ]
  }
}
```

### exec 安全约束（五层）

| 层级 | 约束类型 | 内容 | 来源 |
|:----:|:--------:|------|:----:|
| 第一层 | 硬约束 | Tool policy deny：edit/apply_patch/cron/gateway（平台拦截） | 飞书 GLM |
| 第二层 | 硬约束 | **Sandbox workspaceAccess="rw"**：bash 重定向损害限在沙箱内，不触及宿主机 | 飞书 GLM |
| 第三层 | 软约束 | System Prompt RAII 命令白名单（git diff, grep, curl, diff） | 双方一致 |
| 第四层 | 软约束 | **强制命令日志**：每条 exec 执行前先在验证报告中记录命令全文，再执行 | Cherry GLM |
| 第五层 | 事后 | 先生直查看 exec 记录 + Auditor 审计 raw_output 覆盖率 | 双方一致 |

Sandbox 是关键补丁——exec 的 shell 重定向（`>` / `>>`）可以通过 bash 绕过 write 工具的 deny，但 sandbox 将其限制在容器内，不触及宿主机。

---

## 三、Workspace

### 目录结构（先生确认：最小化）

```
~/.openclaw/workspace-verifier/
├── AGENTS.md           ← 行为准则
├── TOOLS.md            ← 留空
├── findings/           ← 验证结果输出目录
└── refs/               ← 只读参考文档副本（配置模板、接口规范等）
```

- workspace 只包含 findings/ + refs/（只读） + 自身配置
- findings/ 是符号链接，指向主 workspace 的 `findings/` 目录
  使先生可通过统一的 `findings/` 一次性查看所有 Agent 产出（探索/验证/GLM/Auditor）
- 不包含完整项目 workspace，避免信息污染
- Sandbox 内 workspaceAccess="rw" 意味着验证 Agent 的 write 只能写入此目录

### findings 文件生命周期

同探索 Agent 方案：

| 阶段 | 触发条件 | 行为 | 可逆 |
|------|---------|------|:----:|
| 活跃 | 写入至今 ≤ 7 天 | 位于 `findings/` | - |
| 归档 | age > 7 天 | 自动移到 `findings/archive/` | ✅ |
| 建议删除 | age > 60 天 | Auditor 列出 "建议删除" | ✅ |
| 删除 | 先生确认 | 删除 | ❌ |

### findings 文件名格式

```
findings/verifier-verify-<简述任务>_YYYYMMDD_HHMMSS.json
```

示例：`findings/verifier-verify-gateway-hardening_20260725_143000.json`

### findings 数据结构（验证 Agent 写入 — 遵循v3.1统一格式）

```json
{
  "meta": {
    "source": "verifier",
    "task_id": "verify-xxx",
    "timestamp": "2026-07-25T10:05:48+08:00",
    "duration_seconds": 120,
    "status": "completed"
  },
  "summary": "验证摘要",
  "overall_result": "PASS|FAIL|PARTIAL",
  "findings": [
    {
      "id": "V-001",
      "category": "verification",
      "title": "发现标题",
      "detail": "发现描述（≤500字）",
      "evidence": "用于核对的原始输出片段（关键摘录）",
      "raw_file_path": "关联的源文件路径（可选）",
      "priority": "high|medium|low",
      "actionable": true|false,
      "status": "new|extracted|archived"
    }
  ],
  "agent_specific": {
    "verification_brief": "验证简述",
    "three_way_comparison": {
      "requirement_to_plan": {
        "verdict": "PASS|FAIL|PARTIAL",
        "missing_detail": "详细说明"
      },
      "plan_to_actual": {
        "verdict": "PASS|FAIL|PARTIAL",
        "missing_detail": "详细说明"
      },
      "requirement_to_actual": {
        "verdict": "PASS|FAIL|PARTIAL",
        "unsatisfied_detail": "详细说明"
      }
    },
    "execution_log": [
      {
        "command": "实际执行的完整命令",
        "timestamp": "执行时间",
        "exit_code": 0,
        "output_truncated": true|false
      }
    ],
    "blockers": [
      {
        "description": "阻塞描述",
        "severity": "critical|major|minor"
      }
    ]
  },
  "unexplored": [],
  "anomalies": []
}
```

---

## 四、验证方法论：三对照

### 核验流程

```
Step 1: 读 handoff/ 验证包
Step 2: 提取：需求描述 → 方案描述 → 实际产出条件
Step 3: 机械核对：
        A. 需求 → 方案：需求中每一条是否在方案中有所体现
        B. 方案 → 实际产出：方案中每个设计点是否已落地/配置到位
        C. 需求 → 实际产出：跳过方案，直接看需求是否满足
Step 4: 产出结论 + 证据 → 写入 findings/
Step 5: sessions_send 通知瑶光
```

### 输出规范

- 每条 finding 必须有 `raw_output` 证据（不做无证据的判定）
- `execution_log` 记录每条执行的命令（强制命令日志）
- 三对照矩阵的 verdict 为 PASS/FAIL/PARTIAL，附 detail 说明

---

## 五、防偷懒机制（四铁律）

1. **铁律 1：每条 finding 都要求 raw_output** — 无原始证据的 finding 不输出
2. **铁律 2：每条 exec 预记录到 execution_log** — 先报告后执行，审计可追踪
3. **铁律 3：验证不通过直接 escalate 到先生** — 不代瑶光做决策
4. **铁律 4：三对照矩阵必填** — 缺少任何一个对照维度，输出不完整

### 输出前 7 项自检

1. 三对照矩阵的 verdict 是否都有 detail 说明？
2. 每条 finding 是否有 raw_output 证据？
3. execution_log 是否覆盖了所有执行的命令？
4. PASS 判定是否有支持证据（不假设"没发现=没问题"）？
5. FAIL/PARTIAL 判定是否识别了具体哪条不满足？
6. 验证失败时是否明确了 escalate 路径？
7. 引用路径是否为绝对路径或可复现路径？

---

## 六、Agent 间约束协议

**先生裁决：软约束。** 核心原则：

- **信息义务（软）**：发现问题时通知相关 Agent 和先生，但不强制对方等待
- **透明义务（软）**：核对结果写入 findings/（先生直查看），其他 Agent 可读但不强制读
- **escalation 规则（软）**：🔴 级别问题 escalate 到先生，先生裁决后通知其他 Agent

---

## 七、部署预研

### 部署步骤

```bash
Step 1: mkdir -p ~/.openclaw/workspace-verifier/{findings,refs}
Step 2: 写入 AGENTS.md（行为准则 + 三对照方法 + 防偷懒四铁律）
Step 3: 在 openclaw.json agents.list[] 新增 verifier 条目
Step 4: 如在非沙箱环境，先配置 Docker sandbox
Step 5: 重启 Gateway
Step 6: 验证：openclaw status | grep verifier
```

### 安装沙箱的条件

验证 Agent 依赖 sandbox 做安全兜底。沙箱搭建：
- 需要 Docker daemon
- 需要 sandbox 镜像 `openclaw-sandbox:bookworm-slim`
- 需要验证 Agent 专用 workspace

---

## 八、设计决策记录

| 决策项 | 结论 | 裁决者 |
|:------:|:----:|:------:|
| B 方向（事后程序性约束） | ✅ 采用 | 先生 |
| exec 是否保留 | ✅ 保留，五层安全约束 | 先生 |
| sandbox 方案 | workspaceAccess="rw" | 先生 |
| Agent 间约束类型 | 软约束（信息/透明/escalation） | 先生 |
| workspace 范围 | findings/ + refs/ + 自身配置 | 先生 |
| 强制命令日志 | ✅ 每条 exec 预记录（Cherry GLM 补丁） | 双方 GLM 一致 |
| 验证失败处理 | direct escalate 到先生 | 双方 GLM 一致 |
| 激活机制 | sessions_send 唤醒，不轮询 | 双方 GLM 一致 |
| 输出格式 | 结构化 JSON + execution_log | 双方 GLM 一致 |
