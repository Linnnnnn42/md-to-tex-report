#!/usr/bin/env bash
# Build a PDF of selected chapters for a quick local preview.
# Works on macOS, Linux and Windows (Git Bash). On Windows PowerShell, use preview.ps1.
#
# The PDF goes to your Documents folder, never into the repository, and all
# intermediate files stay in a temporary folder.
#
# Usage: scripts/preview.sh [options] [CHAPTER...]
#
#   CHAPTER        chapter numbers as shown in the PDF: 2, "2 5", 2-4;
#                  appendices as letters: A, A-B;
#                  or "all" (the default) for the whole report as CI builds it
#                  (title page, contents, every chapter); --title, --toc and
#                  --no-bib don't apply then
#   -d, --dir DIR  report directory (default: markdown)
#   -o, --out DIR  output folder (default: <Documents>/md-to-tex-report-previews/<repo>)
#   --title        include the title page
#   --toc          include the table of contents
#   --no-bib       leave out the bibliography (citations then aren't links)
#   --no-open      don't open the PDF when done
#   -h, --help     show this help
#
# Examples: scripts/preview.sh 2 5       -> chapters 2 and 5 (plus bibliography)
#           scripts/preview.sh           -> the whole report (same as "all")

set -euo pipefail

usage() {
  sed -n '2,/^$/s/^# \{0,1\}//p' "${BASH_SOURCE[0]}"
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
report_dir="markdown"
out_dir=""
title=false
toc=false
bib=true
open_pdf=true
chapters=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dir) report_dir="$2"; shift 2 ;;
    -o|--out) out_dir="$2"; shift 2 ;;
    --title) title=true; shift ;;
    --toc) toc=true; shift ;;
    --no-bib) bib=false; shift ;;
    --no-open) open_pdf=false; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "error: unknown option $1 (see --help)" >&2; exit 2 ;;
    *) chapters+=("$1"); shift ;;
  esac
done

# No chapters given: preview the whole report.
if [[ ${#chapters[@]} -eq 0 ]]; then
  chapters=(all)
fi

for tool in pandoc latexmk xelatex; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: $tool not found. Install pandoc 3.x and a TeX distribution with XeLaTeX and latexmk." >&2
    exit 1
  fi
done

# Report directory: relative to the current folder, else to the repository.
if [[ ! -d "$report_dir" && -d "$repo_root/$report_dir" ]]; then
  report_dir="$repo_root/$report_dir"
fi
if [[ ! -d "$report_dir" ]]; then
  echo "error: report directory not found: $report_dir" >&2
  exit 1
fi
report_dir="$(cd "$report_dir" && pwd)"

# On Windows (Git Bash), native tools need Windows-style paths.
native_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1"
  else
    printf '%s\n' "$1"
  fi
}

documents_dir() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
      # Ask Windows, so a Documents folder moved to OneDrive is found too.
      local docs
      docs="$(powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('MyDocuments')" 2>/dev/null | tr -d '\r')"
      if [[ -n "$docs" ]]; then
        cygpath -u "$docs"
      else
        printf '%s\n' "$(cygpath -u "$USERPROFILE")/Documents"
      fi
      ;;
    Linux)
      if command -v xdg-user-dir >/dev/null 2>&1; then
        xdg-user-dir DOCUMENTS
      else
        printf '%s\n' "$HOME/Documents"
      fi
      ;;
    *) printf '%s\n' "$HOME/Documents" ;;
  esac
}

if [[ -z "$out_dir" ]]; then
  out_dir="$(documents_dir)/md-to-tex-report-previews/$(basename "$repo_root")"
fi
mkdir -p "$out_dir"
out_dir="$(cd "$out_dir" && pwd)"
case "$out_dir/" in
  "$repo_root"/*) echo "warning: output folder is inside the repository; don't commit the preview PDF" >&2 ;;
esac

selection="${chapters[*]}"
whole_report=false
if [[ "$(printf '%s' "$selection" | tr '[:upper:]' '[:lower:]')" == "all" ]]; then
  whole_report=true
elif printf '%s\n' "${chapters[@]}" | grep -qix 'all'; then
  echo "error: use \"all\" on its own, not together with chapter numbers" >&2
  exit 2
fi
safe_name="$(printf '%s' "$selection" | tr ' ,' '__' | tr -cd 'A-Za-z0-9_-')"
pdf_name="preview-${safe_name}.pdf"
if [[ "$whole_report" == true ]]; then
  pdf_name="preview-all.pdf"
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/report-preview.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT
work_native="$(native_path "$work_dir")"

cd "$report_dir"
shopt -s nullglob
files=([0-9]*.md)
shopt -u nullglob
if [[ ${#files[@]} -eq 0 ]]; then
  echo "error: no numbered Markdown files in $report_dir" >&2
  exit 1
fi
mapfile -t files < <(printf '%s\n' "${files[@]}" | LC_ALL=C sort)

defaults=(--defaults "$(native_path "$repo_root/report/defaults.yaml")")
if [[ -f report.yaml ]]; then
  defaults+=(--defaults report.yaml)
fi

if [[ "$whole_report" == true ]]; then
  # Same settings as the CI build: no chapter selection.
  echo "==> Previewing the whole report from $report_dir"
  preview_args=()
else
  echo "==> Previewing chapter(s) $selection from $report_dir"
  preview_args=(
    --table-of-contents="$toc"
    -M "preview-chapters=$selection"
    -M "preview-bibliography=$bib"
    -M "preview-title=$title"
  )
fi
if ! pandoc "${defaults[@]}" "${files[@]}" ${preview_args[@]+"${preview_args[@]}"} \
  -o "$work_native/preview.tex" 2>"$work_dir/pandoc.err"; then
  # Show a selection mistake as one line instead of a Lua stack trace.
  message="$(grep -o 'preview: .*' "$work_dir/pandoc.err" | head -n 1 || true)"
  if [[ -n "$message" ]]; then
    echo "error: ${message#preview: }" >&2
  else
    cat "$work_dir/pandoc.err" >&2
  fi
  exit 1
fi
# Pass on warnings such as missing images.
cat "$work_dir/pandoc.err" >&2

if ! latexmk -xelatex -interaction=nonstopmode -halt-on-error -file-line-error \
  -outdir="$work_native" "$work_native/preview.tex" >"$work_dir/latexmk.out" 2>&1; then
  echo "error: LaTeX failed. Last lines of the log:" >&2
  tail -n 25 "$work_dir/latexmk.out" >&2
  exit 1
fi

cp "$work_dir/preview.pdf" "$out_dir/$pdf_name"
echo "==> Wrote $out_dir/$pdf_name"

if [[ "$open_pdf" == true ]]; then
  case "$(uname -s)" in
    Darwin) open "$out_dir/$pdf_name" ;;
    MINGW*|MSYS*|CYGWIN*) cmd.exe //c start "" "$(cygpath -w "$out_dir/$pdf_name")" ;;
    *) command -v xdg-open >/dev/null 2>&1 && xdg-open "$out_dir/$pdf_name" >/dev/null 2>&1 & ;;
  esac
fi
