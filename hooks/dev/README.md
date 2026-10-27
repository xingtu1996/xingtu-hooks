# Dev 角色 hooks

开发场景的 hooks（代码安全/不可逆操作拦截方向）。

## 当前 hooks

| Hook | 触发时机 | 作用 |
|------|---------|------|
| [destructive-command-guard](./destructive-command-guard/) | PreToolUse(Bash) | 拦截 rm -rf / git push --force / git reset --hard / git add -A / 磁盘级破坏 |

## 规划

| Hook | 触发时机 | 作用 | 状态 |
|------|---------|------|------|
| pre-tool-sensitive-file-guard | PreToolUse(Edit/Write) | 拦截直接编辑 .env/私钥（base 已有，此为 dev 增强版） | 已有（base/） |
| post-test-reminder | PostToolUse(Bash) | 改代码后提醒跑测试 | 规划中 |
