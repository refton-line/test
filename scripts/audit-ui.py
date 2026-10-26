#!/usr/bin/env python3
"""Native QML audit; web CSS scanners cannot measure the actual Qt theme."""
from pathlib import Path
import re,json,sys
root=Path(__file__).resolve().parents[1]
text=(root/'qml/Theme.qml').read_text()
raw=dict(re.findall(r'readonly property color (\w+):\s*([^\n]+)',text))
def resolve(k):
 v=raw[k].strip().strip('"')
 return v if v.startswith('#') else resolve(v)
colors={k:resolve(k) for k in raw if k!='clear'}
def lum(h):
 c=[int(h[i:i+2],16)/255 for i in (1,3,5)]
 return sum(w*(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4) for w,v in zip([.2126,.7152,.0722],c))
def contrast(a,b):
 x,y=sorted([lum(colors[a]),lum(colors[b])]);return (y+.05)/(x+.05)
pairs=[]
for bg in ['canvas','workspace','rail','surface','surfaceRaised','accentSoft']:
 for fg in ['ink','muted']:
  pairs.append((fg,bg,4.5))
 for fg in ['focus','controlBorder']:
  pairs.append((fg,bg,3))
pairs += [('accentInk','accent',4.5),('accentInk','accentEnd',4.5),('accentInk','accentHover',4.5),('accentInk','primaryHint',4.5),('danger','surface',4.5),('sheen','dangerFace',3),('sheen','dangerPressed',3),('focusOnAccent','accent',3),('focusOnAccent','accentHover',3)]
for bg in ['canvas','workspace','rail','surface','surfaceRaised','accentSoft']:
 pairs.append(('brand',bg,3))
errors=[];results=[]
for a,b,minimum in pairs:
 r=contrast(a,b);results.append({'foreground':a,'background':b,'ratio':round(r,2),'minimum':minimum})
 if r<minimum: errors.append(f'{a}/{b}: {r:.2f} < {minimum}')
for p in (root/'qml').rglob('*.qml'):
 if p.name!='Theme.qml' and re.search(r'#[\da-fA-F]{6}',p.read_text()): errors.append('Local color outside Theme: '+str(p.relative_to(root)))
# Verify static and dynamic icon paths, including the window-state pairs.
icons=set()
for p in (root/'qml').rglob('*.qml'):
 # State { name: "..." } names a state, not an icon.
 for line in p.read_text().splitlines():
  if 'State {' not in line: icons.update(re.findall(r'(?<![\w.])(?:glyph|name):\s*"([\w-]+)"',line))
icons.update(['mouse','activity','keyboard','folder','maximize','restore','fullscreen','minimize','x','minus','play','square'])
for icon in icons:
 if not (root/'assets'/f'{icon}.svg').exists():errors.append('Missing icon: '+icon)
for p in (root/'assets').glob('*.svg'):
 if p.name not in ['c-mark.svg','app-icon.svg'] and 'stroke-width="1.75"' not in p.read_text():errors.append('Inconsistent icon weight: '+p.name)
# This release removes redundant controls and their unused APIs/resources.
for p in (root/'qml').rglob('*.qml'):
 if re.search(r'\btip\s*:|\bchosenVK\b|\bchosenMods\b|\bneon\b|refreshConfigs|glyph:\s*"info"', p.read_text()):
  errors.append('Removed legacy surface returned: '+str(p.relative_to(root)))
keyboard=(root/'qml/components/KeyboardMap.js').read_text()
keys=json.loads(keyboard.split('var keys = ',1)[1].strip().removesuffix(';'))
identities=[k['v'] for k in keys]
if len(set(identities)) != len(identities): errors.append('Duplicate virtual keyboard identity')
if any('k' in k or 'm' in k for k in keys): errors.append('Legacy duplicate keyboard fields returned')
if (root/'assets/info.svg').exists(): errors.append('Unused info asset returned')
report={'theme':'Graphite / Silver','contrast':results,'icons_checked':len(icons),'errors':errors,'note':'Disabled controls are exempt from AA; motion and native layout are verified by the capture harness.'}
print(json.dumps(report,ensure_ascii=False,indent=2))
sys.exit(bool(errors))
