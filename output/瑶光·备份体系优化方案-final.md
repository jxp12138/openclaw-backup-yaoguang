# 瑶光·备份体系优化方案

> 版本：final（GLM × DeepSeek 共识，先生确认）
> 日期：2026-07-28
> 前置：三层三地备份架构 + 安全基线的备份部分

---

## 一、事故发生背景

2026 年 7 月初，云端瑶光在修改配置时因 Key 配置错误导致断联。本地瑶光尝试修复失败，先生过度信任瑶光能力延误了介入时机。最终不得不重新在云端部署，损失了一部分瑶光与先生之间的记忆。

此事故直接催生了：
- 每日 GitHub 自动备份（workspace git add -A + push）
- 每日 03:00 tar 打包（memory/ / long-term/ / transcripts/ / scripts/）
- 多 Agent 协作系统

但当前备份体系仍有致命盲区。

---

## 二、当前备份状态盘点

### ✅ 已有覆盖

| 项 | 方式 | 评价 |
|----|------|------|
| workspace 代码/配置 | `git add -A` + `git push` 每日 04:00 | 好 |
| 每日日志 memory/ | `git add -A` 覆盖 + 03:00 tar 覆盖 | 好 |
| 长期记忆 long-term/ | 同上 | 好 |
| 会话记录 transcripts/ | 03:00 tar 覆盖（sessions.db） | 好 |
| Dreaming 候选 | `git add -A` 覆盖 | 好 |

### ❌ 致命盲区（按优先级排序）

| 优先级 | 盲区项 | 位置 | 影响说明 |
|--------|--------|------|---------|
| **P0** | **openclaw.json** | `~/.openclaw/openclaw.json` | **不在 workspace 内**，git 不跟踪，tar 不包含。所有模型配置、Agent 定义、API Key 全在里面。服务器挂掉 → 瑶光骨架丢失 |
| **P0** | **yg-knowledge 知识库** | `~/yg-knowledge/` | 已配 GitHub remote（yg-knowledge 仓库），但 **无自动推送 cron**，当前仅 1 次手动 commit。无自动备份 = 无备份 |
| **P1** | **Nginx 配置** | `/etc/nginx/sites-available/jxpyaoguang` | SSL/域名/反向代理配置不备份，重部署时需手动恢复 |
| **P1** | **Crontab 配置** | 系统 crontab | 每日备份和 tar 的 cron 未导出，重装时遗忘 |
| **P1** | **变更前快照** | 不存在 | 每次改配置前无自动存档，改坏了回退困难 |
| **P2** | **API Key 加密** | openclaw.json 中明文 | 备份到 GitHub 后有泄露风险（私有仓库低概率，但存在） |
| **P2** | **恢复剧本** | 不存在 | 没有标准化的恢复流程文档 |
| **P2** | **消防演习** | 从未执行 | 恢复流程未经实际验证 |

---

## 三、三层三地备份架构

### Layer 1：变更前快照（新）

在每次修改 `openclaw.json` 等关键配置前，自动触发：

```bash
cp ~/.openclaw/openclaw.json ~/.openclaw/workspace/snapshots/openclaw.json.$(date +%Y%m%d_%H%M%S)
```

- 目录：`workspace/snapshots/`
- 保留期：30 天，过期自动删除
- 触发方式：手动（当前）或 Gateway hook（未来）

### Layer 2：每日全量备份（优化现有）

保留现有 3 层，补充：

| 时间 | 内容 | 方式 | 保留期 |
|------|------|------|--------|
| 03:00 | workspace 关键文件 tar | tar + gzip → /tmp/ | 7 天 |
| 04:00 | workspace git add -A + push | `daily-git-backup.sh` | 永久 |
| **新 04:30** | **openclaw.json 副本** | `cp ~/.openclaw/openclaw.json → workspace/config-backup/` | 永久（git 托管后） |
| **新 04:30** | **yg-knowledge auto-push** | `cd ~/yg-knowledge && git add -A && git commit && git push` | 永久 |
| **新 04:30** | **Nginx 配置 + crontab 导出** | cp + crontab -l → workspace/config-backup/ | 永久 |

### Layer 3：周归档（新）

每周日 05:00 全量打包（含加密敏感文件），异地存档：

```bash
# 敏感文件加密后入包
tar czf /tmp/full-backup-$(date +%Y%m%d).tar.gz \
  ~/.openclaw/openclaw.json.gpg \
  ~/.openclaw/workspace/ \
  ~/yg-knowledge/ \
  /etc/nginx/sites-available/jxpyaoguang

# 加密：gpg --symmetric --cipher-algo AES256 openclaw.json
# 解密：gpg --decrypt openclaw.json.gpg > openclaw.json
```

- 保留期：90 天（12 个归档）
- 异地：GitHub (workspace) + GitHub (yg-knowledge) = 已异地
- GPG 密码：先生保管（仅手动恢复时使用）

---

## 四、执行步骤（两步走）

### 第一步：立刻执行（今晚/明天）——先备份，再安全

**P0（立即，不开机就做）：**

| # | 任务 | 命令 |
|---|------|------|
| 0.1 | 创建 config-backup/ 目录 | `mkdir -p workspace/config-backup/` |
| 0.2 | 复制 openclaw.json | `cp ~/.openclaw/openclaw.json workspace/config-backup/openclaw.json` |
| 0.3 | 确认 openclaw.json 已进入 workspace | `ls -la workspace/config-backup/openclaw.json` |
| 0.4 | 建立 snapshots/ 目录 | `mkdir -p workspace/snapshots/` |
| 0.5 | yg-knowledge 加自动推送 cron | `cd ~/yg-knowledge && git add -A && git commit -m"auto $(date +%Y%m%d)" && git push` |
| 0.6 | 验证 git push 成功 | 查看 GitHub 仓库已更新 |

**P1（第一步内完成）：**

| # | 任务 |
|---|------|
| 1.1 | 导出 Nginx 配置到 config-backup/ |
| 1.2 | 导出 crontab 到 config-backup/ |
| 1.3 | 创建变更前快照脚本 |
| 1.4 | 更新 daily-git-backup.sh 加入新备份项 |

### 第二步：第一步之后

| # | 任务 | 说明 |
|---|------|------|
| 2.1 | API Key 加密存储（GPG） | 备份后清理 git 历史中的明文 Key，替换为 .env 环境变量注入 |
| 2.2 | 写 3 个恢复剧本 | Playbook A（配置损坏 < 2min）、B（GitHub 恢复 15-30min）、C（完全重建 1-2h） |
| 2.3 | emergency-recovery 技能 | 给本地瑶光写一个技能：读取 config-backup/ 恢复关键配置 |
| 2.4 | 消防演习 | 模拟一次断联 + 本地瑶光恢复全过程 |

> **关键原则：第一步先备份（含明文），第二步再清历史铲平安全风险。** 两害相权取其轻——私有仓库泄露 Key 的概率远低于服务器挂了没备份的风险。

---

## 五、三层三地架构总图

```
时间轴 → 变更前 → 每日 → 周日
           │        │       │
Layer 1   快照      │       │
(snapshot) cp JSON  │       │
           │        │       │
Layer 2    │      git push  │
(daily)    │      tar打包   │
           │      yg自动    │
           │      同步       │
           │        │       │
Layer 3    │        │    全量加密
(weekly)   │        │    异地存档
           │        │       │
保留期    30天      永久    90天
```

---

## 六、恢复剧本（待写）

| 剧本 | 场景 | 预计耗时 | 依赖 |
|------|------|---------|------|
| **A** | 配置改坏了但服务器还在 | < 2 分钟 | snapshots/ + git checkout |
| **B** | 服务器挂，GitHub 备份完整 | 15-30 分钟 | git clone + cp config-backup/ |
| **C** | 服务器挂 + 需从周归档恢复 | 1-2 小时 | Layer 3 GPG 解密 + 全量恢复 |

---

> *文档版本：final · 2026-07-28 · 基于 DeepSeek 现状验证 × GLM-5.1 评审 × 先生决策*
> 
> *以"先备份再安全"为第一原则*
