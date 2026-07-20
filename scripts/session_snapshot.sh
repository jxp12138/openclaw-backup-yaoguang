#!/bin/bash
# session_snapshot.sh — session 结束时写入摘要到 daily notes
# 使用方式：bash scripts/session_snapshot.sh <session_id> <summary_file>
#
# 写入位置：memory/YYYY-MM-DD.md
# 包含：起止时间、会话轮数、关键决策

WORKSPACE="$HOME/.openclaw/workspace"
LOG="$WORKSPACE/scripts/.memory.log"
SESSION_ID="${1:-unknown}"
SUMMARY="${2:-无摘要}"
DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%H:%M')
DAILY_FILE="$WORKSPACE/memory/$DATE.md"

mkdir -p "$WORKSPACE/memory"

{
  echo ""
  echo "---"
  echo "## [$TIME] session 结束: $SESSION_ID"
  echo ""
  echo "$SUMMARY"
  echo ""
  echo "_snapshot at $TIME_"
  echo ""
} >> "$DAILY_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ snapshot: $SESSION_ID -> $DAILY_FILE" >> "$LOG"
