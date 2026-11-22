#!/usr/bin/env python3
"""Refresh the standalone Luau payload from the web preview's catalog and images (ImageMagick)."""
import base64
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'snowpaw' / 'assets'
FILE = ROOT / 'SnowpawMenu.client.luau'
START = '-- BEGIN EMBEDDED KIT (generated from snowpaw/kit.json and snowpaw/assets)\n'
END = '-- END EMBEDDED KIT'


def raster(path, w, h):
    raw = subprocess.check_output(['convert', str(ART / path), '-resize', f'{w}x{h}!',
                                   '+dither', '-colors', '96', '-depth', '8', 'rgb:-'])
    assert len(raw) == 3 * w * h
    colors = {}; pixels = bytearray()
    for i in range(0, len(raw), 3):
        color = raw[i:i+3]
        pixels.append(colors.setdefault(color, len(colors)))
    palette = b''.join(colors).hex().upper(); data = base64.b64encode(pixels).decode()
    # Wrapped literals keep the rest of the source navigable in plain-text editors.
    lines = [f'"{data[i:i+160]}"' for i in range(0, len(data), 160)]
    return f'{{w={w},h={h},palette="{palette}",data=table.concat({{\n' + ',\n'.join(lines) + '\n})}'


def literal(value):
    if isinstance(value, dict):
        return '{' + ','.join('[' + literal(k) + ']=' + literal(v) for k,v in value.items()) + '}'
    if isinstance(value, list):
        return '{' + ','.join(literal(v) for v in value) + '}'
    return json.dumps(value, ensure_ascii=False)


def main():
    kit = json.loads((ROOT / 'snowpaw/kit.json').read_text())
    data = '{\n' + ',\n'.join(k+'='+literal(v) for k,v in kit.items()) + '\n}'
    art = [('plate', raster('night-patrol.jpg', 460, 134)), ('avatar', raster('snowpaw.jpg', 64, 64))]
    payload = 'local CATALOG=' + data + '\nlocal PHOTOS={\n' + ',\n'.join(k+'='+v for k,v in art) + '\n}\n'
    old = FILE.read_text(); head, rest = old.split(START); _, tail = rest.split(END)
    result = head + START + payload + END + tail
    if '--check' in sys.argv:
        if result != old: raise SystemExit('Snowpaw payload is stale; rerun tools/sync_snowpaw.py')
    else: FILE.write_text(result)
    print('Snowpaw: 2 embedded photos,',len(kit['tabs']),'sections,',len(result.encode()),'bytes')


if __name__ == '__main__': main()
