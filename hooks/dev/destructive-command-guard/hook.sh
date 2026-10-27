#!/usr/bin/env bash
# destructive-command-guard — 拦截不可逆的 Bash 命令
#
# 事件: PreToolUse(Bash) ｜ 阻断: exit 2（stderr 回注模型）｜ 放行: exit 0
#
# 为什么要有这个 hook：
#   CLAUDE.md / AGENTS.md 里写的 "never do X" 是【请求】，不是【保证】——
#   模型可能忽略、可能被绕过（变量拼接、换写法、复合命令内嵌），
#   而 rm -rf / git push -f 是不可逆的。把不可逆的事交给文字规则保护 = 没保护。
#   hook 由 harness 在工具执行前强制运行，不依赖模型记忆。
#
# 拦截范围（只拦"不可逆"，正常操作一律放行，避免天天误伤）：
#   - 递归删除：rm -rf / rm -fr / rm -Rf / rm -r -f（单文件 rm 不拦）
#   - 丢历史的 git：git push --force / git reset --hard / git clean -f
#   - 批量暂存：git add -A / git add --all（应精确定向 add）
#   - 磁盘级破坏：mkfs.* / dd of=/dev/... / > /dev/sdX
#
# fail-open：stdin 解析失败 / 字段缺失 / hook 自身异常 → 一律放行（exit 0），
#   红线兜底仍在规则层；hook 自身故障不能卡住所有 Bash。
#
# 逃生门：block 时提示用户去终端手动执行（本人在场、知情）。

set -uo pipefail
INPUT=$(cat)

# 取 tool_input.command —— 解析失败时放行
CMD=$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))
except Exception:
    print("")
' 2>/dev/null || echo "")

[ -z "$CMD" ] && exit 0

danger=""
reason=""

# ── 递归删除（rm -rf / -fr / -Rf / -r -f ...）──────────────────────
# 命令位置感知：行首 / ; & | 换行 反引号 $() / sudo / xargs 之后
# 放过 git rm、npm rm 等带前缀形式；echo/grep 参数里的 "rm" 字样不拦
if printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]`]|\$\(|\bsudo[[:space:]]+|\bxargs[[:space:]]+)[[:space:]]*rm[[:space:]]+(-[[:alnum:]]*[rR][[:alnum:]]*[[:space:]]+-[[:alnum:]]*[fF][[:alnum:]]*|-[[:alnum:]]*[fF][[:alnum:]]*[rR][[:alnum:]]*|--recursive[[:space:]]+--force|--force[[:space:]]+--recursive)'; then
  danger="rm"
  reason="递归删除（rm -rf 之类）"
fi

# ── 会丢历史的 git 操作 ───────────────────────────────────────────
# git push -f / --force（--force-with-lease 放行，那是安全的）
# git reset --hard
# git clean -f
if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+push[[:space:]]+.*(--force|-f)([[:space:]]|$)' \
|| printf '%s' "$CMD" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard' \
|| printf '%s' "$CMD" | grep -qE 'git[[:space:]]+clean[[:space:]]+-[[:alnum:]]*[fF]'; then
  danger="git"
  reason="会丢历史的 git 操作（强推 / hard reset / clean -f）"
fi

# ── git add -A / --all 批量暂存 ──────────────────────────────────
# 应精确定向 add 需要的文件，避免把临时文件/密钥/大文件一起提交
if printf '%s' "$CMD" | grep -qE '\bgit[[:space:]]+add[[:space:]]+(-[[:alnum:]]+[[:space:]]+)*(-A|--all)([[:space:]]|$)'; then
  danger="git-add"
  reason="git add -A / --all 批量暂存"
fi

# ── 磁盘级破坏 ────────────────────────────────────────────────────
if printf '%s' "$CMD" | grep -qE 'mkfs\.|dd[[:space:]]+.*of=/dev/[sh]d[a-z]|>[[:space:]]*/dev/[sh]d[a-z]'; then
  danger="disk"
  reason="磁盘级破坏操作（mkfs / dd 写裸设备 / 重定向到磁盘）"
fi

[ -z "$danger" ] && exit 0

# ── 阻断（exit 2，stderr 回注模型）─────────────────────────────────
cat >&2 <<EOF
[BLOCK] 已拦截：$reason

命令：
  $CMD

为什么拦：这类操作不可逆，而规则文件里的禁令只是"请求"不是"保证"，所以用 hook 强制。

如果确实需要执行：
  1. 先确认目标在 git 追踪中（git status）
  2. 需要"清理"时改用 mv 到临时目录，确认无误后再手动删
  3. 或使用配套的 scripts/safe-delete.sh（移入回收站，可恢复）
  4. 确有必要绕过时，请本人在终端手动执行。
EOF
exit 2
