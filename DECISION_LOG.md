# DECISION_LOG — 决策日志

> 创建：2026-08-02（元管理层 v1.1 第 3 步，升级自 long-term/feedback-log.md）
> 维护：瑶光 | 审阅：先生 | 评审：GLM
> 编号规则：从 DEC-007 开始（前 6 条在 long-term/feedback-log.md，冻结不搬迁）
> 写入纪律：🔴/🟡 级决策当日写入；P0 紧急修复先修后补（24h 内）

---

## 决策条目

### DEC-007 — 2026-08-02 采纳元管理层 v1.1 [decision:meta-layer] [tag:META]

**背景：**
- 三大问题（全局协同缺失/反馈机制缺失/主导者依赖全知）经先生总结、GLM 分析，确诊为"系统缺协调层"
- GLM 提出元管理层概念（项目地图/版本账本/心跳监控/决策日志），先生主导三轮迭代：v1.0 对照表 → GLM 评审 → v1.1 最终方案

**决策：**
- 建立元管理层 META（协调层，非第四支柱）
- 四模块落地：PROJECT_MAP / VERSION_LEDGER / 心跳 L0-L2 / DECISION_LOG
- 纪律挂靠：核心规则写 AGENTS.md（运行时可达），完整版存 governance/rules.md
- 第 6 步清理（reflector 退役等）待先生单独授权

**理由：**
- 状态显式化后，先生只需裁决不需记忆（解决能力担忧）
- 漂移账本把"文档声称 vs 实际存在"的偏差显式化（对治版本协同缺失）
- 心跳 L2 提供主动检查（对治反馈机制缺失）

**影响范围：**
- 全部项目（META 为协调层）；AGENTS.md 规则下会话起生效；governance/rules.md 追加纪律

**后续观察（1 周验证期）：**
- 观察项 1：账本漂移率下降（Day1 100% → 清理后 ≤20%）
- 观察项 2：无新增"声称未建"类漂移（DRIFT-002 类）
- 观察项 3：L2 周对账运行 1 次且无误报
- 观察项 4："元管理层第一课"要点是否被执行验证

**验证结果：** <验证期结束回填>

---

### DEC-011 — 2026-08-03 G64 promotion 阈值提升至 0.85 [decision:cogn] [tag:COGN]

**背景：**
- G64 堆积 6 天（07-29 提出），08-03 升级 🔴：MEMORY.md 连续 2 天单日 +13 行/+1.1KB，按增速 08-07 逼近 200 行上限
- 根因：dreaming deep 阶段 promotion 默认阈值 0.80，score 0.803/0.811 的纯模板日志（"每日自动Flush"/"session 结束"）被自动 promoted 进 MEMORY.md

**决策：**
- promotion 阈值 0.80 → 0.85（plugins.entries.memory-core.config.dreaming.phases.deep.minScore，方案文档既定值 auto_promote: 0.85）
- 存量清理：删除 08-01~08-03 三批 14 条模板日志条目（score<0.85 且 recalls=0），合并为 1 行摘要
- 有实际价值的低分条目（07-19 多Agent架构 score=0.840 / 07-17 日志 score=0.847，recalls=3）保留不删

**理由：**
- 0.85 已能过滤全部现存模板日志（最高 0.811），无需 0.90 误伤中价值条目
- 与 promotion-quality-plan.md 三层分流方案（≥0.85 自动提升）一致

**影响范围：**
- MEMORY.md 长期记忆质量；Dreaming 自动 promotion 行为

**验证结果：** 配置 hash 已更新生效；MEMORY.md 11.3KB → 8.4KB（-33 行）；VERSION_LEDGER DRIFT-009 → 已解决

---

## 待写条目（提醒位）

- [ ] DEC-008：第 6 步清理执行决策（先生授权后写）
- [ ] DEC-009：COGN Phase 2 决策（老化回收+待审池，先生与 GLM 讨论后写；G64 已拆出单独解决）
- [ ] DEC-010：第零章/3-A 启动优先级决策（先生定后写）
