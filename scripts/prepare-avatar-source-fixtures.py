#!/usr/bin/env python3
"""Prepare private JPEG/EXIF6 and WebP fixtures; this performs no device testing."""
import datetime
import hashlib
import json
import os
from pathlib import Path

from PIL import Image, ImageOps, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'artifacts/validation/profile/avatar-fixture.png'
BASE = ROOT / 'artifacts/private/avatar-source-fixtures'
PALETTE = {'A': [210, 62, 69], 'B': [36, 112, 198], 'C': [224, 166, 43], 'D': [118, 76, 177]}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def facts(path):
    return {'file': str(path.relative_to(ROOT)), 'sha256': digest(path), 'bytes': path.stat().st_size}


def verify(path, expected_format, expected_size):
    with Image.open(path) as picture:
        if picture.format != expected_format or picture.size != expected_size:
            raise RuntimeError('Generated source format/dimensions differ from the fixture plan')
        picture.verify()
    with Image.open(path) as picture:
        picture.load()
        return {'pillowVerifyPassed': True, 'pillowLoadPassed': True,
                'format': picture.format, 'rawDimensions': list(picture.size),
                'exifOrientation': picture.getexif().get(274)}


def save_image(image, path, **options):
    if path.exists() or path.is_symlink():
        raise RuntimeError('Refusing to overwrite a private source fixture')
    image.save(path, **options)
    path.chmod(0o600)



GLYPHS = {
    'J': ['00111','00010','00010','00010','10010','10010','01100'],
    'P': ['11110','10001','10001','11110','10000','10000','10000'],
    'E': ['11111','10000','10000','11110','10000','10000','11111'],
    'G': ['01110','10001','10000','10111','10001','10001','01110'],
    '6': ['01110','10000','10000','11110','10001','10001','01110'],
    'W': ['10001','10001','10001','10101','10101','10101','01010'],
    'B': ['11110','10001','10001','11110','10001','10001','11110'],
}


def marked(image, label, background):
    """Large deterministic bitmap text in displayed/oriented coordinates."""
    image = image.copy()
    draw = ImageDraw.Draw(image)
    scale = 12
    text_width = (len(label)*6-1)*scale
    width, height = max(480,text_width+48), 132
    left, top = (image.width-width)//2, (image.height-height)//2
    draw.rectangle((left,top,left+width-1,top+height-1),fill=background,
                   outline=(255,255,255),width=6)
    x0, y0 = (image.width-text_width)//2, (image.height-7*scale)//2
    for index,char in enumerate(label):
        for y,row in enumerate(GLYPHS[char]):
            for x,bit in enumerate(row):
                if bit == '1':
                    px,py=x0+(index*6+x)*scale,y0+y*scale
                    draw.rectangle((px,py,px+scale-1,py+scale-1),fill=(255,255,255))
    return image


def main():
    source_meta = json.loads(SOURCE.with_suffix('.json').read_text())
    if digest(SOURCE) != source_meta['sha256']:
        raise RuntimeError('The original generated four-quadrant fixture changed')
    with Image.open(SOURCE) as source:
        source.load()
        original = source.convert('RGB')
    if original.size != (1024, 640):
        raise RuntimeError('Expected the existing1024x640 four-quadrant fixture')
    directory = BASE / ('prepared-' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
    directory.mkdir(parents=True, exist_ok=False, mode=0o700)
    directory.chmod(0o700)
    entries = []
    for case in ('jpeg-exif6', 'webp-rgb'):
        if case == 'jpeg-exif6':
            path = directory / 'quadrants-exif6.jpg'
            exif = Image.Exif()
            exif[274] = 6
            displayed = marked(original.transpose(Image.Transpose.ROTATE_270), 'JPEG6', (121,24,45))
            raw_marked = displayed.transpose(Image.Transpose.ROTATE_90)
            save_image(raw_marked, path, format='JPEG', quality=95, exif=exif)
            validation = verify(path, 'JPEG', (1024, 640))
            if validation['exifOrientation'] != 6:
                raise RuntimeError('Generated JPEG did not retain EXIF Orientation6')
            order, orientation = ['C','A','D','B'], 'Rotate90 degrees clockwise according to EXIF Orientation6'
        else:
            path = directory / 'quadrants-rgb.webp'
            displayed = marked(original, 'WEBP', (11,82,55))
            save_image(displayed, path, format='WEBP', lossless=True, quality=100, method=6)
            validation = verify(path, 'WEBP', (1024, 640))
            order, orientation = ['A','B','C','D'], 'No rotation; RGB WebP without alpha'
        with Image.open(path) as decoded:
            normalized = ImageOps.exif_transpose(decoded).convert('RGB')
            side = min(normalized.size)
            left, top = (normalized.width-side)//2, (normalized.height-side)//2
            region = (left, top, left+side, top+side)
            expected = normalized.crop(region).resize((512,512), Image.Resampling.LANCZOS)
            if case == 'jpeg-exif6':
                raw = decoded.convert('RGB')
                wrong_side = min(raw.size)
                wrong_left, wrong_top = (raw.width-wrong_side)//2, (raw.height-wrong_side)//2
                wrong = raw.crop((wrong_left,wrong_top,wrong_left+wrong_side,wrong_top+wrong_side)).resize((512,512), Image.Resampling.LANCZOS)
                wrong_name = 'Ignore EXIF orientation, then center-crop the raw1024x640 image'
            else:
                wrong = normalized.resize((512,512), Image.Resampling.LANCZOS)
                wrong_name = 'Resize the complete1024x640 WebP into a square without the correct center crop'
        expected_jpeg = directory / (case+'-expected-centered.jpg')
        expected_png = directory / (case+'-expected-centered.png')
        wrong_png = directory / (case+'-wrong-hypothesis.png')
        save_image(expected, expected_jpeg, format='JPEG', quality=95, exif=b'')
        save_image(expected, expected_png, format='PNG')
        save_image(wrong, wrong_png, format='PNG')
        verify(expected_jpeg, 'JPEG', (512,512))
        verify(expected_png, 'PNG', (512,512))
        verify(wrong_png, 'PNG', (512,512))
        samples = []
        for label, point in zip(order, ((.17,.17),(.83,.17),(.17,.83),(.83,.83))):
            rgb = list(expected.getpixel((int(point[0]*512), int(point[1]*512))))
            samples.append({'position': list(point), 'quadrant': label, 'expectedRGB': rgb,
                            'nominalQuadrantRGB': PALETTE[label]})
        entries.append({'case': case, 'source': {**facts(path), **validation},
            'formatMarker': {'text': 'JPEG6' if case=='jpeg-exif6' else 'WEBP',
                             'coordinates': 'Displayed/oriented image center, inside the expected square crop',
                             'style': 'Large white bitmap text with white frame; maroon JPEG6 versus green WEBP'},
            'normalization': orientation, 'normalizedDimensions': list(normalized.size),
            'centerCropRegion': list(region), 'outputDimensions': [512,512],
            'quadrantOrder': order, 'quadrantSamples': samples,
            'expectedJpeg': facts(expected_jpeg), 'expectedLosslessPng': facts(expected_png),
            'wrongHypothesis': {'description': wrong_name, **facts(wrong_png)},
            'wrongUnrotatedComparisonApplicable': case=='jpeg-exif6',
            'nativeAcceptance': 'Not executed; requires real system Picker, ImageKit and native multipart upload'})
    manifest = {'status': 'prepared_not_device_tested', 'preparedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'scope': 'Private deterministic source-format and EXIF-orientation fixtures only',
        'source': facts(SOURCE), 'cases': entries,
        'limits': {'originalMaxBytes':50*1024*1024, 'outputMaxEdge':512, 'outputMaxBytes':200*1024},
        'notes': ['Pillow preparation/verification does not verify native ImageKit behaviour.',
                  'JPEG EXIF6 raw dimensions remain1024x640; normalized640x1024 center region[0,192,640,832] gives C/A/D/B.',
                  'WebP is RGB without alpha; alpha behaviour is outside this fixture scope.',
                  'Distinct JPEG6 and WEBP bitmap banners are encoded into the actual source; all expected images derive from decoding that encoded source.',
                  'Wrong-unrotated comparison applies only to EXIF6; WebP instead contrasts the wrong whole-image stretch.']}
    target = directory / 'manifest.json'
    fd = os.open(target, os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd,'w') as output:
        json.dump(manifest,output,ensure_ascii=False,indent=2)
        output.write('\n')
    print(json.dumps({'status':'prepared_not_device_tested','cases':len(entries),
                      'manifest':str(target.relative_to(ROOT)),'manifestSha256':digest(target)}))


if __name__ == '__main__':
    main()
