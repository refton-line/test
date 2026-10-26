#!/usr/bin/env python3
"""Fail when the English catalogue is stale or incomplete.

Re-runs lupdate over the sources into a scratch copy of the .ts file, then checks
that no message is new, unfinished or empty, and that %1/%2 placeholders match.
"""
import argparse, glob, os, re, shutil, subprocess, sys, tempfile
import xml.etree.ElementTree as ET

p = argparse.ArgumentParser()
p.add_argument('--lupdate', required=True)
p.add_argument('--root', required=True)
p.add_argument('--ts', required=True)
a = p.parse_args()
root = a.root
sources = sorted(glob.glob(f'{root}/src/*.cpp') + glob.glob(f'{root}/src/*.h') +
                 glob.glob(f'{root}/qml/*.qml') + glob.glob(f'{root}/qml/components/*.qml') +
                 glob.glob(f'{root}/qml/components/*.js'))


def messages(path):
    out = {}
    for ctx in ET.parse(path).getroot().iter('context'):
        name = ctx.findtext('name')
        for m in ctx.iter('message'):
            t = m.find('translation')
            out[(name, m.findtext('source'))] = (t.text or '', t.get('type', ''))
    return out


with tempfile.TemporaryDirectory() as tmp:
    scratch = os.path.join(tmp, 'check.ts')
    shutil.copy(os.path.join(root, a.ts), scratch)
    r = subprocess.run([a.lupdate, '-silent', '-no-obsolete', '-locations', 'none', '-source-language', 'ru',
                        '-target-language', 'en', *sources, '-ts', scratch], capture_output=True, text=True)
    if r.returncode:
        sys.exit('lupdate failed:\n' + r.stdout + r.stderr)
    fresh, shipped = messages(scratch), messages(os.path.join(root, a.ts))

problems = []
for key in sorted(set(fresh) - set(shipped)):
    problems.append(f'not in catalogue: {key[0]}: {key[1]!r}')
for key in sorted(set(shipped) - set(fresh)):
    problems.append(f'stale entry: {key[0]}: {key[1]!r}')
placeholder = re.compile(r'%\d')
cyrillic = re.compile('[\u0400-\u04FF]')
for (ctx, src), (text, kind) in sorted(fresh.items()):
    if kind in ('unfinished', 'vanished', 'obsolete') or not text.strip():
        problems.append(f'untranslated: {ctx}: {src!r}')
    elif sorted(placeholder.findall(src)) != sorted(placeholder.findall(text)):
        problems.append(f'placeholder mismatch: {ctx}: {src!r} -> {text!r}')
    elif cyrillic.search(text):
        problems.append(f'Cyrillic left in English: {ctx}: {text!r}')
if problems:
    print('\n'.join(problems))
    sys.exit(f'{len(problems)} translation problem(s)')
print(f'TRANSLATIONS_COMPLETE {len(fresh)} messages')
