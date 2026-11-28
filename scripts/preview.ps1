<#
.SYNOPSIS
  Build a PDF of selected chapters for a quick local preview.

.DESCRIPTION
  For Windows PowerShell 5.1 and PowerShell 7 (also on macOS). On macOS or
  Git Bash you can use preview.sh instead.

  The PDF goes to your Documents folder, never into the repository, and all
  intermediate files stay in a temporary folder.

.PARAMETER Chapters
  Chapter numbers as shown in the PDF: 2, "2 5", 2-4; appendices as letters: A, A-B.
  Or "all" (the default) for the whole report as CI builds it (title page,
  contents, every chapter); -Title, -Toc and -NoBib don't apply then.

.PARAMETER Dir
  Report directory (default: markdown).

.PARAMETER Out
  Output folder (default: <Documents>\md-to-tex-report-previews\<repo>).

.PARAMETER Title
  Include the title page.

.PARAMETER Toc
  Include the table of contents.

.PARAMETER NoBib
  Leave out the bibliography (citations then aren't links).

.PARAMETER NoOpen
  Don't open the PDF when done.

.EXAMPLE
  .\scripts\preview.ps1 2 5
  Chapters 2 and 5, plus the bibliography.

.EXAMPLE
  .\scripts\preview.ps1
  The whole report (same as "all").

.EXAMPLE
  .\scripts\preview.ps1 A -NoBib
  Appendix A only.
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
  [string[]] $Chapters = @("all"),
  [string] $Dir = "markdown",
  [string] $Out = "",
  [switch] $Title,
  [switch] $Toc,
  [switch] $NoBib,
  [switch] $NoOpen
)

Set-StrictMode -Version 2.0
$onWindows = $env:OS -eq "Windows_NT"

function Stop-WithError([string] $message) {
  Write-Host "error: $message" -ForegroundColor Red
  exit 1
}

foreach ($tool in "pandoc", "latexmk", "xelatex") {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    Stop-WithError "$tool not found. Install pandoc 3.x and a TeX distribution with XeLaTeX and latexmk."
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

# Report directory: relative to the current folder, else to the repository.
if (-not (Test-Path $Dir -PathType Container) -and (Test-Path (Join-Path $repoRoot $Dir) -PathType Container)) {
  $Dir = Join-Path $repoRoot $Dir
}
if (-not (Test-Path $Dir -PathType Container)) {
  Stop-WithError "report directory not found: $Dir"
}
$reportDir = (Resolve-Path $Dir).Path

if (-not $Out) {
  if ($onWindows) {
    # Follows a Documents folder that was moved, e.g. to OneDrive.
    $documents = [Environment]::GetFolderPath("MyDocuments")
  } else {
    $documents = Join-Path $HOME "Documents"
  }
  $Out = Join-Path (Join-Path $documents "md-to-tex-report-previews") (Split-Path $repoRoot -Leaf)
}
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$outDir = (Resolve-Path $Out).Path
if (($outDir + [IO.Path]::DirectorySeparatorChar).StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  Write-Warning "output folder is inside the repository; don't commit the preview PDF"
}

$selection = ($Chapters -join " ").Trim()
$wholeReport = $selection -ieq "all"
if (-not $wholeReport -and @($Chapters | Where-Object { $_ -ieq "all" }).Count -gt 0) {
  Stop-WithError 'use "all" on its own, not together with chapter numbers'
}
if ($wholeReport) {
  $pdfName = "preview-all.pdf"
} else {
  $safeName = (($selection -replace "[\s,]+", "_") -replace "[^A-Za-z0-9_-]", "")
  $pdfName = "preview-$safeName.pdf"
}

$files = @(Get-ChildItem -Path $reportDir -Filter "*.md" -File |
  Where-Object { $_.Name -match "^[0-9]" } |
  Sort-Object Name |
  ForEach-Object { $_.Name })
if ($files.Count -eq 0) {
  Stop-WithError "no numbered Markdown files in $reportDir"
}

$workDir = Join-Path ([IO.Path]::GetTempPath()) ("report-preview-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $workDir | Out-Null
$texFile = Join-Path $workDir "preview.tex"

Push-Location $reportDir
try {
  $pandocArgs = @("--defaults", (Join-Path $repoRoot "report/defaults.yaml"))
  if (Test-Path "report.yaml") { $pandocArgs += @("--defaults", "report.yaml") }
  $pandocArgs += $files
  if ($wholeReport) {
    # Same settings as the CI build: no chapter selection.
    Write-Host "==> Previewing the whole report from $reportDir"
  } else {
    $pandocArgs += @(
      "--table-of-contents=$($Toc.IsPresent.ToString().ToLower())",
      "-M", "preview-chapters=$selection",
      "-M", "preview-bibliography=$((-not $NoBib.IsPresent).ToString().ToLower())",
      "-M", "preview-title=$($Title.IsPresent.ToString().ToLower())"
    )
    Write-Host "==> Previewing chapter(s) $selection from $reportDir"
  }
  $pandocArgs += @("-o", $texFile)
  # Collect stderr as text; native stderr must not turn into terminating errors.
  $ErrorActionPreference = "Continue"
  $pandocOutput = @(& pandoc @pandocArgs 2>&1 | ForEach-Object { "$_" })
  if ($LASTEXITCODE -ne 0) {
    # Show a selection mistake as one line instead of a Lua stack trace.
    $message = $pandocOutput | Select-String -Pattern "preview: (.*)" | Select-Object -First 1
    if ($message) {
      Stop-WithError $message.Matches[0].Groups[1].Value
    }
    $pandocOutput | ForEach-Object { Write-Host $_ }
    Stop-WithError "pandoc failed"
  }
  # Pass on warnings such as missing images.
  $pandocOutput | Where-Object { $_ } | ForEach-Object { Write-Host $_ }

  $latexOutput = @(& latexmk -xelatex -interaction=nonstopmode -halt-on-error -file-line-error "-outdir=$workDir" $texFile 2>&1 | ForEach-Object { "$_" })
  if ($LASTEXITCODE -ne 0) {
    Write-Host "error: LaTeX failed. Last lines of the log:" -ForegroundColor Red
    $latexOutput | Select-Object -Last 25 | ForEach-Object { Write-Host $_ }
    exit 1
  }

  $pdfPath = Join-Path $outDir $pdfName
  Copy-Item (Join-Path $workDir "preview.pdf") $pdfPath -Force
  Write-Host "==> Wrote $pdfPath"

  if (-not $NoOpen) {
    if ($onWindows) {
      Invoke-Item $pdfPath
    } elseif (Get-Command open -ErrorAction SilentlyContinue) {
      & open $pdfPath
    } elseif (Get-Command xdg-open -ErrorAction SilentlyContinue) {
      & xdg-open $pdfPath
    }
  }
}
finally {
  Pop-Location
  Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
}
