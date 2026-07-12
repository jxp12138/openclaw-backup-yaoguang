#!/bin/bash
# session_snapshot.sh — 将会话摘要写入 sessions.db（session 结束时间）
# 用法：./session_snapshot.sh <session_id> <摘要内容>
#
# 写入 role='system'，content 标记 '[session_snapshot]' 以区分于 flush 记录。
# 主要用于 search 检索入口，Background Review 的主数据源是 flush 写入的原始消息。

if [ $# -lt 2 ]; then
    echo "Usage: $0 <session_id> <摘要内容>"
    exit 1
fi

SESSION_ID="$1"
shift
CONTENT="$*"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HEARTBEAT=~/.openclaw/workspace/scripts/.heartbeat.log
DB=~/.openclaw/workspace/transcripts/sessions.db

ESCAPED=$(echo "$CONTENT" | sed "s/'/''/g")

sqlite3 "$DB" \
 "INSERT INTO messages (session_id, role, content, created_at) \
  VALUES ('$SESSION_ID', 'system',\
   '[session_snapshot] $TIMESTAMP: $ESCAPED',\
   '$TIMESTAMP');"

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "$TIMESTAMP | snapshot | OK | $SESSION_ID" >> "$HEARTBEAT"
    echo "OK: snapshot written to $SESSION_ID"
else
    echo "$TIMESTAMP | snapshot | FAIL | $SESSION_ID | exit $EXIT_CODE" >> "$HEARTBEAT"
    echo "FAIL: sqlite3 exit code $EXIT_CODE" >&2
    exit $EXIT_CODE
fi
