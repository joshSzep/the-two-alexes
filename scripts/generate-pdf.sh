#!/bin/bash

# Generate a print-ready PDF from the manuscript.
# Run from the repository root: ./scripts/generate-pdf.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANUSCRIPT="$REPO_ROOT/MANUSCRIPT.md"
COVER_IMAGE="$REPO_ROOT/cover.png"
OUTPUT_PDF="$REPO_ROOT/The Two Alexes.pdf"
TEMP_DIR="$(mktemp -d)"
WORKING_MANUSCRIPT="$TEMP_DIR/manuscript-for-pdf.md"
HEADER_FILE="$TEMP_DIR/pandoc-header.tex"

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Error: Required command not found: $command_name" >&2
        exit 1
    fi
}

require_file() {
    local file_path="$1"
    local description="$2"

    if [[ ! -f "$file_path" ]]; then
        echo "Error: Missing $description at $file_path" >&2
        exit 1
    fi
}

require_command pandoc
require_command pdflatex
require_file "$COVER_IMAGE" "cover image"

bash "$SCRIPT_DIR/generate-manuscript.sh"
require_file "$MANUSCRIPT" "manuscript"

if ! grep -q '^## ACT ' "$MANUSCRIPT"; then
    echo "Error: $MANUSCRIPT does not contain any act headings." >&2
    exit 1
fi

cat > "$HEADER_FILE" <<'EOF'
\usepackage[T1]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage{mathpazo}
\usepackage[paperwidth=6in,paperheight=9in,inner=0.85in,outer=0.70in,top=0.90in,bottom=0.85in,includeheadfoot,headsep=16pt]{geometry}
\usepackage{graphicx}
\usepackage{setspace}
\usepackage{fancyhdr}
\usepackage{emptypage}
\usepackage{xcolor}
\usepackage{hyperref}

\definecolor{ActColor}{HTML}{A34A12}

\hypersetup{
    pdftitle={The Two Alexes},
    pdfauthor={Joshua Szepietowski}
}

\setlength{\parindent}{1.25em}
\setlength{\parskip}{0pt}
\setstretch{1.08}
\clubpenalty=10000
\widowpenalty=10000
\displaywidowpenalty=10000
\emergencystretch=2em

\pagestyle{fancy}
\fancyhf{}
\fancyhead[C]{\small\itshape\nouppercase{\leftmark}}
\fancyfoot[C]{\thepage}
\renewcommand{\headrulewidth}{0pt}
\renewcommand{\footrulewidth}{0pt}

\fancypagestyle{plain}{
  \fancyhf{}
    \fancyhead[C]{\small\itshape\nouppercase{\leftmark}}
  \fancyfoot[C]{\thepage}
  \renewcommand{\headrulewidth}{0pt}
  \renewcommand{\footrulewidth}{0pt}
}
EOF

cat > "$WORKING_MANUSCRIPT" <<EOF
\\begin{titlepage}
\\newgeometry{margin=0in}
\\thispagestyle{empty}
\\noindent\\includegraphics[width=\\paperwidth,height=\\paperheight]{${COVER_IMAGE}}
\\end{titlepage}
\\restoregeometry
\\clearpage
\\pagenumbering{arabic}
\\setcounter{page}{1}

EOF

awk '
BEGIN {
    started = 0
    act_count = 0
    chapter_count = 0
    after_act = 0
}

!started {
    if ($0 ~ /^## ACT /) {
        started = 1
    } else {
        next
    }
}

{
    if ($0 == "---") {
        next
    }

    if ($0 ~ /^## ACT /) {
        if (act_count > 0) {
            print ""
            print "\\clearpage"
            print ""
        }

        act_count++
        after_act = 1
        print $0
        next
    }

    if ($0 ~ /^### Chapter /) {
        if (chapter_count > 0 && !after_act) {
            print ""
            print "\\clearpage"
            print ""
        }

        chapter_count++
        after_act = 0
        chapter_title = $0
        sub(/^### /, "", chapter_title)
        print "\\markboth{" chapter_title "}{" chapter_title "}"
        print ""
        print $0
        next
    }

    print $0
}
' "$MANUSCRIPT" >> "$WORKING_MANUSCRIPT"

pandoc "$WORKING_MANUSCRIPT" \
    --standalone \
    --from markdown+raw_tex \
    --pdf-engine=pdflatex \
    --include-in-header="$HEADER_FILE" \
    --resource-path="$REPO_ROOT" \
    --metadata lang="en-US" \
    --variable documentclass=article \
    --variable fontsize=11pt \
    --output "$OUTPUT_PDF"

echo "Generated: $OUTPUT_PDF"
