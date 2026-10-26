#!/usr/bin/env python3
"""Fill translations/cclicker_en.ts from translations/en.py after `update_translations`."""
import os, runpy, sys
import xml.etree.ElementTree as ET
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'translations')
table = runpy.run_path(os.path.join(root, 'en.py'))
T, CTX = table['T'], table['CTX']
path = os.path.join(root, 'cclicker_en.ts')
tree = ET.parse(path)
missing = []
for ctx in tree.getroot().iter('context'):
    name = ctx.findtext('name')
    for m in ctx.iter('message'):
        src = m.findtext('source')
        text = CTX.get((name, src), T.get(src))
        t = m.find('translation')
        if text is None:
            missing.append(f'{name}: {src!r}')
            continue
        t.text = text
        t.attrib.pop('type', None)
body = ET.tostring(tree.getroot(), encoding='unicode')
with open(path, 'w', encoding='utf-8') as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n<!DOCTYPE TS>\n' + body + '\n')
if missing:
    sys.exit('missing translations:\n' + '\n'.join(missing))
print('filled', path)
