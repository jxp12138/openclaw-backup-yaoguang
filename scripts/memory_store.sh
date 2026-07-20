#!/bin/bash
# memory_store.sh — 将记忆条目写入 long-term/ 分类存储
# 使用方式：bash scripts/memory_store.sh <category> <author> <title> <content_file>
#
# category: user | feedback | project | reference
# author: deepseek | glm | reflector
# 先备份，再写入

WORKSPACE="$HOME/.openclaw/workspace"
LOG="$WORKSPACE/scripts/.memory.log"
BACKUP_DIR="$WORKSPACE/scripts/.memory-backups"
CATEGORY="${1:-unknown}"
AUTHOR="${2:-unknown}"
TITLE="${3:-无标题}"
CONTENT_FILE="${4:-}"
DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%H:%M')

# 校验分类
case "$CATEGORY" in
  user|feedback|project|reference) ;;
  *)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ store: 无效分类 $CATEGORY" >> "$LOG"
    exit 1
    ;;
esac

TARGET="$WORKSPACE/long-term/$CATEGORY.md"
mkdir -p "$WORKSPACE/long-term" "$BACKUP_DIR"

# 写前备份
cp "$TARGET" "$BACKUP_DIR/${CATEGORY}-backup-${DATE}-${TIME//:/}.md" 2>/dev/null

if [ -n "$CONTENT_FILE" ] && [ -f "$CONTENT_FILE" ]; then
  CONTENT=$(cat "$CONTENT_FILE")
else
  CONTENT="${3:-(无内容)}"
fi

{
  echo ""
  echo "### $DATE $TIME — $TITLE"
  echo "**作者**: $AUTHOR"
  echo ""
  echo "$CONTENT"
  echo ""
} >> "$TARGET"

# 更新 MEMORY.md 索引（确保索引位置正确）
INDEX="$WORKSPACE/MEMORY.md"
{
  echo ""
  echo "| $DATE $TIME | $CATEGORY | $TITLE | long-term/$CATEGORY.md |"
} >> "$INDEX"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ store: $AUTHOR → $CATEGORY ($TITLE)" >> "$LOG"
