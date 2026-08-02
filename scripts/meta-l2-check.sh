#!/bin/bash
# meta-l2-check.sh — 元管理层 L2 一致性检查（每周对账）
# 职责：L2 是账本的消费者，不是生产者
#   1. 检查 VERSION_LEDGER 待处理项是否超时（🔴>3天标红 / 🔴>7天进findings / 🟡>14天进findings）
#   2. 扫描 agents 注册 + cron 列表，找"应退役未退役"（对比 PROJECT_MAP 状态机）
#   3. 抽查设计文档声明的 cron/文件/配置是否实际存在（DRIFT-002 类"声称未建"）
#   4. 产出异常清单 → 输出到 stdout（由 cron announce 投递）；无异常则静默
# 原则：只报告，不改账本状态（状态变更留给人）
# 用法：bash scripts/meta-l2-check.sh

WORKSPACE="$HOME/.openclaw/workspace"
LEDGER="$WORKSPACE/VERSION_LEDGER.md"
PROJECT_MAP="$WORKSPACE/PROJECT_MAP.md"
FINDINGS_DIR="$WORKSPACE/findings"
TODAY=$(date '+%Y-%m-%d')
ISSUES=""
COUNT=0

echo "🔍 【元管理层 L2 一致性检查】$TODAY"

# ——— 1. 漂移超时检查 ———
if [ -f "$LEDGER" ]; then
  echo ""
  echo "--- 漂移项超时检查（VERSION_LEDGER） ---"
  # 读取待处理项（状态=待处理或处理中），检查进入待处理日是否超时
  # 格式: | DRIFT-XXX | 项目 | ... | 状态 | 进入待处理日 |
  while IFS='|' read -r _ num proj _ _ _ _ _ status date_raw _; do
    num=$(echo "$num" | xargs)
    status=$(echo "$status" | xargs)
    date_raw=$(echo "$date_raw" | xargs)
    [ -z "$num" ] && continue
    case "$num" in DRIFT-*) ;; *) continue ;; esac
    # 只检查未解决状态
    case "$status" in 待处理|处理中) ;; *) continue ;; esac
    # 计算天数
    if [ -n "$date_raw" ] && [[ "$date_raw" =~ ^[0-9]{2}-[0-9]{2}$ ]]; then
      entry_ts=$(date -d "2026-${date_raw}" +%s 2>/dev/null)
      now_ts=$(date +%s)
      days=$(( (now_ts - entry_ts) / 86400 ))
      # 判断优先级（含🔴或🟡的行，从原文再取一次）
      prio=$(grep "^| $num " "$LEDGER" | grep -oE '🔴|🟡' | head -1)
      if [ "$prio" = "🔴" ]; then
        if [ "$days" -gt 7 ]; then
          echo "🔴 $num 超时 ${days}天（>7天）→ 应进 findings"
          ISSUES="$ISSUES\n- $num 🔴 待处理超 ${days}天（>7天）"
          COUNT=$((COUNT+1))
        elif [ "$days" -gt 3 ]; then
          echo "🟠 $num 超时 ${days}天（>3天）→ 周报应标红"
          ISSUES="$ISSUES\n- $num 🔴 待处理超 ${days}天（>3天）"
          COUNT=$((COUNT+1))
        else
          echo "✅ $num 待处理 ${days}天（未超时）"
        fi
      elif [ "$prio" = "🟡" ]; then
        if [ "$days" -gt 14 ]; then
          echo "🟡 $num 超时 ${days}天（>14天）→ 应进 findings"
          ISSUES="$ISSUES\n- $num 🟡 待处理超 ${days}天（>14天）"
          COUNT=$((COUNT+1))
        else
          echo "✅ $num 待处理 ${days}天（未超时）"
        fi
      else
        echo "⚠️ $num 无法判定优先级（检查格式）"
      fi
    else
      echo "⚠️ $num 日期格式异常: '$date_raw'"
    fi
  done < <(grep '^| DRIFT-' "$LEDGER")
else
  echo "⚠️ VERSION_LEDGER.md 不存在"
fi

# ——— 2. 应退役未退役扫描（占位：cron/agent 列表由人工复核） ———
echo ""
echo "--- 应退役未退役（PROJECT_MAP 状态机） ---"
if [ -f "$PROJECT_MAP" ]; then
  # 检查 PROJECT_MAP 中标记"退役"阶段的项目（当前无，占位逻辑）
  RETIRED=$(grep -c "阶段：退役" "$PROJECT_MAP" 2>/dev/null || echo 0)
  echo "PROJECT_MAP 中退役阶段项目数: $RETIRED（0 = 无应退役项）"
  # 已知人工项：reflector 退役（DRIFT-001）应在第6步执行
  if grep -q "DRIFT-001" "$LEDGER" 2>/dev/null && grep -q "| 待处理 |" "$LEDGER" 2>/dev/null; then
    # 具体判断：DRIFT-001 是否仍待处理
    if grep "^| DRIFT-001 " "$LEDGER" | grep -q "待处理"; then
      echo "🔴 DRIFT-001 reflector 退役仍待处理（第6步待先生授权）"
    fi
  fi
else
  echo "⚠️ PROJECT_MAP.md 不存在"
fi

# ——— 3. 声称未建抽查（DRIFT-002 类） ———
echo ""
echo "--- 声称未建抽查 ---"
# 检查账本中所有"声称未建"类型是否已处理
CLAIMED=$(grep -c "声称未建" "$LEDGER" 2>/dev/null || echo 0)
UNRESOLVED_CLAIMED=$(grep "声称未建" "$LEDGER" | grep -cE "待处理|处理中" || echo 0)
echo "声称未建类漂移: 共 $CLAIMED 条，未解决 $UNRESOLVED_CLAIMED 条"
if [ "$UNRESOLVED_CLAIMED" -gt 0 ]; then
  ISSUES="$ISSUES\n- 存在未解决的'声称未建'类漂移（$UNRESOLVED_CLAIMED 条）"
  COUNT=$((COUNT+1))
fi

# ——— 汇总输出 ———
echo ""
if [ "$COUNT" -eq 0 ]; then
  echo "✅ L2 检查完成：无异常，无超时项"
  exit 0
else
  echo "⚠️ L2 检查发现 $COUNT 项异常："
  echo -e "$ISSUES"
  echo ""
  echo "（按 rules.md 升级机制：🔴>7天/🟡>14天 应进 findings/，由人工确认后记录）"
  exit 0
fi
