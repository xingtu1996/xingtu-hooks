# xingtu-hooks — AI Agent 钩子集（按角色选装）

> 给 AI Coding Agent 装的"机械护栏"——规则文件里的"别这么做"是请求，hook 是墙。
> 根据你的角色（开发 / 内容创作）选装对应的 hooks，base 安全防护所有人必装。

## 为什么需要 hooks

CLAUDE.md / AGENTS.md 里写的 "never do X" 是**请求**，不是**保证**——模型可能忽略、可能被绕过（变量拼接、复合命令内嵌）。而 `rm -rf` / `git push -f` / 直接编辑 `.env` 是不可逆的。

hook 由 harness 在工具执行前强制运行，不依赖模型记忆。

## 按角色选装

```
hooks/
├── base/       # 通用防护（所有角色必装）
│   ├── pre-tool-secret-guard     # 拦截直接编辑 .env/私钥
│   ├── post-tool-bash-log        # bash 命令执行记录
│   ├── session-start-reminder    # 会话开始轻量提醒
│   ├── session-recap             # 停止前生成一行 recap
│   ├── stop-review-check         # 停止前交付检视
│   ├── sediment-signal           # 检测到用户纠偏多时写沉淀卡
│   └── ponytail-yagni-reminder   # 写新代码前先过 YAGNI 七问
├── dev/        # 开发者装
│   └── destructive-command-guard  # 拦截 rm -rf / git push -f / git reset --hard / git add -A
└── content/    # 内容创作者装
    └── claim-guard                 # 写入命中断言模式时提醒三问（依据在哪？查过还是凭印象？）
```

## 快速安装

```bash
git clone https://github.com/xingtu1996/xingtu-hooks.git
cd xingtu-hooks

# 交互式选择角色
bash install.sh

# 或直接指定
bash install.sh --role dev       # 开发者
bash install.sh --role content   # 内容创作者
bash install.sh --role all      # 全部
```

安装器会把对应 hooks 复制到 `~/.claude/hooks/`，然后你在 agent 配置（settings.json）里注册各 hook 的触发事件（见每个 hook 目录下的 `hook.json`）。

## Hook 列表

### Base（必装）

| Hook | 触发 | 作用 |
|------|------|------|
| pre-tool-secret-guard | PreToolUse(Edit/Write) | 拦截直接编辑 .env/私钥/pem，密钥走环境变量 |
| post-tool-bash-log | PostToolUse(Bash) | bash 命令执行结果记录，失败时提示检查报错 |
| session-start-reminder | SessionStart | 会话开始注入轻量工作提醒（≤500B 克制注入） |
| session-recap | Stop | 扫描本轮文件变更/git 提交，生成一行 recap 给用户 |
| stop-review-check | Stop | 停止前提醒交付检视（落盘验证/敏感检查/未完成项说明） |
| sediment-signal | Stop/PreCompact | 用户纠偏/报错多时写一张「候选技能沉淀卡」到收件箱 |
| ponytail-yagni-reminder | SessionStart | 注入 YAGNI/最少代码阶梯，写新代码前先过七问 |

### Dev（开发者）

| Hook | 触发 | 作用 |
|------|------|------|
| destructive-command-guard | PreToolUse(Bash) | 拦截 rm -rf / git push --force / git reset --hard / git clean -f / git add -A / 磁盘级破坏 |

### Content（内容创作）

| Hook | 触发 | 作用 |
|------|------|------|
| claim-guard | PostToolUse(Edit/Write) | 写入命中断言模式时提醒三问（原始依据在哪？查过还是凭印象？错了代价？） |

## 设计原则

- **fail-open**：hook 自身解析失败一律放行（exit 0），不能因为 hook 故障卡住所有操作
- **只拦不可逆**：正常操作一律放行，避免天天误伤
- **block 时给逃生门**：提示用户在终端手动执行（本人在场、知情）
- **零依赖**：bash + python3 标准库，任何环境能跑

## 与其他仓的关系

- [xingtu-cli](https://github.com/xingtu1996/xingtu-cli) — CLI 工具集（人+AI 终端命令）
- [xingtu-skills](https://github.com/xingtu1996/xingtu-skills) — Agent Skills 库（工作流编排）
- [harness-kit](https://github.com/xingtu1996/harness-kit) — 完整 harness 生成器（含 preset 机制）

## 许可证

MIT License
