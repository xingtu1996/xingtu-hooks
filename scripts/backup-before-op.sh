#!/bin/bash
# backup-before-op.sh — 批量/结构性操作前快照备份
#
# 用法: backup-before-op.sh <操作描述> <路径1> [路径2 ...]
#  示例: backup-before-op.sh '重组目录' ./dir1 ./dir2
#
# 备份默认落在当前目录下的 .backups，可用环境变量 BACKUP_BEFORE_OP_DIR 覆盖。
# 每次操作打包成带时间戳+描述的 tar.gz，并写 .meta 记录原路径，便于回滚。
#
# 教训沉淀：
#   - 描述会进文件名，必须先消毒（/ 会把 tar 路径切开导致静默失败）
#   - 备份后必须自证：文件真的存在且非空，不能只看"创建成功"那行打印

set -euo pipefail

BACKUP_DIR="${BACKUP_BEFORE_OP_DIR:-${PWD}/.backups}"
mkdir -p "${BACKUP_DIR}"

if [[ $# -lt 2 ]]; then
  echo "用法: backup-before-op.sh <操作描述> <路径1> [路径2 ...]"
  echo "示例: backup-before-op.sh '重组目录' ./dir1 ./dir2"
  exit 1
fi

DESCRIPTION="$1"
shift

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
# 描述进文件名 → 消毒（空格折 -，去掉 / \ : * ? < > |，避免 tar 静默失败）
DESC_SAFE="$(printf '%s' "${DESCRIPTION}" | tr -s ' ' '-' | sed 's#[/\\:*?<>|]#-#g; s#-\{2,\}#-#g; s#^-##; s#-$##')"
[[ -z "${DESC_SAFE}" ]] && DESC_SAFE="op"
BACKUP_NAME="${TIMESTAMP}_${DESC_SAFE}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"

echo "=== 操作前快照 ==="
echo "操作: ${DESCRIPTION}"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "路径: $@"
echo ""

MISSING=()
for P in "$@"; do
  [[ ! -e "${P}" ]] && MISSING+=("${P}")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "警告: 以下路径不存在，将从备份中排除:"
  for P in "${MISSING[@]}"; do echo "  - ${P}"; done
  echo ""
fi

EXISTING=()
for P in "$@"; do
  [[ -e "${P}" ]] && EXISTING+=("${P}")
done
if [[ ${#EXISTING[@]} -eq 0 ]]; then
  echo "错误: 没有可备份的路径"
  exit 1
fi

TAR_ERR="${BACKUP_DIR}/.last_tar_err"
if ! tar -czf "${BACKUP_PATH}" "${EXISTING[@]}" 2>"${TAR_ERR}"; then
  echo "备份失败：tar 返回非零。" >&2
  sed 's/^/   /' "${TAR_ERR}" >&2
  echo "   目标路径: ${BACKUP_PATH}" >&2
  echo "   未产生备份，请勿继续后续破坏性操作。" >&2
  exit 1
fi
rm -f "${TAR_ERR}"

# 自证：备份必须真的存在且非空
if [[ ! -s "${BACKUP_PATH}" ]]; then
  echo "备份文件不存在或为空：${BACKUP_PATH}" >&2
  echo "   未产生备份，请勿继续后续破坏性操作。" >&2
  exit 1
fi

SIZE="$(du -h "${BACKUP_PATH}" | cut -f1)"
ENTRIES="$(tar -tzf "${BACKUP_PATH}" | wc -l | tr -d ' ')"
echo "备份已落盘 (${SIZE} · ${ENTRIES} 条目)"
echo "   ${BACKUP_PATH}"

cat > "${BACKUP_PATH}.meta" << EOF
time: $(date '+%Y-%m-%d %H:%M:%S')
description: ${DESCRIPTION}
paths: ${*}
backup_file: ${BACKUP_NAME}.tar.gz
EOF

echo ""
echo "现有备份 (最近 10 个):"
ls -lt "${BACKUP_DIR}"/*.tar.gz 2>/dev/null | head -10 | awk '{print $6, $7, $8, $9}' || echo "  (无)"
