#!/bin/bash
# daily-git-backup.sh — 每日自动备份工作区到 git
# 绕过模型调用，由系统 crontab 直跑
#
# 安装方式（需 root/sudo）：
#   crontab -e 添加：0 4 * * * /home/ubuntu/.openclaw/workspace/scripts/daily-git-backup.sh

WORKSPACE="$HOME/.openclaw/workspace"
LOG="$WORKSPACE/scripts/.git-backup.log"

cd "$WORKSPACE" || exit 1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始备份" >> "$LOG"

# 添加所有变更
git add -A >> "$LOG" 2>&1

# 检查是否有变更需要提交
if git diff --cached --quiet; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 无变更，跳过提交" >> "$LOG"
    exit 0
fi

# 提交
git commit -m "auto-backup $(date '+%Y-%m-%d %H:%M')" >> "$LOG" 2>&1

# 推送（如果有 remote）
if git remote -v | grep -q origin; then
    git push origin main >> "$LOG" 2>&1 || echo "WARN: push 失败（可能无网络或无权限）" >> "$LOG"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份完成" >> "$LOG"
