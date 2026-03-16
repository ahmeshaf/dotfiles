#!/usr/bin/env bash
set -euo pipefail

echo "==> Academic research tools setup"

# --- Homebrew check ---
if ! command -v brew &>/dev/null; then
  echo "Error: Homebrew not found. Run mac.sh first."
  exit 1
fi

# --- Brew formulae ---
BREW_PACKAGES=(
  # LaTeX
  mactex        # full TeX distribution (pdflatex, bibtex, tlmgr, etc.)
  latexmk       # auto-build LaTeX docs (handles re-runs for refs/bibtex)

  # Document conversion
  pandoc        # convert between formats (md → pdf, latex → docx, etc.)
  pandoc-crossref # cross-references for pandoc (figures, tables, equations)

  # PDF tools
  poppler       # PDF utilities (pdftotext, pdfinfo, pdfunite, pdfseparate)

  # Figures & media
  imagemagick   # image conversion and manipulation (convert, mogrify)
  gnuplot       # plotting from terminal/scripts
  ffmpeg        # video/audio processing (for multimedia research)
)

echo "==> Installing brew formulae..."
INSTALLED=$(brew list --formula -1)

for pkg in "${BREW_PACKAGES[@]}"; do
  if echo "$INSTALLED" | grep -qx "$pkg"; then
    echo "  $pkg already installed, skipping."
  else
    echo "  Installing $pkg..."
    brew install "$pkg" 2>/dev/null || true
  fi
done

# --- Brew casks ---
CASK_PACKAGES=(
  zotero        # reference manager (integrates with Word, LibreOffice, Google Docs)
  skim          # lightweight PDF viewer with LaTeX sync (SyncTeX support)
)

echo "==> Installing cask apps..."
INSTALLED_CASKS=$(brew list --cask -1)

for pkg in "${CASK_PACKAGES[@]}"; do
  if echo "$INSTALLED_CASKS" | grep -qx "$pkg"; then
    echo "  $pkg already installed, skipping."
  else
    echo "  Installing $pkg..."
    brew install --cask "$pkg" 2>/dev/null || true
  fi
done

# --- Pip packages ---
echo "==> Installing pip packages..."
pip install --quiet arxiv-dl --break-system-packages 2>/dev/null || pip3 install --quiet arxiv-dl --break-system-packages 2>/dev/null || true

# Set default download directory for arxiv-dl
mkdir -p "$HOME/.arxiv"
export ARXIV_DL_DIR="$HOME/.arxiv"

# --- paper-init function ---
echo "==> Installing paper-init command..."

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PAPER_INIT_DIR="$DOTFILES_DIR/templates/paper"
mkdir -p "$PAPER_INIT_DIR"

# Style file: clean, minimal style for proposals and lit reviews
cat > "$PAPER_INIT_DIR/quickpaper.sty" << 'STY'
\NeedsTeXFormat{LaTeX2e}
\ProvidesPackage{quickpaper}[Quick paper style for proposals and lit reviews]

% --- Page layout ---
\RequirePackage[margin=1in]{geometry}
\RequirePackage{setspace}
\onehalfspacing

% --- Typography ---
\RequirePackage[T1]{fontenc}
\RequirePackage{lmodern}
\RequirePackage{microtype}

% --- Math ---
\RequirePackage{amsmath,amssymb,amsthm}

% --- Figures & tables ---
\RequirePackage{graphicx}
\RequirePackage{booktabs}
\RequirePackage{caption}
\captionsetup{font=small,labelfont=bf}

% --- References & links ---
\RequirePackage[colorlinks=true,linkcolor=blue!70!black,citecolor=green!50!black,urlcolor=blue!70!black]{hyperref}
\RequirePackage[numbers,sort&compress]{natbib}

% --- Section formatting ---
\RequirePackage{titlesec}
\titleformat{\section}{\large\bfseries}{\thesection.}{0.5em}{}
\titleformat{\subsection}{\normalsize\bfseries}{\thesubsection.}{0.5em}{}

% --- Useful shortcuts ---
\newcommand{\eg}{e.g.\@\xspace}
\newcommand{\ie}{i.e.\@\xspace}
\newcommand{\etal}{et~al.\@\xspace}
\newcommand{\cf}{cf.\@\xspace}
\RequirePackage{xspace}

% --- Theorem environments ---
\newtheorem{theorem}{Theorem}
\newtheorem{lemma}[theorem]{Lemma}
\newtheorem{proposition}[theorem]{Proposition}
\newtheorem{definition}[theorem]{Definition}

% --- Todo notes (remove for final) ---
\RequirePackage[textsize=small,color=yellow!30]{todonotes}
\newcommand{\TODO}[1]{\todo[inline]{#1}}
STY

# Main tex template
cat > "$PAPER_INIT_DIR/main.tex" << 'TEX'
\documentclass[11pt]{article}
\usepackage{quickpaper}

\title{TITLE}
\author{AUTHOR}
\date{\today}

\begin{document}
\maketitle

\begin{abstract}
Your abstract here.
\end{abstract}

\section{Introduction}
\label{sec:intro}

\section{Related Work}
\label{sec:related}

\section{Method}
\label{sec:method}

\section{Experiments}
\label{sec:experiments}

\section{Conclusion}
\label{sec:conclusion}

\bibliographystyle{plainnat}
\bibliography{references}

\end{document}
TEX

# Bib file with example entry
cat > "$PAPER_INIT_DIR/references.bib" << 'BIB'
@article{example2024,
  author  = {Last, First and Other, Author},
  title   = {Example Paper Title},
  journal = {arXiv preprint arXiv:2401.00000},
  year    = {2024},
}
BIB

# Latexmk config
cat > "$PAPER_INIT_DIR/.latexmkrc" << 'LATEXMKRC'
$pdf_mode = 1;
$pdflatex = 'pdflatex -interaction=nonstopmode -synctex=1 %O %S';
$bibtex_use = 2;
$clean_ext = 'synctex.gz run.xml tex.bak bbl blg';
LATEXMKRC

# paper-init shell function
PAPER_INIT_FUNC='
# Initialize a new paper from template
paper-init() {
  local dir="${1:-.}"
  local template_dir="TEMPLATE_DIR"
  if [ ! -d "$template_dir" ]; then
    echo "Error: Template not found at $template_dir. Run research_mac.sh first."
    return 1
  fi
  mkdir -p "$dir"
  cp "$template_dir/quickpaper.sty" "$dir/"
  cp "$template_dir/main.tex" "$dir/"
  cp "$template_dir/references.bib" "$dir/"
  cp "$template_dir/.latexmkrc" "$dir/"
  mkdir -p "$dir/figures"
  echo "Paper initialized in $dir/"
  echo "  cd $dir && latexmk    # build PDF"
}
'
PAPER_INIT_FUNC="${PAPER_INIT_FUNC//TEMPLATE_DIR/$PAPER_INIT_DIR}"

# Add to profile if not already present
PROFILE_SOURCE="$DOTFILES_DIR/profile.sh"
if ! grep -qF "paper-init" "$PROFILE_SOURCE" 2>/dev/null; then
  echo "$PAPER_INIT_FUNC" >> "$PROFILE_SOURCE"
  echo "  paper-init added to profile."
else
  echo "  paper-init already in profile."
fi

echo ""
echo "==> Done! Research tools installed."
echo ""
echo "Quick start:"
echo "  latexmk -pdf paper.tex        # build LaTeX to PDF"
echo "  pandoc paper.md -o paper.pdf   # markdown to PDF"
echo "  pdftotext paper.pdf            # extract text from PDF"
echo "  paper 2301.07041               # download arxiv paper by ID"
