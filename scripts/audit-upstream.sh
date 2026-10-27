#!/usr/bin/env bash
# audit-upstream.sh — 上游 hook 源差异审计
#
# 用途：开源仓维护者定期跑这个脚本，对比"上游实战源"和"开源仓当前内容"，
#       列出哪些上游 hook 有更新但开源仓没跟上、哪些新出现的 hook 模式还没抽象。
#       只读、不改、不 push——输出报告，人决定要不要同步。
#
# 默认扫描的上游源（可通过环境变量覆盖）：
#   UPSTREAM_CLAUDE_HOOKS   ~/.claude/hooks          （全局 Claude Code hook）
#   UPSTREAM_WORKDIR_SAFE    <xingtu>/tools/safety   （工作区安全脚本）
#   UPSTREAM_PROJECTS        ~/projects              （各项目 .claude/hooks 实践）
#
# 用法：
#   bash scripts/audit-upstream.sh
#   UPSTREAM_PROJECTS=/some/dir bash scripts/audit-upstream.sh
#
# 退出码：0（有差异或无差异都正常输出）；2=参数错

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CLAUDE_HOOKS="${UPSTREAM_CLAUDE_HOOKS:-$HOME/.claude/hooks}"
PROJECTS_DIR="${UPSTREAM_PROJECTS:-$HOME/projects}"

echo "================================================================"
echo " xingtu-hooks 上游审计 · $(date '+%Y-%m-%d %H:%M')"
echo "================================================================"

# ── 1. 全局 ~/.claude/hooks vs 开源仓 hooks/ ──────────────────────
echo ""
echo "## 1. 全局 hook 目录 vs 开源仓"
echo "   源: $CLAUDE_HOOKS"
if [ -d "$CLAUDE_HOOKS" ]; then
  # 开源仓里已经有哪些 hook
  ours=$(find "$ROOT/hooks" -name 'hook.*' -type f | xargs -I{} basename {} | sort -u)
  # 上游有哪些 hook 文件
  upstream=$(find "$CLAUDE_HOOKS" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) | xargs -I{} basename {} | sort -u)
  echo "   上游文件数: $(echo "$upstream" | grep -c . )"
  echo "   开源仓已覆盖: $(echo "$ours" | grep -c . ) 个 hook 目录"
  # 上游有但开源仓完全没提到的名字
  echo "   --- 上游有、开源仓未收录的 hook（候选抽象）---"
  for f in $upstream; do
    stem="${f%.*}"
    # 开源仓里有没有同名或近似目录
    if ! find "$ROOT/hooks" -type d -iname "*${stem}*" | grep -q .; then
      mtime=$(stat -f '%Sm' -t '%Y-%m-%d' "$CLAUDE_HOOKS/$f" 2>/dev/null || echo "?")
      echo "     - $f  (mtime: $mtime)"
    fi
  done
else
  echo "   (源目录不存在，跳过)"
fi

# ── 2. 各项目 .claude/hooks 最近 30 天新增 ───────────────────────
echo ""
echo "## 2. 项目级 hook 近 30 天变更"
echo "   扫描: $PROJECTS_DIR"
if [ -d "$PROJECTS_DIR" ]; then
  find "$PROJECTS_DIR" -maxdepth 5 -path '*/.claude/hooks/*' -type f \
    -mtime -30 -not -name '.stats.log' -not -name '*.tsv' 2>/dev/null \
    | while read -r f; do
        proj=$(echo "$f" | sed -E "s|$PROJECTS_DIR/([^/]+)/.*|\1|")
        name=$(basename "$f")
        echo "     - [$proj] $name"
      done | head -30
  echo "   （只列近 30 天改动，最多 30 条）"
else
  echo "   (源目录不存在，跳过)"
fi

# ── 3. 开源仓自身健康检查 ───────────────────────────────────────
echo ""
echo "## 3. 开源仓自身健康检查"
# bash 语法
bash_fail=0
for f in $(find "$ROOT/hooks" "$ROOT/scripts" -name '*.sh' -type f); do
  bash -n "$f" 2>/dev/null || { echo "   [FAIL] bash 语法: $f"; bash_fail=1; }
done
[ "$bash_fail" = "0" ] && echo "   [ok] 所有 .sh 语法通过"
# python 语法
py_fail=0
for f in $(find "$ROOT/hooks" -name '*.py' -type f); do
  python3 -m py_compile "$f" 2>/dev/null || { echo "   [FAIL] py 语法: $f"; py_fail=1; }
done
[ "$py_fail" = "0" ] && echo "   [ok] 所有 .py 语法通过"
# 未执行位
noexec=$(find "$ROOT/hooks" -name 'hook.sh' ! -perm +111 2>/dev/null)
[ -z "$noexec" ] && echo "   [ok] 所有 hook.sh 有执行位" || echo "   [warn] 缺执行位: $noexec"
# git 状态
if [ -d "$ROOT/.git" ]; then
  cd "$ROOT"
  dirty=$(git status --porcelain)
  [ -z "$dirty" ] && echo "   [ok] git 工作区干净" || echo "   [warn] 有未提交改动:"; echo "$dirty" | sed 's/^/        /'
fi

echo ""
echo "================================================================"
echo " 结束。有差异时人工判断哪些该抽象进开源仓，别自动同步。"
echo "================================================================"
