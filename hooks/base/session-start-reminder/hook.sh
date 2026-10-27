#!/usr/bin/env bash
# session-start-reminder — SessionStart 注入轻量工作提醒
# 事件: SessionStart ｜ 输出: additionalContext（≤500B，克制注入）
cat << 'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"工作前提醒：①先读 README/AGENTS 再动手 ②结论先行、不擅扩范围 ③涉及删除/覆盖先备份 ④完成后回读验证"}}
JSON
