#!/bin/bash
# Auto Dream — 记忆系统离线整合守护脚本
# 由 cron 每日定时触发，检查是否满足整合条件

LOCK_FILE="$HOME/.openclaw/workspace/.memory/dream.lock"
DB="$HOME/.openclaw/workspace/transcripts/sessions.db"
LOG_FILE="$HOME/.openclaw/workspace/.memory/dream.log"
INDEX_FILE="$HOME/.openclaw/workspace/MEMORY.md"
LONG_TERM_DIR="$HOME/.openclaw/workspace/long-term"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# === 锁机制 ===
# 检查锁文件 (CAS 竞争检测)
if [ -f "$LOCK_FILE" ]; then
    LOCK_TIME=$(stat -c %Y "$LOCK_FILE" 2>/dev/null)
    LOCK_AGE=$(( $(date +%s) - ${LOCK_TIME:-0} ))
    # 超过 1 小时的锁视为过期（上次跑崩了）
    if [ "$LOCK_AGE" -lt 3600 ]; then
        log "SKIP: 锁文件存在（${LOCK_AGE}s 前创建）"
        exit 0
    fi
    log "WARN: 锁文件过期（${LOCK_AGE}s），覆盖"
fi

# 获取锁 (写入当前 PID)
echo $$ > "$LOCK_FILE"
# CAS 验证：读回来检查是不是自己的 PID
READ_PID=$(cat "$LOCK_FILE" 2>/dev/null)
if [ "$READ_PID" != "$$" ]; then
    log "SKIP: 锁竞争失败 (预期 $$, 读到 $READ_PID)"
    rm -f "$LOCK_FILE"
    exit 0
fi

# === 条件检查 ===

# 条件 1: 距上次整合至少 24 小时
if [ -f "$LOCK_FILE" ]; then
    LAST_RUN_TIME=$(stat -c %Y "$LOCK_FILE" 2>/dev/null)
    LAST_RUN_AGE=$(( $(date +%s) - ${LAST_RUN_TIME:-0} ))
    if [ "$LAST_RUN_AGE" -lt 86400 ]; then
        log "SKIP: 距上次整合仅 $(( LAST_RUN_AGE / 3600 )) 小时，不足 24h"
        rm -f "$LOCK_FILE"
        exit 0
    fi
fi

# 条件 2: 期间至少新增 5 条记忆
# 通过检查 feedback-log.md 和 project-context.md 的新增行数估算
if [ -d "$LONG_TERM_DIR" ]; then
    TOTAL_LINES=$(wc -l "$LONG_TERM_DIR"/*.md 2>/dev/null | tail -1 | awk '{print $1}')
    # 粗略判断：如果所有 long-term 文件总行数 < 50，说明数据很少
    if [ "${TOTAL_LINES:-0}" -lt 50 ]; then
        log "SKIP: long-term 总行数仅 ${TOTAL_LINES:-0}，数据不足整合"
        rm -f "$LOCK_FILE"
        exit 0
    fi
fi

# === 条件满足，执行整合 ===

log "START: Auto Dream 开始执行 (PID: $$)"

# 阶段 1: Orient — 列出文件清单
echo "--- Orient Phase ---"
echo "long-term 文件:"
ls -la "$LONG_TERM_DIR"/
echo ""
echo "MEMORY.md 索引行数: $(wc -l < "$INDEX_FILE")"
echo "索引大小: $(wc -c < "$INDEX_FILE") 字节"

# 阶段 2: Gather — 检查 DB 中的新记录
echo ""
echo "--- Gather Phase ---"
echo "最近 24h 消息数: $(sqlite3 "$DB" "SELECT COUNT(*) FROM messages WHERE created_at > datetime('now', '-1 day', '+8 hours');" 2>/dev/null || echo "N/A")"

# 阶段 3: Consolidate + 4: Prune — 通知主代理在下次对话中执行
echo ""
echo "--- Summary ---"
echo "Auto Dream 条件满足，标记待整合。"
echo "下次主代理对话时将执行完整的 Consolidate + Prune 流程。"

# 记录标记到 DB，下次主代理对话时读取
sqlite3 "$DB" "INSERT INTO messages (session_id, role, content) VALUES ('system', 'system', 'auto_dream:ready');" 2>/dev/null

log "DONE: Auto Dream 标记完成，等待主代理执行整合"

# === 释放锁 ===
# 更新锁文件修改时间（= 本次整合时间戳，供下次判断）
rm -f "$LOCK_FILE"
echo "$$" > "$LOCK_FILE"
log "LOCK: 锁更新完毕"

exit 0
