---
name: gitmoji-commit
description: Write Gitmoji commit messages for BangumiToday using the fixed Chinese style and an emoji selected from the actual change intent and official semantics. Use when drafting or making commits, amending commit messages, splitting commits, or maintaining this project's commit rules. 适用于本项目的 Gitmoji 选择、中文提交信息、原子化提交或提交规则维护。
---

# Gitmoji Commit

编写 Gitmoji 风格的提交信息：一个 emoji 前缀 + 简洁 subject，**不追加类型后缀**（如 `init:`、`feat:`）。按本次提交的主要目的选择 emoji。

## 规则

- 格式：`<emoji> <subject>`，使用实际 emoji 字符，不写 `:shortcode:`，不堆叠多个 emoji。
- 不要在 emoji 后追加 Conventional Commits 类型：写 `🎉 xxx`，不要写 `🎉 init: xxx`。
- subject 用祈使句、简洁（尽量 ≤ 50 字符），描述这次改动做了什么。
- 提交标题与正文使用中文，语言和风格按项目 [AGENTS.md](../../../AGENTS.md) 的固定约定执行。
- 不为确认提交语言、模仿措辞或格式、选择 emoji 读取 Git 历史。
- 仅在用户明确要求时提交或改写历史；只编写信息或修改提交规则不代表获准提交。

## 选择 emoji

1. 先看实际 diff，概括这一逻辑变更的主要目的；执行提交时以最终暂存区为准。不要仅凭文件名、改动行数或“新增／修复／优化”等标题词选择。
2. 每次选择前阅读 [选择边界与示例](references/emoji-selection.md)，比较与当前目的相关的候选。使用 `✨`、`🐛`、`♻️`、`💄`、`🔧` 等通用图标前，检查是否有语义更准确的专用图标。
3. 专用图标与主要目的吻合时优先使用；只匹配实现细节时，仍按主要目的选择。例如修复数据库查询错误可以用 `🐛`，不能仅因修改了数据库文件就用 `🗃️`。
4. 参考中未覆盖或含义不确定的候选，查阅 [Gitmoji 官方完整目录](https://gitmoji.dev/) 或 [官方机器可读定义](https://gitmoji.dev/api/gitmojis)。本地示例不是允许列表，不限制使用其他官方图标。
5. 检查 emoji 与 subject 是否表达同一目的。不要为了图标多样性强用生僻图标，也不要在没有证据时声称紧急热修复、性能提升或破坏兼容性。

## 原子化提交

- 一次提交只包含一个逻辑变更，提交信息只描述这一项，不要罗列多项。
- 一次改动含多个独立方向时，拆成多次提交（`git add` 指定文件或 `git add -p` 选择改动）。
- 先按主题划分改动，再暂存和提交；功能、安全、配置/CI、依赖、格式化、测试、文档等默认视为不同主题。
- 同一文件同时包含多个主题时，必须使用 `git add -p`、临时补丁或等价方式拆分到不同提交。
- 不要为了“方便”把无关的格式化、生成文件或文档混入功能提交；只有它们是该主题不可分割的一部分时才可合并。
- 多项改动必须一起提交时，先确认它们无法独立回滚或验证，并在提交说明中只保留一个共同目的，而不是用顿号罗列。

## 工作流

1. 先 `git status` / `git diff` 确认改动内容。
2. 若包含多项独立改动，先列出提交分组及其文件/补丁范围；按逻辑目的拆分，再依据“选择 emoji”为每组独立选图标。不要按图标种类拆分本来不可分割的改动。
3. 每次提交前检查暂存区只属于当前分组（`git diff --cached`），提交后确认该分组已清空，再处理下一组。
4. 修正本地最后一条提交：`git commit --amend -m "<message>"`；需要拆分已有本地提交时，在保留工作区改动的前提下重写本地历史，并逐组提交。
5. 未经用户明确要求，不修改已推送/共享的提交。
