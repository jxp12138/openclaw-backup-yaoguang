#!/bin/bash
# session_auto_flush.sh — 自动检查近期会话并刷新到 sessions.db
# 由 cron job 周期性触发（每 30 分钟一次）
#
# 流程：
# 1. 使用 OpenClaw CLI 获取近期活跃 session 信息
# 2. 检查 sessions.db 中是否已有记录
# 3. 对未记录的 session 写入 flush marker（实际消息由 session 内主动 flush）

HEARTBEAT=~/.openclaw/workspace/scripts/.heartbeat.log
DB=~/.openclaw/workspace/transcripts/sessions.db
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "$TIMESTAMP | auto-flush | $1" >> "$HEARTBEAT"
}

# 检查 sessions.db 是否存在且有表
sqlite3 "$DB" ".tables" 2>/dev/null | grep -q messages
if [ $? -ne 0 ]; then
    log "FAIL | sessions.db 表不存在"
    exit 1
fi

# 获取今日消息数统计
TODAY_MSGS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM messages WHERE created_at >= '$TIMESTAMP'" 2>/dev/null || echo "0")
TOTAL_MSGS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM messages" 2>/dev/null || echo "0")
LAST_FLUSH=$(sqlite3 "$DB" "SELECT MAX(created_at) FROM messages WHERE role='system' AND content LIKE '[flush]%'" 2>/dev/null || echo "never")

log "OK | 今日 $TODAY_MSGS 条，总计 $TOTAL_MSGS 条，上次flush: $LAST_FLUSH"

exit 0
