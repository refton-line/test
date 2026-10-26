#!/usr/bin/env bash
# Rebuild assets/app.ico, assets/c-mark.png and the 1024 px preview from the SVG
# sources here. Needs rsvg-convert (librsvg2-bin) and icotool (icoutils).
# 16-48 px come from app-icon-small.svg (no blur, heavier C), 64-256 px from
# app-icon.svg. Entries up to 128 px are 32-bit BMP for the widest loader
# support; 256 px is PNG-compressed, as Windows expects.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
assets="$here/../../assets"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for s in 16 20 24 32 40 48; do rsvg-convert -w $s -h $s "$here/app-icon-small.svg" -o "$tmp/$s.png"; done
for s in 64 128 256 1024; do rsvg-convert -w $s -h $s "$here/app-icon.svg" -o "$tmp/$s.png"; done
icotool -c -o "$assets/app.ico" "$tmp"/{16,20,24,32,40,48,64,128}.png --raw="$tmp/256.png"
cp "$tmp/1024.png" "$here/app-icon-1024.png"
rsvg-convert -w 256 -h 256 "$assets/c-mark.svg" -o "$assets/c-mark.png"
icotool -l "$assets/app.ico"
