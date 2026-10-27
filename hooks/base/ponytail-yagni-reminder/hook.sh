#!/usr/bin/env bash
# ponytail-yagni-reminder — SessionStart 注入 YAGNI 阶梯
#
# 事件: SessionStart(startup|resume|clear|compact) ｜ 输出: stdout 文本 → additionalContext
#
# 为什么：YAGNI（You Aren't Gonna Need It）写在规则里是"建议"，模型一赶工就忘。
# 每次会话开始把"最少代码"变成强制约束，而不是一句口号。
# 注入体积极小（< 500B），只挂低频事件，不挂 UserPromptSubmit（那是逐消息高频税）。
cat << 'REMINDER'
YAGNI 阶梯 —— 写任何新代码前按序过一遍：
1. 这东西真的需要存在吗？（推测性需求 = 跳过，写一行理由）
2. 代码库里已经有了吗？先搜；几行之外重写一遍 = 烂代码
3. 标准库能做吗？用它
4. 平台原生能力覆盖吗？（DB 约束胜过应用代码，CSS 胜过 JS）
5. 已装依赖能解吗？别为几行能搞定的事加一个依赖
6. 能写成一行吗？写成一行
7. 然后：用能跑的最少代码实现。
规则：不做投机性抽象；删除 > 新增；文件越少越好；
刻意简化处用 `ponytail:` 注释标注（上限 + 升级路径）。
永不省掉：输入校验、错误处理、安全、可访问性、用户明确要求。
REMINDER
