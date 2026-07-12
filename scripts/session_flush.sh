#!/bin/bash
# session_flush.sh — 将原始对话消息写入 sessions.db
# 用法：./session_flush.sh <session_id> <消息内容>
#
# 消息内容将经过单引号转义后写入 messages 表，
# FTS5 触发器会自动建立 trigram 索引。
#
# 写操作记录到 .heartbeat.log。

if [ $# -lt 2 ]; then
    echo "Usage: $0 <session_id> <消息内容>"
    echo "  session_id: 会话 ID（如 20260712-001）"
    exit 1
fi

SESSION_ID="$1"
shift
CONTENT="$*"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HEARTBEAT=~/.openclaw/workspace/scripts/.heartbeat.log
DB=~/.openclaw/workspace/transcripts/sessions.db

# 转义单引号（SQLite 中单引号用两个单引号表示）
ESCAPED=$(echo "$CONTENT" | sed "s/'/''/g")

# 写入 sessions.db
sqlite3 "$DB" \
 "INSERT INTO messages (session_id, role, content, created_at) \
  VALUES ('$SESSION_ID', 'system',\
   '[flush] $TIMESTAMP: $ESCAPED',\
   '$TIMESTAMP');"

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "$TIMESTAMP | flush | OK | $SESSION_ID" >> "$HEARTBEAT"
    echo "OK: flush written to $SESSION_ID"
else
    echo "$TIMESTAMP | flush | FAIL | $SESSION_ID | exit $EXIT_CODE" >> "$HEARTBEAT"
    echo "FAIL: sqlite3 exit code $EXIT_CODE" >&2
    exit $EXIT_CODE
fi
