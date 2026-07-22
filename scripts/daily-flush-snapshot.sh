#!/bin/bash
# daily-flush-snapshot.sh — 每日 22:45 自动执行记忆 Flush + Snapshot
# 被系统 crontab 调用，无需外部参数
#
# 职责：
#   1. 检查今日是否有活跃 session，生成摘要
#   2. 调用 session_flush.sh 写入今日日志
#   3. 调用 session_snapshot.sh 写入日结束标记
#
# 写入位置：memory/YYYY-MM-DD.md

WORKSPACE="$HOME/.openclaw/workspace"
LOG="$WORKSPACE/scripts/.memory.log"
DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%H:%M')
SESSION_ID="cron-daily-${DATE}"
TITLE="每日自动Flush"
DAILY_FILE="$WORKSPACE/memory/${DATE}.md"

mkdir -p "$WORKSPACE/memory"

# ——— Step 1: 收集今日概要 ———
# 获取今日对话轮数和文件大小
SESSION_COUNT=0
DAILY_SIZE="?"
if [ -f "$DAILY_FILE" ]; then
  SESSION_COUNT=$(grep -c "^## \[" "$DAILY_FILE" 2>/dev/null || echo 0)
  DAILY_SIZE=$(du -h "$DAILY_FILE" 2>/dev/null | cut -f1)
fi

SUMMARY=$(cat <<EOS
**自动每日检查点**
- 时间: $DATE $TIME
- 今日已有日志条目: ${SESSION_COUNT}
- 今日日志文件大小: ${DAILY_SIZE}
- 来源: daily-flush-snapshot cron trigger
- 状态: 系统正常运行
EOS
)

# ——— Step 2: 执行 flush ———
bash "$WORKSPACE/scripts/session_flush.sh" \
  "$SESSION_ID" \
  "$TITLE" \
  "$SUMMARY"

FLUSH_EXIT=$?

# ——— Step 3: 执行 snapshot ———
SNAPSHOT_SUMMARY="每日系统检查点\n- 日期: $DATE\n- 时间: $TIME\n- 已有会话轮次: ${SESSION_COUNT}\n- 文件大小: ${DAILY_SIZE}"

bash "$WORKSPACE/scripts/session_snapshot.sh" \
  "$SESSION_ID" \
  "$(echo -e "$SNAPSHOT_SUMMARY")"

SNAP_EXIT=$?

# ——— Step 4: 记录结果 ———
if [ $FLUSH_EXIT -eq 0 ] && [ $SNAP_EXIT -eq 0 ]; then
  echo "[$DATE $TIME] ✅ daily-flush-snapshot: 完成 (flush=${FLUSH_EXIT}, snapshot=${SNAP_EXIT})" >> "$LOG"
  exit 0
else
  echo "[$DATE $TIME] ❌ daily-flush-snapshot: 失败 (flush=${FLUSH_EXIT}, snapshot=${SNAP_EXIT})" >> "$LOG"
  exit 1
fi
