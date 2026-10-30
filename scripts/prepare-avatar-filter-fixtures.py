#!/usr/bin/env python3
"""Generate private, non-personal sources for the real system Picker filter QA.

Use the workspace's bundled Pillow Python. This does not import media, touch a
device, change the App or claim that an App-side rejection branch was exercised.
"""
import hashlib
import io
import json
import os
from pathlib import Path
import struct
import zlib

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'artifacts/private/profile-filter-fixtures'
POSITIVE = ROOT / 'artifacts/validation/profile/avatar-fixture.png'
TARGET_BYTES = 50 * 1024 * 1024 + 1
PNG_END = b'\x00\x00\x00\x00IEND\xaeB`\x82'


def verify_image(path, expected_format):
    with Image.open(path) as image:
        if image.format != expected_format:
            raise RuntimeError('Fixture format did not match its declared format')
        image.verify()
    # verify() and actual pixel decoding are separate checks in Pillow.
    with Image.open(path) as image:
        image.load()
        if image.width <= 0 or image.height <= 0:
            raise RuntimeError('Fixture had no decoded pixels')


def record(path, expected_format):
    verify_image(path, expected_format)
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(65536), b''):
            digest.update(block)
    return {'path': str(path.resolve()), 'format': expected_format,
            'bytes': path.stat().st_size, 'sha256': digest.hexdigest()}


def large_png(path):
    # The red cross visibly distinguishes this negative source from the
    # existing four-colour positive and from the purple GIF below.
    image = Image.new('RGB', (512, 320), (162, 30, 43))
    draw = ImageDraw.Draw(image)
    draw.line((20, 20, 492, 300), fill='white', width=18)
    draw.line((492, 20, 20, 300), fill='white', width=18)
    draw.rectangle((48, 98, 464, 222), fill=(88, 12, 22))
    font = ImageFont.load_default(size=28)
    draw.text((256, 132), 'OVERSIZE PNG', font=font, anchor='mm', fill='white')
    draw.text((256, 183), '50 MiB + 1 BYTE', font=font, anchor='mm', fill='white')
    encoded = io.BytesIO()
    image.save(encoded, format='PNG', optimize=False, compress_level=9)
    data = encoded.getvalue()
    image.close()
    if not data.endswith(PNG_END):
        raise RuntimeError('Unexpected base PNG end chunk')
    # Insert a legal private unknown ancillary chunk immediately BEFORE IEND.
    # All four type bytes are letters; the reserved third byte is uppercase.
    # Size/CRC are correct. Nothing is appended after the end of the PNG.
    chunk_type = b'swAr'
    payload_size = TARGET_BYTES - len(data) - 12
    if payload_size < 0 or payload_size >= 2 ** 31:
        raise RuntimeError('Invalid PNG ancillary chunk size')
    block = bytes([165]) * 65536
    crc = zlib.crc32(chunk_type)
    with path.open('wb') as output:
        output.write(data[:-12])
        output.write(struct.pack('>I', payload_size))
        output.write(chunk_type)
        remaining = payload_size
        while remaining:
            piece = block[:min(len(block), remaining)]
            output.write(piece)
            crc = zlib.crc32(piece, crc)
            remaining -= len(piece)
        output.write(struct.pack('>I', crc & 0xffffffff))
        output.write(PNG_END)
    if path.stat().st_size != TARGET_BYTES:
        raise RuntimeError('Oversize PNG did not have the exact requested byte size')


def small_gif(path):
    image = Image.new('RGB', (320, 200), (87, 43, 141))
    draw = ImageDraw.Draw(image)
    for x in range(0, 320, 40):
        for y in range(0, 200, 40):
            if (x // 40 + y // 40) % 2 == 0:
                draw.rectangle((x, y, x + 39, y + 39), fill=(167, 124, 206))
    draw.rectangle((18, 47, 302, 153), fill=(43, 19, 75))
    font = ImageFont.load_default(size=27)
    draw.text((160, 82), 'GIF FILTER', font=font, anchor='mm', fill='white')
    draw.text((160, 126), 'NOT SUPPORTED', font=font, anchor='mm', fill='white')
    palette = image.convert('P', palette=Image.Palette.ADAPTIVE, colors=32)
    palette.save(path, format='GIF', optimize=False)
    palette.close()
    image.close()


def main():
    os.umask(0o077)
    OUTPUT.mkdir(parents=True, exist_ok=True, mode=0o700)
    OUTPUT.chmod(0o700)
    if not POSITIVE.is_file():
        raise RuntimeError('Generate the existing positive avatar fixture first')
    # Reference the original read-only positive; never copy or rewrite it.
    positive = record(POSITIVE, 'PNG')
    oversize_path = OUTPUT / 'starward-filter-oversize.png'
    gif_path = OUTPUT / 'starward-filter-unsupported.gif'
    large_png(oversize_path)
    small_gif(gif_path)
    for path in (oversize_path, gif_path):
        path.chmod(0o600)
    manifest = {'smallPng': positive,
                'oversizePng': record(oversize_path, 'PNG'),
                'unsupportedGif': record(gif_path, 'GIF')}
    manifest_path = OUTPUT / 'manifest.json'
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    manifest_path.chmod(0o600)
    # Only local paths, formats, sizes and hashes are printed; no image payload.
    print(json.dumps({'manifest': str(manifest_path.resolve()), 'fixtures': manifest},
                     ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
