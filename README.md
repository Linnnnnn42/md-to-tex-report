# md-to-tex-report

English | [简体中文](README-zh.md)

A template repository for writing a report as Markdown chapters and building it into LaTeX and PDF, locally or with GitHub Actions.

Each chapter is a Markdown file. Pandoc merges the files in name order, converts them to LaTeX with the template in `report/`, and XeLaTeX compiles the PDF. The PDF has a numbered, clickable table of contents and a bookmark outline for the PDF reader's sidebar.

## Layout

```text
markdown/                    One report: numbered Markdown chapters
  00-title-page.md           Title page metadata (YAML only)
  01-introduction.md ...     Chapters, merged in file-name order
  figures/                   Images referenced by the chapters (optional)
  report.yaml                Per-report pandoc settings (optional)
  outputs/                   Build results: report.tex, report.pdf
report/
  defaults.yaml              Shared pandoc settings (heading mapping, numbering, layout)
  template.tex               LaTeX template, including the title page
  filters/missing-images.lua Draws a placeholder box for images that don't exist yet
  filters/appendix.lua       Starts the appendices at a heading marked {.appendix}
scripts/
  build-report.sh            Builds one report directory
  preview.sh, preview.ps1    Builds the report (or selected chapters) into a preview PDF in Documents
  install-deps-ubuntu.sh     Installs pandoc and TeX Live on Ubuntu (used by CI)
.github/workflows/
  build-report.yml           Builds the report on push, pull request or manual run
  template-sync.yml          Opens pull requests with updates from this template
.templatesyncignore          Paths template sync never overwrites
```

## Writing chapters

- Name files `NN-kebab-case.md` (e.g. `03-requirements.md`). Only files starting with a digit are built, in name order.
- Don't number headings yourself. LaTeX numbers them.
- Heading mapping (set in `report/defaults.yaml`):

  | Markdown | LaTeX            | Numbered | In contents |
  | -------- | ---------------- | -------- | ----------- |
  | `#`      | `\chapter`       | 1        | yes         |
  | `##`     | `\section`       | 1.1      | yes         |
  | `###`    | `\subsection`    | 1.1.1    | yes         |
  | `####`   | `\subsubsection` | no       | no          |
  | `#####`  | `\paragraph`     | no       | no          |

  To map `#` to `\section` instead (an article-style report), set `top-level-division: section` and `documentclass: article`.
- Unnumbered chapter: `# Bibliography {-}`.
- Citations: write the bibliography as a numbered list (`1. Author, A. Title ...`) under a level-1 heading titled `Bibliography` or `References` (or marked `{.bibliography}`), and cite entries in the text as `[3]`, `[1, 4]` or `[2–5]`. Each citation becomes a link to its entry. Numbers that aren't in the list stay plain text.
- Appendix: `# Meeting Minutes {.appendix}` becomes "Appendix A", and every later chapter is lettered too.
- Figures: `![Caption](figures/name.png)`. Paths are relative to the report directory. If the file doesn't exist yet, the PDF shows a framed placeholder with the caption and path instead of failing. Figures stay exactly where they appear in the Markdown; set `figure-placement: htbp` in `report/defaults.yaml` to let LaTeX float them to the top or bottom of a page instead.
- Tables: pipe tables. A `Table: Caption` line above (or below) a table, separated from it by a blank line, gives it a numbered caption. Without the blank line the table is read as part of the caption and isn't rendered. The number of dashes in each column of the separator row sets the relative column widths, e.g. `| ---- | ------------ |` for 1:3.
- Title page: edit the YAML in `00-title-page.md`. Don't use `<angle brackets>` in values: Markdown treats them as HTML and drops them.

## Requirements

Needs [pandoc](https://pandoc.org) 3.x and a TeX distribution with XeLaTeX and latexmk (TeX Live or MiKTeX).

## Building locally

```bash
bash scripts/build-report.sh markdown
```

This writes `markdown/outputs/report.tex` and `markdown/outputs/report.pdf`. Set `REPORT_NAME=final` to name them `final.tex` and `final.pdf`.

## Previewing the report

The preview script builds the report into your Documents folder instead of the repository, so nothing can be committed by mistake. It needs the same tools as a local build. Without arguments it builds the whole report, the same as CI:

```bash
# macOS, Linux, Windows Git Bash
bash scripts/preview.sh
```

```powershell
# Windows PowerShell or PowerShell 7
.\scripts\preview.ps1
```

To check only some chapters, add their numbers as they appear in the PDF, e.g. `bash scripts/preview.sh 2 5` or `.\scripts\preview.ps1 2 5`.

- Chapters: `2`, `2 5`, `2-4`; appendices as letters, `A` or `A-B`; `all` for the whole report (the default). Skipped chapters still count, so chapter 5 stays "Chapter 5" and keeps its figure and table numbers.
- When previewing chapters, the bibliography is included so citations still link. Leave it out with `--no-bib` (`-NoBib`).
- Chapter previews have no title page or contents. Add them with `--title` / `--toc` (`-Title` / `-Toc`). The whole-report preview always has both.
- The PDF is saved as `preview-all.pdf` or `preview-<chapters>.pdf` in `Documents/md-to-tex-report-previews/<repo name>/` and opened. Nothing is written to the repository: intermediate files go to a temporary folder that is deleted afterwards. Use `--out DIR` (`-Out DIR`) for another folder, and `--no-open` (`-NoOpen`) to skip opening it.
- Other report directory: `--dir DIR` (`-Dir DIR`).
- If PowerShell refuses to run the script, use `powershell -ExecutionPolicy Bypass -File scripts\preview.ps1`.

## GitHub Actions

`.github/workflows/build-report.yml` runs:

- on every push to `main` that changes the report sources,
- on every pull request into `main` that changes them,
- manually from the Actions tab (**Run workflow**), where you can type which report directories to build.

Every run uploads `report.tex` and `report.pdf` as an artifact named `report-<commit sha>`. On pushes to `main` it also commits `<dir>/outputs/` back to the branch. To turn that off, set `COMMIT_OUTPUTS: "false"`. If `main` is a protected branch that blocks pushes from Actions, turn it off or allow the `github-actions[bot]` to push.

To build other report directories on push, change `REPORT_DIRS` (space-separated) and add the directories to the `paths` filters.

## Getting template updates

A repository created with **Use this template** doesn't share history with the template, so template updates don't reach it on their own. `.github/workflows/template-sync.yml` does this for you, using [actions-template-sync](https://github.com/AndreasAugustin/actions-template-sync):

- Every Monday, or when you run it from the Actions tab, it checks the template for changes and opens a pull request with them. Nothing is merged until you merge the pull request.
- It never touches the paths listed in `.templatesyncignore`. By default that's `markdown/`, your report content. Uncomment `README.md` there to keep your own README too. If you rename `markdown/`, update this file as well.
- It does nothing in the template repository itself.
- The default token can't change files under `.github/workflows/`, so a sync that updates a workflow will fail. To receive those updates, create a personal access token (classic with the `workflow` scope, or fine-grained with contents, pull requests and workflows set to write) and save it as the repository secret `TEMPLATE_SYNC_PAT`.
- If Actions can't create pull requests in your repository, enable **Settings → Actions → General → Allow GitHub Actions to create and approve pull requests**.

## Customising

- Page layout, fonts, link colours, numbering depth: `variables` in `report/defaults.yaml`, or a `report.yaml` in the report directory for one report only.
- Title page and preamble: `report/template.tex`. It is pandoc's default LaTeX template with a custom title page, roman page numbers for the front matter, and running heads.
- Chinese text: add `CJKmainfont: Noto Serif CJK SC` (or another installed CJK font) under `variables`. On CI, also install `fonts-noto-cjk` in `scripts/install-deps-ubuntu.sh`.
