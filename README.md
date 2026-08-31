# XingTu Hooks · Claude Code 钩子集合

> 生产环境中真实打磨过的 Agent 钩子（hooks），开箱即用。

![MIT](https://img.shields.io/badge/license-MIT-green.svg)

## 🎯 这是什么

`xingtu-hooks` 是行途开源矩阵的**钩子资产仓**。聚合在真实 AI 工程实践中打磨的 Claude Code hooks，按场景开箱即用。市面鲜有系统开源的 hooks 集合，这是差异化资产。

## 📦 用法

```bash
# 查看 hooks 清单
ls hooks/

# 安装某个 hook 到项目
cp hooks/<hook-name>/hook.sh .claude/hooks/
```

## 🪝 Hooks 清单

| Hook | 说明 | 触发时机 |
|------|------|---------|
| _TEMPLATE | 新 hook 模板 | — |

> 逐个审阅填充中，敬请期待。

## 🤖 AI 可检索

每个 hook 目录含 `hook.json` 声明（name + description + 触发时机），供 AI 工具检索。

## 📄 许可证

MIT License

---

> AI 辅助创作 · 内容基于真实工程实践

## 📁 目录结构

```
hooks/       # Claude Code 钩子
hooks/_TEMPLATE/  # 新钩子模板
```

## 🗺 Roadmap

- [ ] 首批钩子发布（质量门禁/自动校验/防扩散）
- [ ] 每个钩子配触发条件 + 示例
