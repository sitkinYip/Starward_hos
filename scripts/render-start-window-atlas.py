#!/usr/bin/env python3
"""Rasterize a still of the existing SessionAtlas for the OS-owned startup window."""

import json
from pathlib import Path
import xml.etree.ElementTree as ET

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "entry/src/main/resources"


def palette(theme: str) -> dict[str, str]:
    return {item["name"]: item["value"] for item in json.loads(
        (RESOURCES / theme / "element/color.json").read_text())["color"]}


def artwork(colors: dict[str, str], star: str) -> str:
    ink = colors["accent_muted"]
    paper = colors["start_window_background"]
    accent = colors["accent"]
    glow = colors["accent_soft"]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 390 390">
  <defs>
    <radialGradient id="halo">
      <stop offset="0" stop-color="#{glow[3:]}" stop-opacity="{int(glow[1:3], 16) / 255}"/>
      <stop offset="1" stop-color="#{glow[3:]}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <!-- Frame the SessionAtlas above center, leaving space for its real ArkUI status text. -->
  <g transform="translate(195,152)" fill="none" stroke-width="1">
    <circle r="158" fill="url(#halo)"/>
    <g stroke="{ink}" opacity=".5">
      <circle r="115" fill="none"/>
      <circle r="105" fill="none" stroke-dasharray="2 3"/>
      <circle cx="-114" r="4" fill="{paper}"/>
      <circle cx="78" cy="-85" r="3" fill="{ink}"/>
      <circle cx="5" cy="120" r="6" fill="{paper}"/>
    </g>
    <g stroke="{ink}" opacity=".7">
      <circle r="82" fill="none"/>
      <circle r="87" fill="none"/>
      <circle cx="-77" r="4" fill="{paper}"/>
      <circle cx="56" cy="-60" r="3" fill="{ink}"/>
    </g>
    <g stroke="{ink}" opacity=".6">
      <circle r="46" fill="none" stroke-dasharray="2 3"/>
      <circle cx="-45" r="4" fill="{paper}"/>
    </g>
    <path d="M0 -136 136 0 0 136 -136 0Z M-88 -88 88 88 M-88 88 88 -88" fill="none" stroke="{ink}" opacity=".15"/>
    <path d="{star}" fill="{ink}" transform="translate(-29,-29) scale(.2265625)"/>
    <g stroke="{ink}" stroke-width=".8">
      <path d="M-2.6 -92v-7l5.2 7v-7 M2.4 97c-1-1.6-5-1.5-5 .8 0 2.4 5 1.3 5 3.7 0 2.2-3.8 2.2-5 1" fill="none"/>
    </g>
    <circle r="127" fill="none" stroke="{colors["accent_border"]}" stroke-dasharray="2 7"/>
    <path d="M-85 90A124 124 0 0 0 21 122" fill="none" stroke="{accent}" stroke-width="1.5"/>
  </g>
</svg>'''


def main() -> None:
    star_path = (RESOURCES / "base/media/icon_star_four.svg")
    star = ET.parse(star_path).getroot().find("{http://www.w3.org/2000/svg}path")
    if star is None:
        raise ValueError("The project star SVG has no path")
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True, args=["--disable-background-networking"])
        page = browser.new_page(viewport={"width": 256, "height": 256})
        for theme in ("base", "dark"):
            media = RESOURCES / theme / "media"
            media.mkdir(parents=True, exist_ok=True)
            svg = artwork(palette(theme), star.attrib["d"])
            page.set_content('<style>body { margin: 0; }</style>' + svg)
            page.locator("svg").screenshot(path=media / "start_window_atlas.png", omit_background=True)
        browser.close()


if __name__ == "__main__":
    main()
