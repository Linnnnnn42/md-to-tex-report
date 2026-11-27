# md-to-tex-report

[English](README.md) | 简体中文

一个模板仓库：用 Markdown 分章节写报告，在本地或通过 GitHub Actions 编译成 LaTeX 和 PDF。

每章是一个 Markdown 文件。Pandoc 按文件名顺序合并这些文件，用 `report/` 里的模板转换成 LaTeX，再由 XeLaTeX 编译出 PDF。生成的 PDF 带有编号、可点击跳转的目录，以及显示在 PDF 阅读器侧边栏的书签大纲。

## 目录结构

```text
examples/                    一份报告：带编号的 Markdown 章节
  00-title-page.md           封面信息（只有 YAML）
  01-introduction.md ...     各章正文，按文件名顺序合并
  figures/                   各章引用的图片（可选）
  report.yaml                这份报告专用的 pandoc 设置（可选）
  outputs/                   构建结果：report.tex、report.pdf
report/
  defaults.yaml              所有报告共用的 pandoc 设置（标题映射、编号、版式）
  template.tex               LaTeX 模板，包括封面
  filters/missing-images.lua 图片文件还不存在时画一个占位框
  filters/appendix.lua       从标记了 {.appendix} 的标题开始进入附录
scripts/
  build-report.sh            构建一个报告目录
  install-deps-ubuntu.sh     在 Ubuntu 上安装 pandoc 和 TeX Live（CI 使用）
.github/workflows/build-report.yml
```

## 编写章节

- 文件按 `NN-kebab-case.md` 命名（例如 `03-requirements.md`）。只有以数字开头的文件会参与构建，按文件名顺序排列。
- 标题里不要自己写编号，编号由 LaTeX 生成。
- 标题映射（在 `report/defaults.yaml` 中设置）：

  | Markdown | LaTeX            | 编号  | 出现在目录 |
  | -------- | ---------------- | ----- | ---------- |
  | `#`      | `\chapter`       | 1     | 是         |
  | `##`     | `\section`       | 1.1   | 是         |
  | `###`    | `\subsection`    | 1.1.1 | 是         |
  | `####`   | `\subsubsection` | 无    | 否         |
  | `#####`  | `\paragraph`     | 无    | 否         |

  如果想让 `#` 对应 `\section`（文章式报告），设置 `top-level-division: section` 和 `documentclass: article`。
- 不编号的章：`# Bibliography {-}`。
- 附录：`# Meeting Minutes {.appendix}` 会变成 "Appendix A"，之后的各章也都用字母编号。
- 图片：`![图注](figures/name.png)`，路径相对于报告目录。如果文件还不存在，PDF 里会显示一个带图注和路径的占位框，而不会编译失败。
- 表格：使用管道表格。在表格正上方写一行 `Table: 标题`，表格就会有带编号的标题。
- 封面：编辑 `00-title-page.md` 里的 YAML。值里不要用 `<尖括号>`，Markdown 会把它当作 HTML 标签丢掉。

## 本地构建

需要 [pandoc](https://pandoc.org) 3.x，以及带 XeLaTeX 和 latexmk 的 TeX 发行版（TeX Live 或 MiKTeX）。

```bash
bash scripts/build-report.sh examples
```

这会生成 `examples/outputs/report.tex` 和 `examples/outputs/report.pdf`。设置 `REPORT_NAME=final` 可以把输出改名为 `final.tex` 和 `final.pdf`。

## GitHub Actions

`.github/workflows/build-report.yml` 在以下时机运行：

- 每次 push 到 `main` 且改动了报告源文件时，
- 每次向 `main` 提交改动了报告源文件的 pull request 时，
- 在 Actions 页面手动运行（**Run workflow**）时，可以填写要构建哪些报告目录。

每次运行都会把 `report.tex` 和 `report.pdf` 上传为名为 `report-<commit sha>` 的 artifact。push 到 `main` 时，还会把 `<dir>/outputs/` 提交回分支。不需要的话，设置 `COMMIT_OUTPUTS: "false"`。如果 `main` 开启了分支保护、不允许 Actions 推送，请关闭这个选项，或者允许 `github-actions[bot]` 推送。

要在 push 时构建其他报告目录，修改 `REPORT_DIRS`（用空格分隔），并把这些目录加进 `paths` 过滤条件。

## 自定义

- 页面版式、字体、链接颜色、编号深度：修改 `report/defaults.yaml` 里的 `variables`；只想改某一份报告，就在那个报告目录里放一个 `report.yaml`。
- 封面和导言区：修改 `report/template.tex`。它是 pandoc 默认 LaTeX 模板，加上了自定义封面、前置部分的罗马页码和页眉。
- 中文内容：在 `variables` 下加 `CJKmainfont: Noto Serif CJK SC`（或其他已安装的中文字体）。在 CI 上还需要在 `scripts/install-deps-ubuntu.sh` 里安装 `fonts-noto-cjk`。
