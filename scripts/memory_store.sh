#!/bin/bash
# memory_store.sh — 将先生表达的偏好/决策/项目信息写入 long-term/，同步更新索引
# 用法：./memory_store.sh <type> <内容>
#   type: user | feedback | project | reference
#
# 写前备份 → 写入目标文件 → 同步 MEMORY.md 索引 → 心跳日志

if [ $# -lt 2 ]; then
    echo "Usage: $0 <type> <内容>"
    echo "  type: user | feedback | project | reference"
    exit 1
fi

TYPE="$1"
shift
CONTENT="$*"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
HEARTBEAT=~/.openclaw/workspace/scripts/.heartbeat.log
WORKSPACE=~/.openclaw/workspace
LONGBASE="$WORKSPACE/long-term"
INDEX="$WORKSPACE/MEMORY.md"

# 数组显式映射（比链式 if 更可靠）
declare -A FILE_MAP=(
    ["user"]="$LONGBASE/user-profile.md"
    ["feedback"]="$LONGBASE/feedback-log.md"
    ["project"]="$LONGBASE/project-context.md"
    ["reference"]="$LONGBASE/references.md"
)

TARGET="${FILE_MAP[$TYPE]}"
if [ -z "$TARGET" ]; then
    echo "Error: type must be user|feedback|project|reference, got '$TYPE'"
    exit 1
fi

# 写前备份
cp "$TARGET" "${TARGET}.bak" 2>/dev/null || true

# 写入目标文件
echo "" >> "$TARGET"
echo "### $TIMESTAMP" >> "$TARGET"
echo "$CONTENT" >> "$TARGET"

# 更新 MEMORY.md 索引（摘要 ≤ 150 字符）
SHORT="${CONTENT:0:120}"
REL_NAME=$(basename "$TARGET")
# 如果 SUMMARY 太长，加省略号
[ "${#CONTENT}" -gt 120 ] && SHORT="${SHORT}..."
echo "| $TIMESTAMP | $TYPE | $SHORT | $REL_NAME |" >> "$INDEX"

echo "$TIMESTAMP | store | OK | $TYPE | $REL_NAME" >> "$HEARTBEAT"
echo "OK: written to $TARGET"
