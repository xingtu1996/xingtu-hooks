#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
claim-guard — PostToolUse 断言守卫（「先查再答」的机器兜底）

问题：写出**否定性裁决 / 机制性断言**（"X 不支持 / X 不能 / 这是 bug"）时，
     不查原始依据就落纸。根因：注意力单位是「我要说的结论」，
     而这类结论要求的单位是「这个结论的依据在哪一行」。
     实测越觉得"明显"的时刻，越不查——"我有把握"就是盲区。

为什么规则无效：把"下结论前先查证"写在 rules 里是【请求】不是【保证】——
    它可能当天才沉淀，当天就被违反。和 rm -rf 靠 hook 兜是同一个道理。

设计取舍：
  - 用**登记表**不用自动提词——噪音大吵几次就免疫；登记表短、准、可控。
  - **绝不阻断**——只提醒，exit 0。误伤一个正常改动比漏掉一次违规更贵。
  - **同会话同类型只提醒一次**——防刷屏。
  - Hook 自身任何异常都静默退出，绝不影响主流程（fail-open）。

登记表格式（TSV，放在项目 .claude/claim-patterns.tsv）：
    名称<TAB>正则表达式<TAB>前车之鉴说明
    # 开头为注释。例：
    否定裁决	(不支持|不能|无法实现|这是 bug|不是这个意思)	该判断需先读官方文档/源码确认

环境变量：
    CLAIM_GUARD_TABLE  自定义登记表路径（默认向上查找 .claude/claim-patterns.tsv）
"""
import json
import os
import re
import sys
import hashlib
import tempfile


def done(msg=None):
    """非阻断退出。msg 非空时作为 additionalContext 注入。"""
    if msg:
        sys.stdout.write(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": msg,
            }
        }, ensure_ascii=False))
    sys.exit(0)


def fail_silently():
    sys.exit(0)


try:
    raw = sys.stdin.read()
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    fail_silently()

tool_name = data.get("tool_name", "")
if tool_name not in ("Edit", "Write", "MultiEdit"):
    fail_silently()

tool_input = data.get("tool_input") or {}
file_path = tool_input.get("file_path") or ""

# 只关心「被写进去的内容」——那才是断言的落点
changed = []
for key in ("new_string", "content"):
    v = tool_input.get(key)
    if isinstance(v, str) and v:
        changed.append(v)
if not changed:
    fail_silently()
changed_text = "\n".join(changed)

# 定位登记表：环境变量优先，否则从被写文件向上找 .claude/claim-patterns.tsv
table = os.environ.get("CLAIM_GUARD_TABLE", "")
if not table or not os.path.isfile(table):
    here = os.path.dirname(os.path.abspath(__file__))
    candidates = []
    if file_path:
        d = os.path.dirname(os.path.abspath(file_path))
    else:
        d = here
    for _ in range(6):
        candidates.append(os.path.join(d, ".claude", "claim-patterns.tsv"))
        nd = os.path.dirname(d)
        if nd == d:
            break
        d = nd
    table = next((p for p in candidates if os.path.isfile(p)), None)
if not table:
    fail_silently()

entries = []
try:
    with open(table, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 3:
                continue
            entries.append((parts[0].strip(), parts[1].strip(), parts[2].strip()))
except Exception:
    fail_silently()

if not entries:
    fail_silently()

hits = []
for name, pattern, why in entries:
    try:
        m = re.search(pattern, changed_text)
        if m:
            hits.append((name, m.group(0), why))
    except re.error:
        continue

if not hits:
    fail_silently()

# 节流：同一会话同一类型只提醒一次
session_id = str(data.get("session_id") or "nosession")
state_dir = os.path.join(tempfile.gettempdir(), "claim-guard")
try:
    os.makedirs(state_dir, exist_ok=True)
    state_file = os.path.join(state_dir, hashlib.md5(session_id.encode()).hexdigest() + ".txt")
    seen = set()
    if os.path.isfile(state_file):
        with open(state_file, encoding="utf-8") as f:
            seen = {l.strip() for l in f if l.strip()}
    fresh = [(n, g, w) for (n, g, w) in hits if n not in seen]
    if fresh:
        with open(state_file, "a", encoding="utf-8") as f:
            for (n, _g, _w) in fresh:
                f.write(n + "\n")
    else:
        fresh = []
except Exception:
    fresh = hits

if not fresh:
    fail_silently()

lines = [
    "断言守卫 —— 你刚写入的内容里有断言性表述，落纸前先过三问：",
    "",
]
for name, got, why in fresh:
    lines.append("· 类型：" + name)
    lines.append("  · 命中：" + got)
    lines.append("  · 前车之鉴：" + why)
    lines.append("")

lines.append("三问：")
lines.append("① 这个断言的**原始依据**在哪？（文件路径 / 官方文档 URL / 命令输出）")
lines.append("② 我**查过**它，还是只听了转述 / 凭印象？")
lines.append("③ 如果我错了，代价是什么？")
lines.append("")
lines.append("判据：指不出依据 → 不要下「不成立 / 取消 / 不支持」这类断言，改成「待核」并写明要查什么。")
lines.append("（本条为「下结论前先查证」的机器兜底；同会话同类型只提醒一次。）")

done("\n".join(lines))
