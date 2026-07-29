#!/bin/bash
# daily-git-backup.sh — 每日自动备份工作区到 git
# 绕过模型调用，由系统 crontab 直跑
#
# 安装方式（需 root/sudo）：
#   crontab -e 添加：0 4 * * * /home/ubuntu/.openclaw/workspace/scripts/daily-git-backup.sh
#
# v2.2 更新：加入 openclaw.json / nginx / crontab 副本到 config-backup/

WORKSPACE="$HOME/.openclaw/workspace"
CONFIG_BACKUP_DIR="$WORKSPACE/config-backup"
LOG="$WORKSPACE/scripts/.git-backup.log"

cd "$WORKSPACE" || exit 1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始备份" >> "$LOG"

# ===== 配置副本（v2.2 新增）=====
# 将关键配置复制到 workspace 内，以便 git add -A 跟踪
mkdir -p "$CONFIG_BACKUP_DIR"

# openclaw.json — 核心配置
cp "$HOME/.openclaw/openclaw.json" "$CONFIG_BACKUP_DIR/openclaw.json" 2>/dev/null && \
  echo "  cp openclaw.json" >> "$LOG" || \
  echo "  WARN: openclaw.json 复制失败" >> "$LOG"

# Nginx 配置
cp "/etc/nginx/sites-available/jxpyaoguang" "$CONFIG_BACKUP_DIR/jxpyaoguang" 2>/dev/null && \
  echo "  cp nginx conf" >> "$LOG" || \
  echo "  WARN: nginx 配置复制失败" >> "$LOG"

# crontab 列表
crontab -l > "$CONFIG_BACKUP_DIR/crontab.txt" 2>/dev/null && \
  echo "  crontab 导出" >> "$LOG" || \
  echo "  WARN: crontab 导出失败" >> "$LOG"

# ===== git add（带上 config-backup/ 的新文件）=====
git add -A >> "$LOG" 2>&1

# ===== 检查变更 =====
if git diff --cached --quiet; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 无变更，跳过提交" >> "$LOG"
    exit 0
fi

# ===== 提交 =====
git commit -m "auto-backup $(date '+%Y-%m-%d %H:%M')" >> "$LOG" 2>&1

# ===== 推送 =====
if git remote -v | grep -q origin; then
    # 添加超时防止 SSH/GitHub 连接挂死
    timeout 30 git push origin master >> "$LOG" 2>&1 || echo "WARN: push 失败（超时或无网络或无权限）" >> "$LOG"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份完成" >> "$LOG"
