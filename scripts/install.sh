#!/usr/bin/env bash
# install.sh — 打印各 hook 的 settings.json 注册片段
#
# 本脚本不直接改你的全局 settings（那有风险），只打印可复制的 JSON 片段。
# 把需要的片段合并进 ~/.claude/settings.json 的 hooks 段即可。
#
# 用法: bash scripts/install.sh [hook-name]
#   不带参数 → 打印全部 hook 的注册片段
#   带名字   → 只打印指定 hook

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

print_hook() {
  local name="$1"
  local dir="${ROOT}/hooks/${name}"
  [[ -d "$dir" ]] || { echo "# (未找到 hooks/${name})"; return; }
  local impl
  if [[ -f "${dir}/hook.sh" ]]; then impl="${dir}/hook.sh";
  elif [[ -f "${dir}/hook.py" ]]; then impl="${dir}/hook.py";
  else return; fi
  chmod +x "$impl" 2>/dev/null || true
  # 从 hook.json 读 trigger
  local trigger matcher
  trigger=$(python3 -c "import json;print(json.load(open('${dir}/hook.json')).get('trigger',''))" 2>/dev/null || echo "")
  echo ""
  echo "// ── ${name}  (${trigger}) ──"
  echo "// 把下面这一段合并进 settings.json 对应事件数组"
  case "$trigger" in
    PreToolUse*)
      echo '{'
      echo '  "matcher": "Bash",'
      echo '  "hooks": [{"type":"command","command":"'${impl}'","timeout":5000}]'
      echo '}'
      ;;
    PostToolUse*)
      echo '{'
      echo '  "matcher": "Edit|Write|MultiEdit",'
      echo '  "hooks": [{"type":"command","command":"'${impl}'"}]'
      echo '}'
      ;;
    SessionStart*)
      echo '{'
      echo '  "matcher": "startup|resume|clear|compact",'
      echo '  "hooks": [{"type":"command","command":"'${impl}'"}]'
      echo '}'
      ;;
    Stop*)
      echo '{'
      echo '  "hooks": [{"type":"command","command":"'${impl}'"}]'
      echo '}'
      ;;
    *)
      echo '{"hooks":[{"type":"command","command":"'${impl}'"}]}'
      ;;
  esac
}

echo "// xingtu-hooks 注册片段 —— 合并进 ~/.claude/settings.json 的 hooks 段"
echo "// 路径已是绝对路径，复制即用。"

if [[ $# -ge 1 ]]; then
  print_hook "$1"
else
  for d in "${ROOT}/hooks"/*/; do
    print_hook "$(basename "$d")"
  done
fi

echo ""
echo "// 提醒：safe-delete.sh / backup-before-op.sh 在 scripts/ 下，"
echo "// 不用注册成 hook，在 Bash 里直接调用即可。"
