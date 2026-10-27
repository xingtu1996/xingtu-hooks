#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sediment-signal — 会话沉淀信号器（跨会话技能复利引擎 L1）

读 hook stdin JSON，对 transcript 尾部做轻量启发式：
  - 用户纠偏词（"不对/别这样/重来/又错/说过"等）
  - 工具报错次数（is_error:true）
  - 工具调用密度
过阈值 → 写一张候选技能卡到收件箱目录，提示人工分诊：
  "这次会话里反复出现的模式，值不值得沉淀成一个可复用的 skill？"

铁律：
  - fail-open：任何异常 exit 0，绝不阻断会话
  - 每会话最多 1 卡（同会话重复触发只追加信号）
  - pending + stale 卡片 >= 15 时拒写（防收件箱爆炸）
  - 信号器只报"有事发生"，说不出该沉淀什么——分诊由人做

环境变量：
  SEDIMENT_INBOX_DIR  卡片输出目录（默认 ~/.claude/skill-inbox/cards）
  SEDIMENT_LOG        日志路径（默认同目录 signal-log.jsonl）
  SEDIMENT_THRESHOLD  阈值（默认 3）
"""
import sys, os, re, json, hashlib, datetime

HOME = os.path.expanduser("~")
CARDS = os.environ.get("SEDIMENT_INBOX_DIR", os.path.join(HOME, ".claude", "skill-inbox", "cards"))
LOG = os.environ.get("SEDIMENT_LOG", os.path.join(os.path.dirname(CARDS), "signal-log.jsonl"))
CORRECT = ["不对", "别这样", "重来", "重新来", "又错", "不是这样", "以后不要", "记住", "说过"]
THRESHOLD = int(os.environ.get("SEDIMENT_THRESHOLD", "3"))


def log(kind, msg=""):
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(json.dumps({"ts": datetime.datetime.now().isoformat(timespec="seconds"),
                                "kind": kind, "msg": msg[:200]}, ensure_ascii=False) + "\n")
    except Exception:
        pass


def tail_lines(p, n=400):
    with open(p, encoding="utf-8", errors="ignore") as f:
        return f.readlines()[-n:]


def main():
    try:
        payload = json.loads(sys.stdin.read() or "{}")
        tp = os.path.expanduser(str(payload.get("transcript_path", "")))
        sid = str(payload.get("session_id", "anon"))
        if not tp or not os.path.isfile(tp):
            return
        lines = tail_lines(tp)
        corrections, errors, tool_uses = 0, 0, 0
        for ln in lines:
            if '"type":"user"' in ln or '"type": "user"' in ln:
                for kw in CORRECT:
                    corrections += ln.count(kw)
            errors += ln.count('"is_error":true') + ln.count('"is_error": true')
            tool_uses += ln.count('"tool_use"')
        score = min(10, corrections + (2 if errors >= 3 else 0) + (2 if tool_uses >= 15 else 0))
        if score < THRESHOLD:
            return
        # 池界：pending + stale >= 15 拒写
        pend = 0
        if os.path.isdir(CARDS):
            for fn in os.listdir(CARDS):
                if fn.endswith(".md"):
                    try:
                        head = open(os.path.join(CARDS, fn), encoding="utf-8").read(600)
                        if re.search(r"^status: (pending|stale)", head, re.M):
                            pend += 1
                    except Exception:
                        pass
        if pend >= 15:
            log("quota_rejected", f"session={sid} score={score}")
            return
        # 每会话一卡
        h = hashlib.sha1(sid.encode()).hexdigest()[:6]
        slug = f"signal-{h}"
        now = datetime.datetime.now()
        os.makedirs(CARDS, exist_ok=True)
        existing = [f for f in os.listdir(CARDS) if slug in f]
        if existing:
            p0 = os.path.join(CARDS, existing[0])
            with open(p0, "a", encoding="utf-8") as f:
                f.write(f"\n- (追加信号 {now:%m-%d %H:%M} score={score}) {tp}")
            log("merged", existing[0]); return
        path = os.path.join(CARDS, f"{now:%Y%m%d-%H%M}-{slug}.md")
        title = "会话内出现纠偏/报错-修复/长流程信号，待分诊决定是否沉淀技能"
        card = f"""---
id: {os.path.basename(path)[:-3]}
ts: {now:%Y-%m-%d %H:%M}
slug: {slug}
score: {score}
status: pending
evidence:
  - {tp}
---
## 场景信号

自动提名（sediment-signal @ {payload.get('hook_event_name', '?')}）：
纠偏词×{corrections}、工具报错×{errors}、tool_use×{tool_uses}。

## 建议技能内容

【待分诊】信号器只能报"有事发生"，说不出该沉淀什么——
由人工回看 transcript 决定是否值得做成可复用 skill。

## 拍板与落盘记录

- {now:%Y-%m-%d %H:%M} 钩子建卡
"""
        open(path, "w", encoding="utf-8").write(card)
        log("written", os.path.basename(path))
    except Exception as e:
        log("error", repr(e))
    finally:
        sys.exit(0)


if __name__ == "__main__":
    main()
