# Hook 实战指南

> 给已经在用 Claude Code（或同类 agent harness）、想把"每次都要做的事"从"求模型记得"升级成"结构强制"的人。
> 本文不抄官方文档，只沉淀实战中踩过的坑。

---

## 一、先回答：该用 hook 吗？

不是所有规则都该做成 hook。判断顺序：

| 你的诉求 | 用什么 | 为什么 |
|---------|--------|--------|
| 一段知识/背景/流程，模型知道后能更好 | 写进 AGENTS.md / CLAUDE.md / Skill | 知识靠注入，不需要拦截 |
| 每次必做、漏了有不可逆代价、且判据能写成正则 | **hook** | 文字规则会被绕过，hook 在工具层强制 |
| 低频、一次性、查一下就好 | 让 agent 自己做 | 加 hook 是常驻税 |

一句话：**hook 只留给"必须机械强制"的确定性行为。能用 rule/Skill 解决的，不要上 hook。**

三个判据全中才值得做 hook：

1. **违反代价高**——比如 rm -rf 不可逆，写错了收不回
2. **靠自觉已经失效**——同一根因短期内犯过不止一次
3. **判据能机械化**——是"文件路径是否匹配正则"这种存在性/模式检查，不需要理解语义

缺一条都别做。你会发现很多"我觉得该拦一下"的东西，其实三条都不齐。

---

## 二、Hook 事件类型表

| Event | 触发时机 | 典型用途 |
|-------|---------|---------|
| `SessionStart` | 会话启动 / resume / clear / compact | 注入常驻提醒（低频）；初始化环境 |
| `UserPromptSubmit` | 用户每条消息提交时 | **禁止用于注入**（逐消息高频税）。仅可用于 prompt 改写且 stdout 置空 |
| `PreToolUse` | 调用工具前（matcher 匹配工具名） | 命令改写；门禁拦截（危险命令/敏感文件）；权限预检 |
| `PostToolUse` | 工具执行后 | 校验副作用（改完 .sh 跑 lint）；失败拦截；日志审计 |
| `Stop` | 一轮 agent 回合结束 | 状态落盘；进度摘要；会话回顾 |
| `SubagentStart` | 子 agent 启动时 | 注入子 agent 提醒 |
| `PreCompact` | 上下文压缩前 | 压缩前状态保存 |

**matcher 语法**：正则字符串。
- `PreToolUse`/`PostToolUse` 匹配工具名：`Bash`、`Grep|Glob`、`Edit|Write`、`*`
- `SessionStart` 的 matcher：`startup` / `resume` / `clear` / `compact`，可 `|` 组合

---

## 三、settings.json 注册格式

```jsonc
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/绝对路径/hook.sh",
            "timeout": 5000
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          { "type": "command", "command": "/绝对路径/reminder.sh" }
        ]
      }
    ]
  }
}
```

要点：
- **command 用绝对路径**，别用 `~`（harness 展开时机不确定）
- 门禁/改写类 hook 必设 `timeout`（毫秒），5000 够了——别让 hook 拖慢工具调用
- 同事件多个 hook 会多次 spawn 子进程。**同事件的检查尽量合并成一个脚本**，省 spawn 开销

---

## 四、脚本 stdout 协议

### 4.1 纯注入（SessionStart / SubagentStart）

stdout 直接输出文本 → 自动成为 additionalContext 注入上下文：

```bash
#!/usr/bin/env bash
cat << 'REMINDER'
你的提醒内容（< 500 字节，只写会犯错的强制约束，别写废话）
REMINDER
```

### 4.2 需要决策时（PreToolUse / PostToolUse）

输出 JSON。用 `python3 -c json.dumps` 构造，**别自己拼字符串**（中文/引号/换行转义会踩坑）：

```bash
# 拦截
python3 -c "import sys,json;print(json.dumps({'hookSpecificOutput':{'hookEventName':'PreToolUse','decision':'block','reason':'为什么拦'}},ensure_ascii=False))"

# 放行
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"allow"}}'
```

### 4.3 PostToolUse 的坑（实测踩过）

**PostToolUse 的纯文本 stdout 不回注模型**，只写进 debug log。想让模型看到提醒，必须输出 JSON：

```json
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"你想说的话"}}
```

我们有个 hook 建好却"像没生效"，查了半天根因就是这个——脚本跑了，但吐的是纯文本，模型根本看不见。

### 4.4 退出码约定（Claude Code）

- `0` = 放行
- `2` = 阻止（stderr 内容回注给模型）
- 其他 = 非阻断错误

---

## 五、注入体积预算

| 指标 | 预算 | 原因 |
|------|:---:|------|
| hook 单次事件注入 | **< 500B** | 每 KB 常驻 × 每会话 = 固定烧 token |
| UserPromptSubmit 注入 | **= 0** | 逐消息高频税，实测 1KB/消息 就是纯浪费 |
| 门禁类 hook 超时 | ≤ 5000ms | 不拖慢工具调用 |

写通过删除：注入内容只写"会犯错的强制约束"，不写正确的废话。写之前问自己：这句不注入，模型真会错吗？不会就删。

---

## 六、新增 hook 准入五问

新增之前逐条自检，任一不过就别加：

1. **注入体积 < 500B？** 实测 `wc -c` 你的脚本输出。超了先精简，或改成指针（只留一句话 + 文件路径）。
2. **该用 hook 吗（vs rule/Skill）？** 确定性行为 → hook；知识/流程 → rule。能用 rule 就别 hook。
3. **没挂 UserPromptSubmit 做注入？** 那是高频税。只挂 SessionStart/Stop/PreCompact 等低频事件。
4. **模型已知的内容重复注入了？** L0/L1 通用常识不进 hook。
5. **有验证途径？** 必须能手动喂 JSON 测 block/allow。测不了的 hook 等于没有。

---

## 七、场景骨架

### 场景 A：会话级强制提醒（低频注入）

```
场景：每次会话开始让 agent 记住某条铁律
事件：SessionStart（matcher: startup|resume|clear|compact）
脚本：stdout 输出 < 500B 提醒
验证：新开会话 → 看上下文里有没有这句话
```

### 场景 B：工具调用门禁（拦截/改写）

```
场景：禁止 rm -rf / 强制危险命令走安全脚本
事件：PreToolUse（matcher: Bash）
脚本：解析 stdin JSON 的 command 字段，正则命中 → exit 2 + stderr 原因
验证：echo '{"tool_input":{"command":"rm -rf /"}}' | bash hook.sh
```

### 场景 C：工具副作用校验（事后提醒）

```
场景：改完 .sh 文件自动跑多字节 lint
事件：PostToolUse（matcher: Edit|Write）
脚本：读 file_path，是 .sh 就跑 lint，发现问题输出 JSON additionalContext
注意：必须走 JSON，纯文本模型看不见
```

---

## 八、验证方法

```bash
# 手动喂 JSON 测 PreToolUse 门禁（注意用 bash 调 .sh，python3 调 bash 脚本会语法报错，那是你喂错了解释器，不是 hook 的问题）
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf foo"}}' | bash hooks/dev/destructive-command-guard/hook.sh
echo $?   # 应为 2

# 测放行
echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | bash hooks/dev/destructive-command-guard/hook.sh
echo $?   # 应为 0

# 看注入文本体积
bash hooks/base/ponytail-yagni-reminder/hook.sh | wc -c
```

改了 settings.json 里的注册（command/matcher），**当前会话不生效，要重启会话**才加载。
改 hook 脚本本体则立即生效（每次调用现读）。

---

## 九、反面教材（别重蹈）

1. **通知伪装成门禁**：写个 hook 每次都 allow，只是打印一句提醒——这不是门禁，是常驻税。真门禁要能 block。
2. **黑名单当安全边界**：正则能被 `/bin/rm`、复合命令内嵌绕过。hook 只防"规范形式"，真正的安全底线靠路径限制/沙箱/人审。
3. **fail-closed 过度**：hook 自己崩了就卡住所有工具调用——这是把单点故障扩大化。门禁类 hook 一律 fail-open（解析失败就放行，规则层兜底）。
4. **同事件堆多个 hook**：每次工具调用 spawn 3 个脚本 = 3 倍延迟。合并成一个。
5. **同会话刷屏提醒**：提醒类 hook 要做节流（同会话同类型只提醒一次），否则吵几次模型就免疫了。
6. **正则只测了一种写法**：初版拦 `rm -rf` 的正则要求"两个分开的 flag"或"f 在前 r 在后"，结果连写的 `rm -rf`（r 在前 f 在后）漏拦——测试时喂了 `rm -rf foo/` 才发现 exit 0。**门禁正则必须测全 flag 排列组合：`-rf`/`-fr`/`-Rf`/`-fR`/`-r -f`，再测正常操作不误伤。**
7. **自己骗自己的测试**：拿 python3 去调一个 bash 脚本，看到 SyntaxError 以为 hook 坏了——其实是喂错了解释器。测试前先看 shebang：`#!/usr/bin/env bash` 就用 bash 喂，`#!/usr/bin/env python3` 就用 python3 喂。
