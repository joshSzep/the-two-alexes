#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEBSITE_DIR="$REPO_ROOT/website"
INDEX_FILE="$WEBSITE_DIR/index.html"
TEMP_DIR="$(mktemp -d)"
CHAPTER_HTML="$TEMP_DIR/chapter.html"
CHAPTER_SOURCE="$(find "$REPO_ROOT/chapters" -type f \( -name '001.md' -o -name '01.md' \) | LC_ALL=C sort | head -n 1)"

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

require_file() {
    local file_path="$1"
    local description="$2"

    if [[ ! -f "$file_path" ]]; then
        echo "Error: Missing $description at $file_path" >&2
        exit 1
    fi
}

render_chapter_html() {
    local source_file="$1"

    awk '
function trim(text) {
    sub(/^[[:space:]]+/, "", text)
    sub(/[[:space:]]+$/, "", text)
    return text
}

function escape_html(text) {
    gsub(/&/, "\\&amp;", text)
    gsub(/</, "\\&lt;", text)
    gsub(/>/, "\\&gt;", text)
    return text
}

function flush_paragraph(    text) {
    text = trim(paragraph)
    if (text != "") {
        print "        <p>" escape_html(text) "</p>"
    }
    paragraph = ""
}

{
    sub(/\r$/, "", $0)

    if ($0 ~ /^---[[:space:]]*$/) {
        flush_paragraph()
        next
    }

    if ($0 ~ /^# /) {
        flush_paragraph()
        heading = $0
        sub(/^# /, "", heading)
        print "        <h2>" escape_html(trim(heading)) "</h2>"
        next
    }

    if ($0 ~ /^## /) {
        flush_paragraph()
        heading = $0
        sub(/^## /, "", heading)
        print "        <h3>" escape_html(trim(heading)) "</h3>"
        next
    }

    if ($0 ~ /^[[:space:]]*$/) {
        flush_paragraph()
        next
    }

    line = trim($0)
    if (paragraph == "") {
        paragraph = line
    } else {
        paragraph = paragraph " " line
    }
}

END {
    flush_paragraph()
}
' "$source_file"
}

require_file "$REPO_ROOT/cover.png" "cover image"

if [[ -z "$CHAPTER_SOURCE" ]]; then
    echo "Error: Could not find the first chapter source file." >&2
    exit 1
fi

require_file "$CHAPTER_SOURCE" "first chapter"

rm -rf "$WEBSITE_DIR"
mkdir -p "$WEBSITE_DIR"

cp "$REPO_ROOT/cover.png" "$WEBSITE_DIR/cover.png"

if [[ -x "$SCRIPT_DIR/generate-pdf.sh" ]]; then
    (
        cd "$SCRIPT_DIR"
        ./generate-pdf.sh
    )
else
    (
        cd "$SCRIPT_DIR"
        bash ./generate-pdf.sh
    )
fi

if [[ -x "$SCRIPT_DIR/generate-epub.sh" ]]; then
    (
        cd "$SCRIPT_DIR"
        ./generate-epub.sh
    )
else
    (
        cd "$SCRIPT_DIR"
        bash ./generate-epub.sh
    )
fi

require_file "$REPO_ROOT/The Two Alexes.pdf" "generated PDF"
require_file "$REPO_ROOT/The Two Alexes.epub" "generated EPUB"
cp "$REPO_ROOT/The Two Alexes.pdf" "$WEBSITE_DIR/The Two Alexes.pdf"
cp "$REPO_ROOT/The Two Alexes.epub" "$WEBSITE_DIR/The Two Alexes.epub"

render_chapter_html "$CHAPTER_SOURCE" > "$CHAPTER_HTML"

cat > "$INDEX_FILE" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>The Two Alexes</title>
    <meta name="description" content="A literary hard science fiction novel by Joshua Szepietowski.">
    <meta name="author" content="Joshua Szepietowski">
    <meta name="color-scheme" content="dark">
    <style>
        :root {
            --bg: #040404;
            --bg-deep: #080302;
            --panel: rgba(10, 7, 6, 0.7);
            --panel-strong: rgba(13, 9, 7, 0.84);
            --line: rgba(255, 184, 112, 0.18);
            --line-strong: rgba(255, 204, 153, 0.28);
            --text: #f7e9d7;
            --muted: #cfb59a;
            --soft: #8f7b6b;
            --accent: #ff8f2e;
            --accent-bright: #ffd08a;
            --danger: #ff5c1a;
            --shadow: rgba(0, 0, 0, 0.46);
            --content-width: 48rem;
            --ui-font: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            --book-font: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Palatino, Georgia, serif;
        }

        * {
            box-sizing: border-box;
        }

        html {
            scroll-behavior: smooth;
        }

        body {
            margin: 0;
            min-height: 100vh;
            font-family: var(--ui-font);
            color: var(--text);
            background:
                radial-gradient(circle at 50% -5%, rgba(255, 134, 37, 0.14), transparent 28%),
                linear-gradient(180deg, #170904 0%, #080606 32%, #040404 70%, #020202 100%);
            letter-spacing: 0.01em;
        }

        body::before,
        body::after {
            content: "";
            position: fixed;
            inset: 0;
            pointer-events: none;
            z-index: 1;
        }

        body::before {
            background:
                linear-gradient(90deg, rgba(255, 255, 255, 0.03) 0, rgba(255, 255, 255, 0.03) 1px, transparent 1px, transparent calc(50% - 1px), rgba(255, 255, 255, 0.03) calc(50% - 1px), rgba(255, 255, 255, 0.03) 50%, transparent 50%, transparent 100%),
                linear-gradient(180deg, rgba(255, 209, 154, 0.07), transparent 18%, transparent 82%, rgba(255, 209, 154, 0.04));
            opacity: 0.16;
            mix-blend-mode: screen;
        }

        body::after {
            background: radial-gradient(circle at 50% 18%, rgba(255, 171, 98, 0.18), transparent 24%);
            opacity: 0.42;
        }

        a {
            color: inherit;
        }

        img {
            display: block;
            max-width: 100%;
        }

        .star-canvas {
            position: fixed;
            inset: 0;
            width: 100%;
            height: 100%;
            z-index: 0;
            display: block;
            opacity: 0.98;
        }

        .page {
            position: relative;
            z-index: 2;
            overflow: clip;
        }

        .page::before,
        .page::after {
            content: "";
            position: absolute;
            pointer-events: none;
            filter: blur(40px);
        }

        .page::before {
            top: 12rem;
            right: -12rem;
            width: 32rem;
            height: 32rem;
            background: radial-gradient(circle, rgba(255, 128, 40, 0.18), transparent 72%);
        }

        .page::after {
            top: 62rem;
            left: -14rem;
            width: 36rem;
            height: 36rem;
            background: radial-gradient(circle, rgba(255, 191, 123, 0.14), transparent 72%);
        }

        .section {
            position: relative;
            width: min(100%, 82rem);
            margin: 0 auto;
            padding: 0 1.5rem;
        }

        .masthead {
            position: fixed;
            top: 1rem;
            left: 50%;
            transform: translateX(-50%);
            width: min(calc(100% - 2rem), 74rem);
            z-index: 5;
        }

        .masthead-inner {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 1rem;
            padding: 0.8rem 1rem;
            border: 1px solid rgba(255, 207, 156, 0.18);
            border-radius: 999px;
            background: linear-gradient(180deg, rgba(18, 13, 11, 0.84), rgba(12, 9, 8, 0.78));
            backdrop-filter: blur(16px);
            box-shadow: 0 18px 48px rgba(0, 0, 0, 0.28);
        }

        .masthead-title {
            color: #f7e7d5;
            text-decoration: none;
            font-size: 0.82rem;
            letter-spacing: 0.22em;
            text-transform: uppercase;
            white-space: nowrap;
        }

        .masthead-nav {
            display: flex;
            align-items: center;
            justify-content: flex-end;
            flex-wrap: wrap;
            gap: 0.5rem;
        }

        .masthead-nav a {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            min-height: 2.45rem;
            padding: 0.65rem 1rem;
            border-radius: 999px;
            color: var(--muted);
            text-decoration: none;
            font-size: 0.78rem;
            letter-spacing: 0.14em;
            text-transform: uppercase;
            transition: background-color 180ms ease, color 180ms ease, transform 180ms ease;
        }

        .masthead-nav a:hover,
        .masthead-nav a:focus-visible {
            color: #f7e7d5;
            background: rgba(255, 255, 255, 0.05);
            transform: translateY(-1px);
            outline: none;
        }

        .masthead-nav a.primary-link {
            color: #221106;
            background: linear-gradient(180deg, #ffd18d 0%, #ff9f42 66%, #ff7a1a 100%);
            box-shadow: 0 12px 26px rgba(0, 0, 0, 0.24);
        }

        .hero {
            min-height: 100vh;
            display: flex;
            align-items: center;
            padding-top: 6.5rem;
            padding-bottom: 4rem;
        }

        .hero::before {
            content: "";
            position: absolute;
            inset: 1.2rem 1.5rem auto;
            height: calc(100% - 2.4rem);
            border-top: 1px solid rgba(255, 207, 156, 0.14);
            border-bottom: 1px solid rgba(255, 207, 156, 0.08);
            border-radius: 2.4rem;
            background:
                linear-gradient(180deg, rgba(8, 6, 5, 0.18), rgba(8, 6, 5, 0.05)),
                linear-gradient(135deg, rgba(255, 165, 88, 0.05), transparent 42%);
            mask: linear-gradient(90deg, transparent 0, rgba(0, 0, 0, 1) 12%, rgba(0, 0, 0, 1) 88%, transparent 100%);
            z-index: -1;
        }

        .hero-grid {
            display: grid;
            grid-template-columns: minmax(0, 1.02fr) minmax(18rem, 0.98fr);
            gap: 1.8rem;
            align-items: center;
            width: 100%;
        }

        .eyebrow {
            margin: 0 0 1rem;
            font-size: 0.78rem;
            letter-spacing: 0.38em;
            text-transform: uppercase;
            color: var(--accent-bright);
        }

        h1 {
            margin: 0;
            max-width: 8ch;
            font-size: clamp(4.3rem, 11vw, 8.8rem);
            line-height: 0.86;
            font-weight: 600;
            letter-spacing: -0.03em;
            text-transform: uppercase;
            text-wrap: balance;
            text-shadow: 0 0 28px rgba(255, 153, 61, 0.12);
        }

        .author-line {
            margin: 1rem 0 0;
            font-size: 0.95rem;
            letter-spacing: 0.26em;
            text-transform: uppercase;
            color: var(--muted);
        }

        .hero-copy {
            max-width: 42rem;
            padding: 4.2rem 0 3rem;
            position: relative;
            z-index: 2;
        }

        .hero-copy .lede {
            width: min(100%, 34rem);
            margin: 2rem 0 0;
            font-size: clamp(1.15rem, 2vw, 1.42rem);
            line-height: 1.75;
            color: #f2e0ce;
        }

        .hero-copy .microcopy {
            width: min(100%, 30rem);
            margin: 1.25rem 0 0;
            font-size: 0.98rem;
            line-height: 1.72;
            color: var(--muted);
        }

        .hero-actions {
            display: flex;
            flex-wrap: wrap;
            gap: 0.85rem;
            margin-top: 2rem;
        }

        .hero-actions a {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            min-height: 3.25rem;
            padding: 0.9rem 1.35rem;
            border-radius: 999px;
            text-decoration: none;
            letter-spacing: 0.1em;
            text-transform: uppercase;
            font-size: 0.9rem;
            transition: transform 180ms ease, border-color 180ms ease, background-color 180ms ease, box-shadow 180ms ease;
        }

        .hero-actions .primary {
            color: #221106;
            background: linear-gradient(180deg, #ffd18d 0%, #ff9f42 66%, #ff7a1a 100%);
            box-shadow: 0 18px 42px rgba(0, 0, 0, 0.34), 0 0 30px rgba(255, 145, 55, 0.18);
        }

        .hero-actions .secondary {
            border: 1px solid rgba(255, 204, 153, 0.24);
            background: rgba(12, 9, 8, 0.34);
            backdrop-filter: blur(14px);
        }

        .hero-actions a:hover,
        .hero-actions a:focus-visible {
            transform: translateY(-2px);
            outline: none;
        }

        .hero-actions .secondary:hover,
        .hero-actions .secondary:focus-visible {
            border-color: rgba(255, 218, 181, 0.46);
            background: rgba(24, 18, 16, 0.42);
        }

        .hero-actions .primary:hover,
        .hero-actions .primary:focus-visible {
            box-shadow: 0 24px 52px rgba(0, 0, 0, 0.42), 0 0 34px rgba(255, 145, 55, 0.28);
        }

        .hero-visual {
            position: relative;
            padding: 1rem 0;
            min-height: 42rem;
        }

        .hero-visual::before {
            content: "";
            position: absolute;
            inset: 6% -12% 10%;
            border-radius: 50%;
            background: radial-gradient(circle, rgba(255, 146, 48, 0.18), rgba(255, 146, 48, 0.04) 34%, transparent 68%);
            filter: blur(14px);
            transform: translateX(6%) scale(1.05, 0.92);
        }

        .hero-visual::after {
            content: "";
            position: absolute;
            inset: 16% -2% 18% 18%;
            border-radius: 46% 54% 52% 48%;
            border: 1px solid rgba(255, 208, 154, 0.12);
            background: linear-gradient(180deg, rgba(15, 10, 8, 0.28), rgba(15, 10, 8, 0.02));
            transform: rotate(-10deg);
        }

        .cover-vessel {
            position: relative;
            margin: 2.5rem 0 0 auto;
            width: min(100%, 33rem);
            transform: rotate(-7deg) translateX(2rem);
        }

        .cover-vessel img {
            border-radius: 1.1rem;
            box-shadow: 0 40px 90px rgba(0, 0, 0, 0.52), 0 0 0 1px rgba(255, 238, 219, 0.08);
        }

        .visual-caption {
            position: absolute;
            left: -2.8rem;
            bottom: 2.2rem;
            width: 13rem;
            margin: 0;
            padding: 0.9rem 1rem;
            font-size: 0.88rem;
            letter-spacing: 0.14em;
            text-transform: uppercase;
            color: #f3ddc8;
            border: 1px solid rgba(255, 206, 156, 0.18);
            border-radius: 1rem;
            background: linear-gradient(180deg, rgba(20, 14, 11, 0.86), rgba(13, 10, 8, 0.78));
            backdrop-filter: blur(10px);
            box-shadow: 0 18px 44px rgba(0, 0, 0, 0.28);
        }

        .blurb {
            padding-top: 2rem;
            padding-bottom: 6.5rem;
        }

        .blurb-box {
            width: min(100%, 56rem);
            padding: 2.6rem 2rem;
            margin: 0 auto;
            border: 1px solid rgba(255, 198, 142, 0.14);
            border-radius: 2rem;
            background: linear-gradient(180deg, rgba(15, 11, 10, 0.72), rgba(15, 11, 10, 0.54));
            box-shadow: 0 26px 70px rgba(0, 0, 0, 0.24);
            backdrop-filter: blur(12px);
        }

        .section-label {
            margin: 0 0 1rem;
            font-size: 0.76rem;
            letter-spacing: 0.34em;
            text-transform: uppercase;
            color: var(--soft);
        }

        .blurb-copy {
            margin: 0;
            font-family: var(--book-font);
            font-size: clamp(1.36rem, 2vw, 1.82rem);
            line-height: 1.8;
            color: #f8ead9;
            text-align: center;
            text-wrap: balance;
        }

        .chapter {
            padding-top: 0;
            padding-bottom: 7rem;
        }

        .chapter-shell {
            position: relative;
            padding: 0.5rem 0 0;
            border-top: 1px solid var(--line);
        }

        .section-heading {
            margin: 0;
            max-width: 42rem;
            font-size: clamp(2.2rem, 4vw, 3.8rem);
            line-height: 1.04;
            font-weight: 500;
            letter-spacing: -0.03em;
            text-wrap: balance;
        }

        .section-note {
            margin: 1rem 0 0;
            max-width: 38rem;
            font-size: 1rem;
            line-height: 1.8;
            color: var(--muted);
        }

        .chapter-frame {
            position: relative;
            width: min(100%, 64rem);
            margin: 3rem auto 0;
            padding: 3.5rem clamp(1.2rem, 4vw, 3rem);
            border: 1px solid rgba(255, 201, 147, 0.14);
            border-radius: 2rem;
            background:
                linear-gradient(180deg, rgba(21, 15, 12, 0.93), rgba(14, 11, 10, 0.96)),
                radial-gradient(circle at top, rgba(255, 170, 91, 0.04), transparent 35%);
            box-shadow: 0 30px 80px rgba(0, 0, 0, 0.34);
        }

        .chapter-frame::before {
            content: "";
            position: absolute;
            top: 1.5rem;
            left: 1.5rem;
            right: 1.5rem;
            bottom: 1.5rem;
            border: 1px solid rgba(255, 220, 190, 0.05);
            border-radius: 1.35rem;
            pointer-events: none;
        }

        .chapter-content {
            position: relative;
            width: min(100%, var(--content-width));
            margin: 0 auto;
            font-family: var(--book-font);
            font-size: clamp(1.08rem, 1.5vw, 1.24rem);
            line-height: 2;
            color: #efe0cf;
        }

        .chapter-content h2,
        .chapter-content h3 {
            margin: 0 0 2rem;
            font-family: var(--ui-font);
            font-weight: 500;
            line-height: 1.12;
            letter-spacing: -0.02em;
            color: #fbefdf;
            text-wrap: balance;
        }

        .chapter-content h2 {
            font-size: clamp(2.1rem, 3.2vw, 3rem);
        }

        .chapter-content h3 {
            margin-top: 3rem;
            font-size: 1.4rem;
        }

        .chapter-content p {
            margin: 0 0 1.4rem;
            text-wrap: pretty;
        }

        .chapter-content p:first-of-type::first-letter {
            float: left;
            margin-right: 0.1rem;
            font-size: 4.2rem;
            line-height: 0.88;
            color: var(--accent-bright);
        }

        .download {
            padding-bottom: 7rem;
        }

        .download-panel {
            width: min(100%, 60rem);
            margin: 0 auto;
            padding: 2.8rem clamp(1.3rem, 4vw, 2.7rem);
            border: 1px solid rgba(255, 204, 153, 0.16);
            border-radius: 2rem;
            background: linear-gradient(180deg, rgba(14, 10, 8, 0.78), rgba(10, 8, 7, 0.88));
            box-shadow: 0 26px 80px rgba(0, 0, 0, 0.28);
            text-align: center;
        }

        .download-panel p {
            width: min(100%, 33rem);
            margin: 1rem auto 0;
            line-height: 1.8;
            color: var(--muted);
        }

        .download-panel .section-heading {
            margin-left: auto;
            margin-right: auto;
            text-align: center;
        }

        .download-link {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            min-height: 3.45rem;
            margin-top: 2rem;
            padding: 0.95rem 1.6rem;
            border-radius: 999px;
            text-decoration: none;
            text-transform: uppercase;
            letter-spacing: 0.12em;
            font-size: 0.92rem;
            color: #241104;
            background: linear-gradient(180deg, #ffe0b1 0%, #ffb35d 58%, #ff861f 100%);
            box-shadow: 0 22px 52px rgba(0, 0, 0, 0.36), 0 0 34px rgba(255, 145, 55, 0.16);
            transition: transform 180ms ease, box-shadow 180ms ease;
        }

        .download-link:hover,
        .download-link:focus-visible {
            transform: translateY(-2px);
            box-shadow: 0 26px 60px rgba(0, 0, 0, 0.42), 0 0 40px rgba(255, 145, 55, 0.24);
            outline: none;
        }

        footer {
            width: min(100%, 82rem);
            margin: 0 auto;
            padding: 0 1.5rem 2.8rem;
            color: var(--soft);
            font-size: 0.82rem;
            letter-spacing: 0.12em;
            text-transform: uppercase;
        }

        .visually-hidden {
            position: absolute;
            width: 1px;
            height: 1px;
            padding: 0;
            margin: -1px;
            overflow: hidden;
            clip: rect(0, 0, 0, 0);
            border: 0;
        }

        @media (max-width: 980px) {
            .masthead {
                width: min(calc(100% - 1.5rem), 74rem);
            }

            .masthead-inner {
                border-radius: 1.35rem;
                align-items: flex-start;
                flex-direction: column;
            }

            .masthead-nav {
                justify-content: flex-start;
            }

            .hero {
                min-height: auto;
                padding-top: 8.2rem;
            }

            .hero-grid {
                grid-template-columns: 1fr;
                gap: 1rem;
            }

            .hero-copy {
                padding-top: 3.5rem;
                padding-bottom: 0.5rem;
            }

            .hero-visual {
                min-height: auto;
                padding-top: 0.5rem;
            }

            .cover-vessel {
                margin: 1.5rem auto 0;
                transform: rotate(-4deg) translateX(0);
            }

            .visual-caption {
                left: 0.75rem;
                bottom: 0.75rem;
            }
        }

        @media (max-width: 640px) {
            .section {
                padding: 0 1rem;
            }

            .hero {
                padding-top: 13.5rem;
            }

            .masthead {
                top: 0.75rem;
                width: calc(100% - 1rem);
            }

            .masthead-inner {
                padding: 0.75rem;
            }

            .masthead-nav {
                width: 100%;
            }

            .masthead-nav a {
                flex: 1 1 calc(50% - 0.5rem);
            }

            .hero::before {
                inset: 0.75rem 1rem auto;
                height: calc(100% - 1.5rem);
                border-radius: 1.4rem;
            }

            .blurb-box,
            .chapter-frame,
            .download-panel {
                border-radius: 1.35rem;
            }

            .cover-vessel {
                width: min(100%, 24rem);
            }

            .visual-caption {
                position: static;
                width: auto;
                margin-top: 0.9rem;
            }

            .hero-copy .lede,
            .hero-copy .microcopy,
            .section-note,
            .download-panel p {
                font-size: 0.98rem;
                line-height: 1.72;
            }

            .chapter-frame {
                padding-top: 2.6rem;
                padding-bottom: 2.6rem;
            }

            .chapter-content {
                font-size: 1.02rem;
                line-height: 1.92;
            }

            .chapter-content p:first-of-type::first-letter {
                font-size: 3.4rem;
            }

            .hero-actions {
                flex-direction: column;
                align-items: stretch;
            }

            .hero-actions a,
            .download-link {
                width: 100%;
            }
        }
    </style>
</head>
<body>
    <canvas class="star-canvas" id="star-canvas" aria-hidden="true"></canvas>

    <div class="page">
        <div class="masthead" aria-label="Primary">
            <div class="masthead-inner">
                <a class="masthead-title" href="#top">The Two Alexes</a>
                <nav class="masthead-nav">
                    <a href="#top">Overview</a>
                    <a href="#chapter">Chapter One</a>
                    <a href="#download">Download</a>
                    <a class="primary-link" href="The Two Alexes.pdf" download>PDF</a>
                    <a class="primary-link" href="The Two Alexes.epub" download>EPUB</a>
                </nav>
            </div>
        </div>

        <header class="section hero" id="top">
            <div class="hero-grid">
                <div class="hero-copy">
                    <p class="eyebrow">A novel by Joshua Szepietowski</p>
                    <h1>The Two Alexes</h1>
                    <p class="author-line">Joshua Szepietowski</p>
                    <p class="lede">Inside a cavity held open in the corona of an unstable star, two people with the same name discover that survival can be shared more easily than love.</p>
                    <p class="microcopy">A literary hard science fiction novel about confinement, asymmetry, routine, and the quiet brutality of needing more than the universe, or another person, can return.</p>
                    <div class="hero-actions">
                        <a class="primary" href="The Two Alexes.pdf" download>Download PDF</a>
                        <a class="secondary" href="The Two Alexes.epub" download>Download EPUB</a>
                        <a class="secondary" href="#chapter">Read Chapter One</a>
                    </div>
                </div>

                <div class="hero-visual">
                    <div class="cover-vessel">
                        <img src="cover.png" alt="Cover art for The Two Alexes by Joshua Szepietowski">
                        <p class="visual-caption">A station in the light. No exit. No relief.</p>
                    </div>
                </div>
            </div>
        </header>

        <section class="section blurb" aria-labelledby="blurb-heading">
            <div class="blurb-box">
                <p class="section-label" id="blurb-heading">Blurb</p>
                <p class="blurb-copy">On a platform embedded in the living violence of a star, one Alex has made the other the center of his inner life. The other can offer care, competence, and steadiness, but not return. Beyond the hull, the universe burns without intention. Inside it, routine becomes devotion, and loneliness has nowhere left to disperse.</p>
            </div>
        </section>

        <section class="section chapter" id="chapter" aria-label="Chapter One">
            <div class="chapter-shell">
                <div class="chapter-frame">
                    <article class="chapter-content">
HTML

cat "$CHAPTER_HTML" >> "$INDEX_FILE"

cat >> "$INDEX_FILE" <<'HTML'
                </article>
            </div>
        </section>

        <section class="section download" id="download" aria-labelledby="download-heading">
            <div class="download-panel">
                <p class="section-label">Download</p>
                <h2 class="section-heading" id="download-heading">Download the full book</h2>
                <p>Complete PDF and EPUB editions are packaged beside this page for offline reading, review, sharing, and e-readers.</p>
                <a class="download-link" href="The Two Alexes.pdf" download>Download PDF</a>
                <a class="download-link" href="The Two Alexes.epub" download>Download EPUB</a>
            </div>
        </section>

        <footer>
            The Two Alexes · Joshua Szepietowski · <a href="https://joshszep.com" target="_blank" rel="noreferrer">Author book list</a>
        </footer>
    </div>

    <script>
        (function () {
            var canvas = document.getElementById('star-canvas');
            if (!canvas) {
                return;
            }

            var prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
            var gl = canvas.getContext('webgl', { antialias: false, alpha: true, premultipliedAlpha: false });

            if (!gl) {
                canvas.style.display = 'none';
                return;
            }

            var vertexSource = `
                attribute vec2 a_position;
                void main() {
                    gl_Position = vec4(a_position, 0.0, 1.0);
                }
            `;

            var fragmentSource = `
                precision highp float;

                uniform vec2 u_resolution;
                uniform float u_time;
                uniform vec2 u_pointer;

                float hash(vec2 p) {
                    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
                }

                float noise(vec2 p) {
                    vec2 i = floor(p);
                    vec2 f = fract(p);
                    vec2 u = f * f * (3.0 - 2.0 * f);

                    float a = hash(i);
                    float b = hash(i + vec2(1.0, 0.0));
                    float c = hash(i + vec2(0.0, 1.0));
                    float d = hash(i + vec2(1.0, 1.0));

                    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
                }

                float fbm(vec2 p) {
                    float value = 0.0;
                    float amplitude = 0.5;
                    for (int i = 0; i < 6; i++) {
                        value += amplitude * noise(p);
                        p *= 2.03;
                        amplitude *= 0.5;
                    }
                    return value;
                }

                mat2 rot(float angle) {
                    float c = cos(angle);
                    float s = sin(angle);
                    return mat2(c, -s, s, c);
                }

                void main() {
                    vec2 uv = (gl_FragCoord.xy / u_resolution.xy) * 2.0 - 1.0;
                    uv.x *= u_resolution.x / u_resolution.y;

                    vec2 center = vec2(0.62, 0.12);
                    center.x += (u_pointer.x - 0.5) * 0.16;
                    center.y += (u_pointer.y - 0.5) * -0.11;

                    vec2 p = uv - center;
                    float dist = length(p);
                    float angle = atan(p.y, p.x);
                    float time = u_time * 0.24;

                    vec3 color = vec3(0.01, 0.008, 0.007);

                    float starRadius = 0.46;
                    float asymmetry = 0.07 * sin(angle * 3.0 - time * 1.1) + 0.035 * sin(angle * 7.0 + time * 1.7);
                    float radiusField = starRadius + asymmetry;
                    vec2 swirl = rot(time * 0.65) * p;
                    float surface = fbm(swirl * 4.8 + vec2(time * 0.85, -time * 0.5));
                    surface += 0.55 * fbm(rot(-time * 0.58) * p * 10.5 - vec2(time * 0.15, time * 0.8));
                    surface += 0.15 * sin(angle * 21.0 + time * 5.7);
                    surface += 0.08 * sin(angle * 43.0 - time * 7.5);

                    float sphere = smoothstep(radiusField + 0.06, radiusField - 0.03, dist);
                    float core = smoothstep(radiusField * 0.64, 0.0, dist);
                    float rim = smoothstep(radiusField + 0.2, radiusField - 0.01, dist) - smoothstep(radiusField + 0.36, radiusField + 0.03, dist);
                    float flareBands = smoothstep(0.18, 1.18, fbm(vec2(angle * 3.1, dist * 9.5 - time * 1.2)) + 0.55 * sin(angle * 8.0 - time * 3.0));
                    float shock = smoothstep(radiusField + 0.08, radiusField - 0.015, dist) * (0.5 + 0.5 * sin(angle * 5.0 + time * 2.4));

                    vec3 inner = mix(vec3(0.78, 0.16, 0.02), vec3(1.0, 0.88, 0.56), clamp(surface * 1.2 + core * 0.9, 0.0, 1.0));
                    vec3 outer = mix(vec3(0.95, 0.3, 0.04), vec3(1.0, 0.72, 0.22), clamp(surface * 0.75 + 0.15, 0.0, 1.0));

                    color += mix(outer, inner, core) * sphere;
                    color += vec3(1.0, 0.55, 0.12) * rim * (0.55 + flareBands * 0.95);
                    color += vec3(1.0, 0.84, 0.46) * shock * 0.18;

                    vec2 plumePos = vec2(angle * 4.2 + time * 0.55, dist * 8.4 - time * 1.9);
                    float plumes = fbm(plumePos) * smoothstep(radiusField + 0.46, radiusField - 0.01, dist);
                    plumes *= smoothstep(radiusField - 0.1, radiusField + 0.18, dist);
                    color += vec3(1.0, 0.48, 0.09) * plumes * 0.92;

                    vec2 eruptionVec = vec2(cos(angle), sin(angle));
                    float eruptionMaskA = smoothstep(0.92, 0.995, sin(angle * 2.0 - time * 0.9));
                    float eruptionMaskB = smoothstep(0.88, 0.995, sin(angle * 3.0 + 1.4 + time * 1.3));
                    float eruptionA = fbm(vec2(angle * 10.0 - time * 2.4, dist * 12.0 - time * 3.2));
                    float eruptionB = fbm(vec2(angle * 12.0 + time * 1.8, dist * 13.0 - time * 2.5));
                    float prominences = eruptionMaskA * eruptionA + eruptionMaskB * eruptionB;
                    prominences *= smoothstep(radiusField + 0.6, radiusField + 0.02, dist);
                    prominences *= smoothstep(radiusField - 0.02, radiusField + 0.28, dist);
                    color += vec3(1.0, 0.62, 0.16) * prominences * 1.25;

                    vec2 jetCenter = p - vec2(0.18, -0.14);
                    jetCenter = rot(-0.65) * jetCenter;
                    float jet = exp(-abs(jetCenter.y) * 18.0) * smoothstep(-0.12, 0.52, jetCenter.x) * smoothstep(0.88, 0.06, length(jetCenter));
                    jet *= 0.45 + 0.55 * fbm(vec2(jetCenter.x * 12.0 - time * 5.0, jetCenter.y * 9.0));
                    color += vec3(1.0, 0.38, 0.08) * jet * 0.9;

                    float corona = exp(-max(dist - radiusField, 0.0) * 7.4);
                    float coronaNoise = fbm(vec2(angle * 5.0 - time * 0.55, dist * 7.8 + time * 1.2));
                    color += vec3(1.0, 0.42, 0.08) * corona * (0.36 + coronaNoise * 0.62);

                    vec2 secondary = uv - vec2(-0.95, -0.7);
                    float faintGlow = exp(-length(secondary) * 2.25) * 0.14;
                    color += vec3(0.24, 0.08, 0.03) * faintGlow;

                    vec2 emberField = uv * 1.8 + vec2(time * 0.12, -time * 0.08);
                    float embers = pow(max(fbm(emberField * 8.0) - 0.78, 0.0), 2.0);
                    color += vec3(1.0, 0.44, 0.16) * embers * 0.28;

                    float vignette = smoothstep(1.8, 0.35, length(uv));
                    color *= vignette;

                    gl_FragColor = vec4(color, 1.0);
                }
            `;

            function compileShader(type, source) {
                var shader = gl.createShader(type);
                gl.shaderSource(shader, source);
                gl.compileShader(shader);
                if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
                    throw new Error(gl.getShaderInfoLog(shader) || 'Shader compilation failed');
                }
                return shader;
            }

            function createProgram(vertex, fragment) {
                var program = gl.createProgram();
                gl.attachShader(program, vertex);
                gl.attachShader(program, fragment);
                gl.linkProgram(program);
                if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
                    throw new Error(gl.getProgramInfoLog(program) || 'Program link failed');
                }
                return program;
            }

            var program;
            try {
                program = createProgram(
                    compileShader(gl.VERTEX_SHADER, vertexSource),
                    compileShader(gl.FRAGMENT_SHADER, fragmentSource)
                );
            } catch (error) {
                console.error(error);
                canvas.style.display = 'none';
                return;
            }

            var buffer = gl.createBuffer();
            gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
            gl.bufferData(
                gl.ARRAY_BUFFER,
                new Float32Array([
                    -1, -1,
                     1, -1,
                    -1,  1,
                    -1,  1,
                     1, -1,
                     1,  1
                ]),
                gl.STATIC_DRAW
            );

            gl.useProgram(program);

            var positionLocation = gl.getAttribLocation(program, 'a_position');
            var timeLocation = gl.getUniformLocation(program, 'u_time');
            var resolutionLocation = gl.getUniformLocation(program, 'u_resolution');
            var pointerLocation = gl.getUniformLocation(program, 'u_pointer');

            gl.enableVertexAttribArray(positionLocation);
            gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);

            var pointer = { x: 0.5, y: 0.5 };

            function resize() {
                var ratio = Math.min(window.devicePixelRatio || 1, 2);
                canvas.width = Math.floor(window.innerWidth * ratio);
                canvas.height = Math.floor(window.innerHeight * ratio);
                canvas.style.width = window.innerWidth + 'px';
                canvas.style.height = window.innerHeight + 'px';
                gl.viewport(0, 0, canvas.width, canvas.height);
            }

            function render(time) {
                gl.uniform1f(timeLocation, prefersReducedMotion ? 0.0 : time * 0.001);
                gl.uniform2f(resolutionLocation, canvas.width, canvas.height);
                gl.uniform2f(pointerLocation, pointer.x, pointer.y);
                gl.drawArrays(gl.TRIANGLES, 0, 6);
            }

            function tick(time) {
                render(time);
                window.requestAnimationFrame(tick);
            }

            window.addEventListener('resize', resize, { passive: true });

            window.addEventListener('pointermove', function (event) {
                pointer.x = event.clientX / window.innerWidth;
                pointer.y = event.clientY / window.innerHeight;
            }, { passive: true });

            resize();
            render(0);

            if (!prefersReducedMotion) {
                window.requestAnimationFrame(tick);
            }
        }());
    </script>
</body>
</html>
HTML

echo "Generated website at $WEBSITE_DIR"
