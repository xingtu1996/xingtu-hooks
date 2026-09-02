# XingTu Hooks · Claude Code 钩子集合

> 开箱即用的 Agent 钩子（hooks），覆盖安全拦截 / 会话提醒 / 交付检视。

![MIT](https://img.shields.io/badge/license-MIT-green.svg)

## 这是什么

`xingtu-hooks` 是行途开源矩阵的**钩子资产仓**。聚合 AI 工程实践中打磨的 Claude Code hooks，按场景开箱即用。市面鲜有系统开源的 hooks 集合，这是差异化资产。

## Hooks 清单

| Hook | 说明 | 触发时机 |
|------|------|---------|
| pre-tool-secret-guard | 拦截敏感文件（.env / 私钥 / 凭据）编辑 | PreToolUse(Edit\|Write) |
| post-tool-bash-log | Bash 执行结果记录，失败提示 | PostToolUse(Bash) |
| session-start-reminder | 会话开始注入轻量工作提醒 | SessionStart |
| stop-review-check | 停止前提醒交付检视 | Stop |

## 安装

```bash
# 复制到项目 .claude/hooks/
cp -r hooks/<hook-name> .claude/hooks/

# 注册到 settings.json（示例）
# "hooks": {
#   "PreToolUse": [ { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": "bash .claude/hooks/pre-tool-secret-guard/hook.sh" } ] } ],
#   "SessionStart": [ { "hooks": [ { "type": "command", "command": "bash .claude/hooks/session-start-reminder/hook.sh" } ] } ],
#   "Stop": [ { "hooks": [ { "type": "command", "command": "bash .claude/hooks/stop-review-check/hook.sh" } ] } ]
# }
```

## Hook 协议

- 输入：stdin JSON（含 `tool_name` / `tool_input` 等）
- 输出：`{"hookSpecificOutput": {"hookEventName": "...", "decision": "block|allow", "reason": "..."}}`
- PreToolUse 可 block/allow；SessionStart/Stop 用 `additionalContext` 注入轻量提醒（≤500B 克制）

## 设计原则

- **确定性行为用 hook 强制**：模型会忘指令，hook 由 harness 执行不依赖模型记忆
- **克制注入**：会话注入 ≤500B，不用 hook 做长文提醒
- **安全第一**：拦截优先于放行，敏感文件一律走环境变量

## 许可证

MIT License
