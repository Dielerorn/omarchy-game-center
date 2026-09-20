#!/usr/bin/env python3
"""Render the pad geometry to a PNG so the silhouette can be checked without
restarting the shell. Same coordinates that go into PadArt.js."""
import subprocess, sys

W, H = 300, 200

BODY = (
    "M 70 50 "
    "C 100 38, 200 38, 230 50 "
    "C 262 58, 281 76, 279 104 "
    "C 277 142, 262 179, 236 186 "
    "C 214 192, 202 178, 196 158 "
    "C 188 146, 170 152, 150 152 "
    "C 130 152, 112 146, 104 158 "
    "C 98 178, 86 192, 64 186 "
    "C 38 179, 23 142, 21 104 "
    "C 19 76, 38 58, 70 50 Z"
)

STICKS = [(84, 88, 20, 9), (166, 120, 19, 8)]
DPAD = (116, 128, 12, 9)
FACE = [("Y", 228, 64), ("X", 208, 84), ("B", 248, 84), ("A", 228, 104)]
SMALL = [("view", 130, 78, 6.5), ("menu", 170, 78, 6.5), ("guide", 150, 58, 11)]
BUMPERS = [(52, 34, 54, 13), (194, 34, 54, 13)]
TRIGGERS = [(60, 16, 40, 11), (200, 16, 40, 11)]

parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W*3}" height="{H*3}" viewBox="0 0 {W} {H}">',
         f'<rect width="{W}" height="{H}" fill="#1c1f26"/>']
parts.append(f'<path d="{BODY}" fill="#2a2f39" stroke="#c9c2b0" stroke-width="1.6"/>')
for x, y, w, h in TRIGGERS:
    parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{h/2}" fill="#3a4150"/>')
for x, y, w, h in BUMPERS:
    parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{h/2}" fill="#49515f"/>')
for x, y, r, travel in STICKS:
    parts.append(f'<circle cx="{x}" cy="{y}" r="{r+travel}" fill="#232832" stroke="#3a4150" stroke-width="1"/>')
    parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#6b7383"/>')
x, y, arm, th = DPAD
parts.append(f'<rect x="{x-arm}" y="{y-th/2}" width="{arm*2}" height="{th}" rx="2" fill="#49515f"/>')
parts.append(f'<rect x="{x-th/2}" y="{y-arm}" width="{th}" height="{arm*2}" rx="2" fill="#49515f"/>')
for label, x, y in FACE:
    parts.append(f'<circle cx="{x}" cy="{y}" r="12" fill="#49515f"/>')
    parts.append(f'<text x="{x}" y="{y+4}" font-size="11" font-family="monospace" fill="#e8e2d4" text-anchor="middle">{label}</text>')
for key, x, y, r in SMALL:
    parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#49515f"/>')
parts.append("</svg>")

open(sys.argv[1] + ".svg", "w").write("\n".join(parts))
subprocess.run(["magick", sys.argv[1] + ".svg", sys.argv[1]], check=True)
print("wrote", sys.argv[1])
