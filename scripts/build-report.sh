#!/usr/bin/env bash
# Build one report directory: merge its numbered Markdown chapters into LaTeX, then compile the PDF.
#
# Usage: scripts/build-report.sh [report-dir]   (default: markdown)
#
# Inputs : <report-dir>/NN-*.md, merged in file-name order (00-title-page.md, 01-introduction.md, ...)
#          <report-dir>/report.yaml (optional) overrides settings from report/defaults.yaml
# Outputs: <report-dir>/outputs/report.tex and <report-dir>/outputs/report.pdf
# Env    : REPORT_NAME  base name of the outputs (default: report)

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
report_dir="${1:-markdown}"
report_name="${REPORT_NAME:-report}"

if [[ ! -d "$report_dir" ]]; then
  echo "error: report directory not found: $report_dir" >&2
  exit 1
fi
report_dir="$(cd "$report_dir" && pwd)"
out_dir="$report_dir/outputs"

# Image paths in the Markdown are relative to the report directory, so build from there.
cd "$report_dir"

shopt -s nullglob
chapters=([0-9]*.md)
shopt -u nullglob
if [[ ${#chapters[@]} -eq 0 ]]; then
  echo "error: no numbered Markdown files (e.g. 01-introduction.md) in $report_dir" >&2
  exit 1
fi
mapfile -t chapters < <(printf '%s\n' "${chapters[@]}" | LC_ALL=C sort)

defaults=(--defaults "$repo_root/report/defaults.yaml")
if [[ -f report.yaml ]]; then
  defaults+=(--defaults report.yaml)
fi

mkdir -p "$out_dir"
echo "==> Markdown -> LaTeX: ${chapters[*]}"
pandoc "${defaults[@]}" "${chapters[@]}" -o "outputs/$report_name.tex"

echo "==> LaTeX -> PDF"
latexmk -xelatex -interaction=nonstopmode -halt-on-error -file-line-error \
  -outdir=outputs "outputs/$report_name.tex"
# Keep only the .tex and .pdf; the log stays around when compilation fails (set -e stops before this).
latexmk -c -outdir=outputs "outputs/$report_name.tex" >/dev/null
rm -f "outputs/$report_name.xdv"

echo "==> Done: $out_dir/$report_name.tex, $out_dir/$report_name.pdf"
