#!/usr/bin/env bash
# Install the build toolchain on Ubuntu (GitHub Actions runner or an ubuntu Docker image):
# a pinned pandoc release plus XeLaTeX, latexmk and the LaTeX packages pandoc's template uses.
#
# Env: PANDOC_VERSION  pandoc release to install (default below)

set -euo pipefail

PANDOC_VERSION="${PANDOC_VERSION:-3.11}"

SUDO=""
if [[ $(id -u) -ne 0 ]]; then
  SUDO="sudo"
fi

export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq --no-install-recommends \
  ca-certificates curl \
  latexmk lmodern \
  texlive-xetex texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended

arch="$(dpkg --print-architecture)"
deb="pandoc-${PANDOC_VERSION}-1-${arch}.deb"
curl -fsSL -o "/tmp/$deb" "https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/${deb}"
$SUDO apt-get install -y -qq "/tmp/$deb"
rm -f "/tmp/$deb"

pandoc --version | head -1
xelatex --version | head -1
