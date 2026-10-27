#!/usr/bin/env bash
# session-recap — Stop hook：本轮响应结束后生成一行 recap
#
# 事件: Stop ｜ 输出: systemMessage（非阻断，decision: allow）
#
# 设计：
#   - 非阻塞，不影响正常会话流程
#   - systemMessage 展示摘要，用户一眼看到本轮产出
#   - 持久化到 ~/.claude/recaps/YYYYMMDD.md，下次 SessionStart 可注入
#   - 防循环：stop_hook_active=true 时直接放行
#
# 依赖：jq（macOS 需 brew install jq）

INPUT=$(cat)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && echo '{"decision":"allow"}' && exit 0

# 防止 Stop hook 自身触发循环
STOP_ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$STOP_ACTIVE" = "true" ] && echo '{"decision":"allow"}' && exit 0

# 扫描 transcript 最近 300 行
RECENT=$(tail -300 "$TRANSCRIPT" 2>/dev/null)

COMMITS=$(printf '%s' "$RECENT" | grep -oE '"commit [a-f0-9]{7,}' | sort -u | tail -3 | sed 's/"commit //g')
EDIT_COUNT=$(printf '%s' "$RECENT" | grep -c '"name":"Edit"')
WRITE_COUNT=$(printf '%s' "$RECENT" | grep -c '"name":"Write"')
TASKS_DONE=$(printf '%s' "$RECENT" | grep -c '"status":"completed"')

PARTS=()
FILE_OPS=$((EDIT_COUNT + WRITE_COUNT))
[ "$FILE_OPS" -gt 0 ] && PARTS+=("文件×${FILE_OPS}")

if [ -n "$COMMITS" ]; then
  COMMIT_SHORT=$(printf '%s' "$COMMITS" | head -1 | cut -c1-7)
  PARTS+=("提交 ${COMMIT_SHORT}")
fi

[ "$TASKS_DONE" -gt 0 ] && PARTS+=("完成任务×${TASKS_DONE}")

# 无事件 → 跳过
if [ ${#PARTS[@]} -eq 0 ]; then
  echo '{"decision":"allow"}' && exit 0
fi

RECAP_MSG="※ recap: > $(IFS=' | '; echo "${PARTS[*]}")"

# 持久化到 recaps 文件
RECAP_DIR="${HOME}/.claude/recaps"
mkdir -p "$RECAP_DIR"
RECAP_FILE="${RECAP_DIR}/$(date +%Y%m%d).md"
echo "[$(date +%H:%M:%S)] ${RECAP_MSG}" >> "$RECAP_FILE"

# 输出：非阻塞 + systemMessage 展示
jq -n --arg msg "$RECAP_MSG" '{"decision":"allow","hookSpecificOutput":{"systemMessage":$msg}}'
