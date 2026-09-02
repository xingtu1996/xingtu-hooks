#!/usr/bin/env bash
# pre-tool-secret-guard — 拦截对敏感文件（.env / 私钥 / 凭据）的 Edit/Write
# 事件: PreToolUse(Edit|Write) ｜ 输出: block/allow JSON
# 用途: 密钥/凭据只走环境变量或配置中心，禁止直接编辑 .env / *.key / id_rsa / *.pem
set -euo pipefail

FP=$(python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")
[ -z "$FP" ] && echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"allow"}}' && exit 0

# 白名单例外：模板 / 公钥 / 公开目录 / 文档
if printf '%s' "$FP" | grep -qE '\.env\.example$|\.pub$|(^|/)public/|\.md$'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"allow"}}'
  exit 0
fi

# 敏感拦截
if printf '%s' "$FP" | grep -qE '(^|/)\.env([^a-zA-Z0-9_]|$)|\.key$|id_rsa($|\.)|\.pem$|\.git/objects'; then
  python3 -c "import sys,json;print(json.dumps({'hookSpecificOutput':{'hookEventName':'PreToolUse','decision':'block','reason':'敏感文件禁止直接编辑：密钥/凭据请走环境变量或配置中心，.env 类已 gitignore'}}))"
  exit 0
fi

echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"allow"}}'
