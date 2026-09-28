#!/usr/bin/env python3
"""Lay out the saved Flutter screenshots as light and dark README grids.

Requires rsvg-convert from librsvg. Source screenshots remain unchanged.
"""

import argparse
import base64
import html
import math
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile


APP = Path(__file__).resolve().parents[1]
SCREENS = (
    ("home", "Home"),
    ("transactions", "Transactions"),
    ("add_transaction", "Add transaction"),
    ("insights_overview", "Insights"),
    ("insights_trend_selected", "Spending analysis"),
    ("recurrences", "Recurring payments"),
)
PALETTES = {
    "light": ("#EEEFF5", "#252336", "#626575", "#D7D9E5"),
    "dark": ("#0C0D11", "#F2F2F7", "#A7A9B8", "#343640"),
}


def data_uri(path, mime):
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode()}"


def grid(theme):
    background, text, muted, border = PALETTES[theme]
    width, margin, gap, card_width = 1440, 64, 32, 416
    top, caption, row_gap = 164, 46, 46
    images = []
    dimensions = None
    for name, label in SCREENS:
        path = APP / "test/screenshots/goldens" / f"{name}_{theme}.png"
        if not path.is_file():
            raise SystemExit(f"Missing {path}. Regenerate the Flutter screenshot goldens first.")
        size = struct.unpack(">II", path.read_bytes()[16:24])
        if dimensions is not None and size != dimensions:
            raise SystemExit(f"Screenshot dimensions differ: {path} is {size}, expected {dimensions}")
        dimensions = size
        images.append((label, data_uri(path, "image/png")))
    card_height = card_width * dimensions[1] / dimensions[0]
    height = math.ceil(top + 2 * (caption + card_height) + row_gap + margin)
    logo = data_uri(APP / "assets/branding/moneef-icon.svg", "image/svg+xml")
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        f'<title>Moneef screenshots in {theme} mode</title>',
        '<desc>Home, transactions, add transaction, insights, spending analysis, and recurring payments. Sample data.</desc>',
        f'<rect width="{width}" height="{height}" fill="{background}"/>',
        f'<image href="{logo}" x="64" y="48" width="56" height="56"/>',
        f'<g font-family="Manrope, sans-serif" fill="{text}">',
        '<text x="140" y="88" font-size="40" font-weight="800">Moneef</text>',
        f'<text x="1376" y="84" text-anchor="end" font-size="22" fill="{muted}">{theme.capitalize()} mode</text>',
        f'<path d="M64 130H1376" stroke="{border}"/>',
    ]
    for index, (label, image) in enumerate(images):
        x = margin + (index % 3) * (card_width + gap)
        y = top + (index // 3) * (caption + card_height + row_gap)
        parts.extend([
            f'<text x="{x}" y="{y + 22}" font-size="22" font-weight="600">{html.escape(label)}</text>',
            f'<rect x="{x - 1}" y="{y + caption - 1}" width="{card_width + 2}" height="{card_height + 2}" fill="{border}"/>',
            f'<image href="{image}" x="{x}" y="{y + caption}" width="{card_width}" height="{card_height}"/>',
        ])
    return "\n".join([*parts, "</g></svg>"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify exports without writing them")
    args = parser.parse_args()
    renderer = shutil.which("rsvg-convert")
    if not renderer:
        raise SystemExit("Install rsvg-convert from librsvg to generate the grids.")
    output = APP / "docs/screenshots"
    with tempfile.TemporaryDirectory(prefix="moneef-screenshot-grid-") as temporary:
        # Load the same bundled font as Flutter without installing it system-wide.
        config = Path(temporary) / "fonts.conf"
        config.write_text(
            '<fontconfig><include ignore_missing="yes">/etc/fonts/fonts.conf</include>'
            f'<dir>{html.escape(str(APP / "assets/fonts"))}</dir>'
            f'<cachedir>{html.escape(temporary)}</cachedir></fontconfig>'
        )
        environment = {**os.environ, "FONTCONFIG_FILE": str(config)}
        for theme in PALETTES:
            png = subprocess.run(
                [renderer, "--format=png"], input=grid(theme).encode(),
                stdout=subprocess.PIPE, check=True, env=environment,
            ).stdout
            target = output / f"screenshot-grid-{theme}.png"
            if args.check:
                if not target.is_file() or target.read_bytes() != png:
                    raise SystemExit(f"Stale or missing export: {target}. Run this script without --check.")
                print(f"Verified {target.relative_to(APP)}")
            else:
                output.mkdir(parents=True, exist_ok=True)
                target.write_bytes(png)
                print(f"Generated {target.relative_to(APP)} ({len(png):,} bytes)")


if __name__ == "__main__":
    main()
