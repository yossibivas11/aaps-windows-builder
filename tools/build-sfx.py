#!/usr/bin/env python3
"""Rebuild AndroidAPS-Builder-EN.bat from the files in src/.

The launcher is the existing batch header plus a base64 zip of what a user
needs. Run from the repository root or from anywhere:

    python tools/build-sfx.py
"""
import base64
import io
import os
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')
OUT = os.path.join(ROOT, 'AndroidAPS-Builder-EN.bat')

# Internal zip names, in a stable order.
FILES = [
    ('Build-AAPS.bat', 'Build-AAPS.bat'),
    ('README.html', 'README.html'),
    ('TEST-FIRST.bat', 'TEST-FIRST.bat'),
    ('Build-AAPS.ps1', 'AAPS-Builder-Files/Build-AAPS.ps1'),
    ('READ-ME-FIRST.txt', 'AAPS-Builder-Files/READ-ME-FIRST.txt'),
]


def main():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', compression=zipfile.ZIP_DEFLATED) as zf:
        for src_name, arc_name in FILES:
            zf.write(os.path.join(SRC, src_name), arc_name)
    b64 = base64.b64encode(buf.getvalue()).decode('ascii')
    payload_lines = [b64[i:i + 76] for i in range(0, len(b64), 76)]

    text = open(OUT, 'r', encoding='utf-8', newline='').read()
    parts = text.splitlines(keepends=True)
    markers = [i for i, line in enumerate(parts) if line.startswith('::PAYLOAD::')]
    if not markers:
        raise SystemExit('marker line not found in AndroidAPS-Builder-EN.bat')
    # The marker also appears inside the helper script, so cut at the line
    # that starts with it, not at the first occurrence anywhere.
    header = ''.join(parts[:markers[0] + 1])
    if not header.endswith('\n'):
        header += '\n'
    payload = '\r\n'.join(payload_lines) + '\r\n'
    with open(OUT, 'w', newline='', encoding='utf-8') as f:
        f.write(header)
        f.write(payload)
    print('wrote %s (%d byte zip, %d payload lines)' % (OUT, buf.tell(), len(payload_lines)))


if __name__ == '__main__':
    main()
