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
- Appendix: `# Meeting Minutes {.appendix}` becomes "Appendix A", and every later chapter is lettered too.
- Figures: `![Caption](figures/name.png)`. Paths are relative to the report directory. If the file doesn't exist yet, the PDF shows a framed placeholder with the caption and path instead of failing. Figures stay exactly where they appear in the Markdown; set `figure-placement: htbp` in `report/defaults.yaml` to let LaTeX float them to the top or bottom of a page instead.
- Tables: pipe tables. A `Table: Caption` line directly above a table gives it a numbered caption.
- Title page: edit the YAML in `00-title-page.md`. Don't use `<angle brackets>` in values: Markdown treats them as HTML and drops them.

## Building locally

Needs [pandoc](https://pandoc.org) 3.x and a TeX distribution with XeLaTeX and latexmk (TeX Live or MiKTeX).

```bash
bash scripts/build-report.sh markdown
```

This writes `markdown/outputs/report.tex` and `markdown/outputs/report.pdf`. Set `REPORT_NAME=final` to name them `final.tex` and `final.pdf`.

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
