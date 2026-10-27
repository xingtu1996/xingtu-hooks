#!/usr/bin/env bash
# install.sh — xingtu-hooks 一键安装
# 用法: bash install.sh [--role dev|content|all] [--target ~/.claude]
# 例:
#   bash install.sh                    # 交互式选择角色
#   bash install.sh --role dev          # 直接装开发角色
#   bash install.sh --role all         # 装全部（base + dev + content）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROLE=""
TARGET="$HOME/.claude"

while [ $# -gt 0 ]; do
  case "$1" in
    --role) ROLE="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done

# 交互式选择角色
if [ -z "$ROLE" ]; then
  echo "选择你的角色（决定装哪些 hooks）:"
  echo "  1) dev     — 开发者（代码安全/不可逆操作拦截）"
  echo "  2) content — 内容创作者（写作/发布脱敏检查）"
  echo "  3) all     — 全部都要"
  read -rp "输入选项 [1/2/3]: " choice
  case "$choice" in
    1) ROLE="dev" ;;
    2) ROLE="content" ;;
    3) ROLE="all" ;;
    *) echo "无效选项" >&2; exit 1 ;;
  esac
fi

echo "==> 安装目标: $TARGET/hooks/"
echo "==> 角色: $ROLE"

mkdir -p "$TARGET/hooks"

# 安装 base hooks（所有角色必装）
echo "==> 安装 base hooks（通用安全防护）..."
for h in "$SCRIPT_DIR/hooks/base"/*/; do
  [ -d "$h" ] || continue
  name="$(basename "$h")"
  mkdir -p "$TARGET/hooks/$name"
  cp -r "$h" "$TARGET/hooks/$name/"
  chmod +x "$TARGET/hooks/$name"/*.sh 2>/dev/null || true
  echo "   [ok] $name"
done

# 按角色安装
if [ "$ROLE" = "dev" ] || [ "$ROLE" = "all" ]; then
  echo "==> 安装 dev hooks（开发安全）..."
  for h in "$SCRIPT_DIR/hooks/dev"/*/; do
    [ -d "$h" ] || continue
    name="$(basename "$h")"
    mkdir -p "$TARGET/hooks/$name"
    cp -r "$h" "$TARGET/hooks/$name/"
    chmod +x "$TARGET/hooks/$name"/*.sh 2>/dev/null || true
    echo "   [ok] $name"
  done
fi

if [ "$ROLE" = "content" ] || [ "$ROLE" = "all" ]; then
  echo "==> 安装 content hooks（内容创作）..."
  for h in "$SCRIPT_DIR/hooks/content"/*/; do
    [ -d "$h" ] || continue
    name="$(basename "$h")"
    mkdir -p "$TARGET/hooks/$name"
    cp -r "$h" "$TARGET/hooks/$name/"
    chmod +x "$TARGET/hooks/$name"/*.sh 2>/dev/null || true
    echo "   [ok] $name"
  done
fi

echo ""
echo "==> 安装完成。hooks 位于 $TARGET/hooks/"
echo "==> 在你的 agent 配置（settings.json / CLAUDE.md）里注册这些 hook 的触发事件。"
echo "==> 各 hook 的触发事件见对应 hook.json。"
