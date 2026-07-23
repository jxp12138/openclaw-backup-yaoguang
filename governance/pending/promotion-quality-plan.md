# 自动 promoted 质量门槛方案（草案）

> 基于 2026-07-23 07:31 先生与瑶光的讨论
> 待 16:00 继续细化

## 背景

Reflector 第五次反思产出 G36 建议：MEMORY.md 自动 promoted 无质量门槛，近期 4 条低分条目（score=0.803）已进入 MEMORY.md，存在膨胀风险。

## 方案（三层分流 + 每周自动清理）

### 分层标准

| 分数范围 | 处理 | 说明 |
|---------|------|------|
| score ≥ 0.85 | 🟢 自动提升到 MEMORY.md | 和现在一样 |
| 0.70 ≤ score < 0.85 | 🟡 进入待审池（pending-promotion.md） | 关键改动：低分条目不死，留下缓冲期 |
| score < 0.70 | 🔴 直接丢弃 | Dreaming 系统自己都没信心 |

### 待审池自动清理规则（Reflector 每周扫一次）

| 条件 | 处理 |
|------|------|
| 超过 1 周 + 无人引用 (recalls=0) | 🗑️ 自动删除 |
| 有人引用过 | 🟢 自动提升 |
| 与已有记录冲突/重复 | ⚠️ 列出交给先生裁决 |

### 优势
- 不遗漏紧急但低分的条目（先生忙起来的内容照样能留下来观察）
- 自动清理不增加手动工作
- 冲突感知，避免决策矛盾

### 待定细节（晚间讨论）
- [x] 待审池文件格式和位置（已落地：governance/pending/promotion-pool.yaml，YAML 完整读写）
- [ ] Reflector 扫描的具体时机（和现有周扫描的关系）
- [ ] 首轮存量清理：现有 4 条低分条目如何处理

## 落地实现

### 待审池
- 文件: governance/pending/promotion-pool.yaml
- 格式: YAML list（完整读写追加）
- 状态机: pending → promoted / discarded / disputed
- 生命周期:
  - promoted: 7天后从 YAML 删除
  - discarded: 3天后从 YAML 删除
  - disputed: 不设自动过期，等先生裁决

### 扫描
- 频率: 每天 03:00（Reflector 现有运行时间）
- recalls: Reflector 被动计算（关键词匹配）
- scan 日志: governance/pending/scan-log.md（独立文件）

### 阈值可配置
auto_promote: 0.85
pending_min: 0.70

### 写入协议
- Dreaming 先追加 → Reflector 后更新
- 原子写：write to temp → rename to target
- 去重：追加前比对已有条目 summary，相似 >0.8 合并
