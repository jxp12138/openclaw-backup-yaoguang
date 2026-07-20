#!/bin/bash
# session_flush.sh — 将当前 session 消息写入 daily notes
# 使用方式：bash scripts/session_flush.sh <session_id> <session_title> <message_summary>
#
# 写入位置：memory/YYYY-MM-DD.md
# 每条记录含时间戳、session_id、消息摘要

WORKSPACE="$HOME/.openclaw/workspace"
LOG="$WORKSPACE/scripts/.memory.log"
SESSION_ID="${1:-unknown}"
SESSION_TITLE="${2:-无标题}"
MESSAGE_SUMMARY="${3:-无摘要}"
DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%H:%M')
DAILY_FILE="$WORKSPACE/memory/$DATE.md"

mkdir -p "$WORKSPACE/memory"

{
  echo ""
  echo "## [$TIME] session: $SESSION_ID"
  echo "### $SESSION_TITLE"
  echo ""
  echo "$MESSAGE_SUMMARY"
  echo ""
} >> "$DAILY_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ flush: $SESSION_ID -> $DAILY_FILE" >> "$LOG"
