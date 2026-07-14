#!/bin/bash
# Auto Dream — 记忆系统离线整合守护脚本
# 由 cron 每日定时触发，检查是否满足整合条件
#
# 修复：v2 — 分离锁文件和上次运行时间戳（解决持续 SKIP bug）

LOCK_FILE="$HOME/.openclaw/workspace/.memory/dream.lock"
LAST_RUN_FILE="$HOME/.openclaw/workspace/.memory/dream_last_run"  # 新增：独立时间戳文件
DB="$HOME/.openclaw/workspace/transcripts/sessions.db"
LOG_FILE="$HOME/.openclaw/workspace/.memory/dream.log"
INDEX_FILE="$HOME/.openclaw/workspace/MEMORY.md"
LONG_TERM_DIR="$HOME/.openclaw/workspace/long-term"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

create_lock() {
    # 原子创建锁文件
    echo "$$" > "$LOCK_FILE"
    # CAS 验证
    READ_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ "$READ_PID" != "$$" ]; then
        log "SKIP: 锁竞争失败 (预期 $$, 读到 $READ_PID)"
        exit 0
    fi
}

release_lock() {
    rm -f "$LOCK_FILE"
}

# === 锁机制（仅用于互斥，不用于时间戳）===
if [ -f "$LOCK_FILE" ]; then
    LOCK_TIME=$(stat -c %Y "$LOCK_FILE" 2>/dev/null)
    LOCK_AGE=$(( $(date +%s) - ${LOCK_TIME:-0} ))
    # 超过 1 小时的锁视为过期（上次跑崩了）
    if [ "$LOCK_AGE" -lt 3600 ]; then
        log "SKIP: 锁文件存在（${LOCK_AGE}s 前创建），互斥冲突"
        exit 0
    fi
    log "WARN: 锁文件过期（${LOCK_AGE}s），覆盖"
fi

create_lock

# === 条件检查 ===

# 条件 1: 距上次整合至少 24 小时（使用独立时间戳文件）
if [ -f "$LAST_RUN_FILE" ]; then
    LAST_RUN_TIME=$(stat -c %Y "$LAST_RUN_FILE" 2>/dev/null)
    LAST_RUN_AGE=$(( $(date +%s) - ${LAST_RUN_TIME:-0} ))
    if [ "$LAST_RUN_AGE" -lt 86400 ]; then
        log "SKIP: 距上次整合仅 $(( LAST_RUN_AGE / 3600 )) 小时，不足 24h"
        release_lock
        exit 0
    fi
fi

# 条件 2: 期间至少新增 5 条记忆
if [ -d "$LONG_TERM_DIR" ]; then
    TOTAL_LINES=$(wc -l "$LONG_TERM_DIR"/*.md 2>/dev/null | tail -1 | awk '{print $1}')
    if [ "${TOTAL_LINES:-0}" -lt 50 ]; then
        log "SKIP: long-term 总行数仅 ${TOTAL_LINES:-0}，数据不足整合"
        release_lock
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

# === 更新上次运行时间戳（仅成功完成时写入）===
touch "$LAST_RUN_FILE"
log "TIME: 上次运行时间戳已更新"

# === 释放锁 ===
release_lock
log "LOCK: 锁已释放"

exit 0
