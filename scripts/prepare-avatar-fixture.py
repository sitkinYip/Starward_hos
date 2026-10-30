#!/usr/bin/env python3
"""Create a deterministic, non-private QA image for the native avatar flow."""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'artifacts/validation/profile/avatar-fixture.png'
WIDTH, HEIGHT, GRID = 1024, 640, 64
PALETTE = {'A': (210, 62, 69), 'B': (36, 112, 198),
           'C': (224, 166, 43), 'D': (118, 76, 177)}
LETTERS = {
    'A': ('01110', '10001', '10001', '11111', '10001', '10001', '10001'),
    'B': ('11110', '10001', '10001', '11110', '10001', '10001', '11110'),
    'C': ('01111', '10000', '10000', '10000', '10000', '10000', '01111'),
    'D': ('11110', '10001', '10001', '10001', '10001', '10001', '11110'),
}


def letter(draw, text, center):
    """Integer bitmap lettering avoids machine-specific fonts and metrics."""
    scale = 12
    left, top = center[0] - 30, center[1] - 42
    for y, row in enumerate(LETTERS[text]):
        for x, pixel in enumerate(row):
            if pixel == '1':
                draw.rectangle((left + x * scale - 2, top + y * scale - 2,
                                left + (x + 1) * scale + 1, top + (y + 1) * scale + 1),
                               fill=(20, 28, 32))
    for y, row in enumerate(LETTERS[text]):
        for x, pixel in enumerate(row):
            if pixel == '1':
                draw.rectangle((left + x * scale, top + y * scale,
                                left + (x + 1) * scale - 1, top + (y + 1) * scale - 1),
                               fill=(255, 255, 255))


def crop_case(name, zoom, horizontal, vertical):
    side = max(1, int(min(WIDTH, HEIGHT) / zoom))
    # Match non-negative ArkTS Math.round rather than Python's bankers rounding.
    x = int((WIDTH - side) * horizontal / 100 + .5)
    y = int((HEIGHT - side) * vertical / 100 + .5)
    return {'name': name, 'zoom': zoom, 'horizontal': horizontal, 'vertical': vertical,
            'sourceRegion': {'x': x, 'y': y, 'width': side, 'height': side},
            'outputEdge': min(512, side), 'gridPitchInOutput': GRID * min(512, side) / side}


def main():
    image = Image.new('RGB', (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(image)
    for name, bounds, center in (
        ('A', (0, 0, 511, 319), (256, 160)),
        ('B', (512, 0, 1023, 319), (768, 160)),
        ('C', (0, 320, 511, 639), (256, 480)),
        ('D', (512, 320, 1023, 639), (768, 480)),
    ):
        draw.rectangle(bounds, fill=PALETTE[name])
        letter(draw, name, center)
    for x in range(GRID, WIDTH, GRID):
        draw.line((x, 0, x, HEIGHT - 1), fill=(240, 240, 240), width=1)
    for y in range(GRID, HEIGHT, GRID):
        draw.line((0, y, WIDTH - 1, y), fill=(240, 240, 240), width=1)
    draw.rectangle((508, 0, 515, HEIGHT - 1), fill=(255, 255, 255))
    draw.rectangle((0, 316, WIDTH - 1, 323), fill=(255, 255, 255))
    draw.rectangle((0, 0, WIDTH - 1, HEIGHT - 1), outline=(20, 28, 32), width=4)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT, format='PNG', optimize=False, compress_level=9)
    metadata = {'kind': 'deterministic non-private avatar QA fixture',
                'file': str(OUTPUT.relative_to(ROOT)), 'sha256': hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
                'width': WIDTH, 'height': HEIGHT, 'mode': 'RGB', 'mimeType': 'image/png',
                'source': 'Code-drawn solid quadrants, integer grid and bitmap A/B/C/D labels; no personal media or external fonts',
                'quadrants': {key: list(value) for key, value in PALETTE.items()}, 'grid': GRID,
                'cases': [crop_case('center-default', 1, 50, 50),
                          crop_case('top-left-zoom2', 2, 0, 0),
                          crop_case('bottom-right-zoom2', 2, 100, 100),
                          crop_case('bottom-left-zoom4', 4, 0, 100)],
                'limits': {'originalMaxBytes': 50 * 1024 * 1024, 'outputMaxBytes': 200 * 1024,
                           'outputMaxEdge': 512, 'outputFormat': 'image/jpeg'},
                'notes': ['At zoom1 the full 640px source height is used, so the vertical slider has no remaining range.',
                          'Use zoom2 to verify both horizontal and vertical movement.',
                          'Output sizes below512 stay at the crop size; the implementation does not upscale.',
                          'Compare JPEG solid patches away from grid, text and borders with a small compression tolerance.']}
    OUTPUT.with_suffix('.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(json.dumps({'output': str(OUTPUT.relative_to(ROOT)), 'sha256': metadata['sha256'],
                      'pixels': [WIDTH, HEIGHT], 'bytes': OUTPUT.stat().st_size}))


if __name__ == '__main__':
    main()
