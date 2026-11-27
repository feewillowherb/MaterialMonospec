# MaterialMonospec / assets / svg — Agent 约定

本目录用于存放 Chat 中 AI 生成的 SVG 预览与矢量资产，**纳入 Git 跟踪**，统一按**年月日**分层，便于按时间访问与整夹清理。

## 目录结构

```text
assets/svg/
├── AGENTS.md
└── YYYY/
    └── MM/
        └── DD/
            ├── <topic-slug>[-vN].svg        # 有明确主题
            ├── <HHmm>-<kind>.svg            # 弱主题（形态描述）
            └── <HHmm>-preview-<NN>.svg      # 无主题兜底
```

示例：

```text
assets/svg/2026/11/27/
├── weighing-flow-v1.svg
├── weighing-flow-v2.svg
├── 1105-layout-draft.svg
└── 1112-preview-01.svg
```

## 命名规则

- 全小写字母、数字与连字符（kebab-case），**禁止**空格与特殊字符。
- **有明确 topic**：`<topic-slug>[-vN].svg`（如 `urban-client-arch-v1.svg`）。
- **无明确 topic（随手预览）**：不另建 `misc/` 子目录，直接放当天 `YYYY/MM/DD/` 下，使用以下兜底命名：
  - 有模糊形态：`<HHmm>-<kind>.svg`（如 `1105-card-preview.svg`）
  - 完全无主题：`<HHmm>-preview-<NN>.svg`（如 `1112-preview-01.svg`）
- 同一主题微调优先直接局部编辑原文件；需要对比保留历史版本时递增 `-v2`、`-v3`。

## MUST / MUST NOT

- **MUST** 将 Chat 中生成的 SVG 预览直接落盘到当天 `assets/svg/YYYY/MM/DD/`，并在回复中返回可点击的文件路径；**禁止**在对话正文反复整段倾倒大块 `<svg>` XML。
- **MUST** 在 `<svg>` 根元素内包含简短的 `<title>` 或 `<desc>`，说明图示用途，便于无 topic 文件后续检索。
- **MUST** 尽量使用整数坐标并复用 `<style>` / `<defs>`，减少冗余属性与 Token 消耗。
- **MUST NOT** 在 SVG 中内嵌 base64 位图（如 `<image href="data:image/png;base64,...">`），保持纯矢量文本，避免膨胀 Git 仓库。
- **MUST NOT** 按 topic 再嵌套子文件夹（保持 `YYYY/MM/DD/` 扁平存放）。

## 清理约定

- 按年（`YYYY/`）、按月（`YYYY/MM/`）或按日（`YYYY/MM/DD/`）整夹删除过期预览，并做常规 Git 提交（如 `chore(svg): prune 2026-09 previews`）。
- 删除前若该 SVG 可能被 `docs/` 或 `openspec/` 引用，先全局搜索文件名确认无断链。
