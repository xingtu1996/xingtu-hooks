#!/usr/bin/env bash
# stop-review-check — Stop 时提醒交付检视
# 事件: Stop ｜ 输出: additionalContext
cat << 'JSON'
{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"停止前自查：①产物是否真实落盘并回读验证 ②是否按 README/AGENTS 约定 ③敏感信息是否泄露（.env/密钥/内部域名）④未完成项是否如实说明"}}
JSON
