# 待审池实施方案

> 基于先生 07-23 讨论 + DeepSeek 预评审
> 状态：待先生确认后落地

---

## 一、文件位置

**`governance/pending/promotion-pool.yaml`**

理由：
- 不污染 `memory/` 目录，memory_search 搜索不到未确认的候选条目
- 与现有的 `promotion-quality-plan.md` 同目录，语义统一
- 在 MEMORY.md 中加一行索引：「待审池 → governance/pending/promotion-pool.yaml」

---

## 二、文件格式（YAML 结构化）

```yaml
# Pending Promotion Pool
# status: pending | promoted | discarded | disputed

entries:
  - date: 2026-07-23
    score: 0.78
    recalls: 0
    status: pending
    source: memory/2026-07-23.md
    summary: "先生提到想做一个智能家居联动方案"
```

| 字段 | 用途 | 写入者 |
|------|------|--------|
| date | 条目创建日期 | Dreaming 追加时 |
| score | Dreaming 评分 | Dreaming |
| recalls | 被引用次数 | Reflector 每日扫描更新 |
| status | pending / promoted / discarded / disputed | Reflector 更新 |
| source | 原始 daily note 文件名 | Dreaming |
| summary | 内容摘要（含足量原文） | Dreaming |

---

## 三、status 状态机

```
         ┌─────────┐
         │ pending │ ← Dreaming 写入时
         └────┬────┘
              │
     ┌────────┼────────┐
     ▼        ▼        ▼
 ┌──────┐ ┌──────┐ ┌────────┐
 │promoted│ │discard│ │disputed│ ← 冲突时先生裁决
 └──────┘ └──────┘ └────────┘
```

- **promoted**：确认提升到 MEMORY.md (有引用或高分)
- **discarded**：超 1 周无人引用
- **disputed**：与已有记录冲突，等先生裁决

---

## 四、目录结构

```
governance/pending/
├── promotion-quality-plan.md   ← 方案描述（已有）
├── promotion-pool.yaml         ← 待审池数据（本文件）
└── scan-log.md                 ← Reflector 每日扫描日志
```

---

## 五、执行计划

| 步骤 | 内容 | 谁来 |
|:----:|------|:----:|
| 1 | 创建 `promotion-pool.yaml` | 我 |
| 2 | 创建 `scan-log.md` | 我 |
| 3 | MEMORY.md 加一行索引 | 我 |
| 4 | 配置每日 Reflector 多一步待审池扫描 | 下次改 Reflector 配置时 |
| 5 | 现有 4 条低分条目 | 先生周六处理 |
