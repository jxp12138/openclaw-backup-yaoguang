#!/bin/bash
# pre-change-snapshot.sh — 配置变更前快照
# 调用方式：./scripts/pre-change-snapshot.sh
# 在每次修改 openclaw.json 或 .env 前手动执行
#
# 输出：workspace/snapshots/openclaw.json.YYYYMMDD_HHMMSS
#       workspace/snapshots/env.YYYYMMDD_HHMMSS
# 保留期：30 天（自动清理过期快照）

SNAPSHOTS_DIR="$HOME/.openclaw/workspace/snapshots"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$SNAPSHOTS_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 快照 $TIMESTAMP"

# openclaw.json
if [ -f "$HOME/.openclaw/openclaw.json" ]; then
  cp "$HOME/.openclaw/openclaw.json" "$SNAPSHOTS_DIR/openclaw.json.$TIMESTAMP"
  echo "  ✅ openclaw.json.$TIMESTAMP  $(ls -lh "$SNAPSHOTS_DIR/openclaw.json.$TIMESTAMP" | awk '{print $5}')"
else
  echo "  ⚠️  openclaw.json 不存在，跳过"
fi

# .env（如果存在）
if [ -f "$HOME/.openclaw/.env" ]; then
  cp "$HOME/.openclaw/.env" "$SNAPSHOTS_DIR/env.$TIMESTAMP"
  echo "  ✅ env.$TIMESTAMP  $(ls -lh "$SNAPSHOTS_DIR/env.$TIMESTAMP" | awk '{print $5}')"
else
  echo "  ℹ️  .env 不存在（API Key 还未迁移），跳过"
fi

# 清理 30 天前的快照
find "$SNAPSHOTS_DIR" -name 'openclaw.json.*' -mtime +30 -delete 2>/dev/null
find "$SNAPSHOTS_DIR" -name 'env.*' -mtime +30 -delete 2>/dev/null

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 快照完成"
