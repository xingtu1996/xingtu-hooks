# Content 角色 hooks

内容创作场景的 hooks（写作/断言/脱敏方向）。

## 当前 hooks

| Hook | 触发 | 作用 |
|------|------|------|
| [claim-guard](./claim-guard/) | PostToolUse(Edit/Write) | 写入命中断言模式时提醒三问（原始依据在哪？查过还是凭印象？错了代价？） |

## 规划

| Hook | 触发时机 | 作用 | 状态 |
|------|---------|------|------|
| pre-publish-privacy-gate | Stop / 发文前 | 检查稿子里有无真名/公司名/内网域名/密钥 | 规划中 |
| pre-publish-ai-flavor-gate | Stop / 发文前 | 检测 AI 味（空泛口号/加粗过多/引用块过多） | 规划中 |

> 这些 hook 从行途工作区的 `tools/privacy_scan.py`、`de-ai-flavor` skill、`mp-prepublish-draft-verify` 蒸馏而来。
> 当前基座 hooks（base/）已覆盖通用安全防护，角色专属 hooks 逐步补充。
