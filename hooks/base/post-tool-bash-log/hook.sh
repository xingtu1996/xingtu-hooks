#!/usr/bin/env bash
# post-tool-bash-log — Bash 命令执行结果记录（失败时提示）
# 事件: PostToolUse(Bash) ｜ 输出: 通知（不阻断）
set -euo pipefail
EXIT=$(python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('tool_response',{}).get('exit_code','0'))" 2>/dev/null || echo "0")
if [ "$EXIT" != "0" ]; then
  python3 -c "import sys,json;print(json.dumps({'hookSpecificOutput':{'hookEventName':'PostToolUse','decision':'block','reason':f'Bash 退出码 {sys.argv[1]}，请检查报错原因'}},ensure_ascii=False))" "$EXIT" 2>/dev/null || true
  exit 0
fi
echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","decision":"allow"}}'
