#!/usr/bin/env python3
"""Render a controller family from PadArt.js to a PNG.

    tools/pad-preview.py xbox out.png

Placing parts by eye in QML means a shell restart per attempt and a screenshot
to judge it. This reads the same PadArt.js the plugin does and draws it through
a plain SVG, so geometry can be iterated in a second.

It is also how you tell the two failure modes apart: if the PNG looks right and
the panel does not, the bug is in the rendering, not the coordinates.
"""
import json, re, subprocess, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "controllers" / "PadArt.js"


def load(family):
    """Pull one family out of PadArt.js without a JS engine.

    The file is JS, not JSON, so this strips comments and quotes the keys. It
    is a preview tool, not a parser — if it chokes on something you added, fix
    the tool rather than contorting the art.
    """
    src = ART.read_text()
    src = re.sub(r"//[^\n]*", "", src)
    start = src.index("var families")
    body = src[src.index("{", start):]
    depth, end = 0, None
    for i, ch in enumerate(body):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    text = body[:end]
    text = re.sub(r'"\s*\+\s*\n?\s*"', "", text)          # joined path strings
    text = re.sub(r"([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:", r'\1"\2":', text)
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    families = json.loads(text)
    if family not in families:
        sys.exit("no such family: %s (have: %s)" % (family, ", ".join(families)))
    return families[family]


def render(art, out):
    W, H = 300, 200
    e = art.get("elements", {})
    p = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W*3}" height="{H*3}" viewBox="0 0 {W} {H}">',
         f'<rect width="{W}" height="{H}" fill="#1c1f26"/>',
         f'<path d="{art["body"]}" fill="#2a2f39" stroke="#c9c2b0" stroke-width="1.6"/>']

    for t in e.get("triggers", []):
        p.append(f'<rect x="{t["x"]}" y="{t["y"]}" width="{t["w"]}" height="{t["h"]}" rx="{t["h"]/2}" fill="#3a4150"/>')
    for b in e.get("bumpers", []) + e.get("grips", []):
        p.append(f'<rect x="{b["x"]}" y="{b["y"]}" width="{b["w"]}" height="{b["h"]}" rx="{min(b["w"],b["h"])/2}" fill="#49515f"/>')
    for tp in e.get("trackpads", []):
        rx = "8" if tp.get("round") is False else str(tp["r"])
        p.append(f'<rect x="{tp["x"]-tp["r"]}" y="{tp["y"]-tp["r"]}" width="{tp["r"]*2}" height="{tp["r"]*2}" rx="{rx}" fill="#232832" stroke="#3a4150"/>')
    for s in e.get("sticks", []):
        p.append(f'<circle cx="{s["x"]}" cy="{s["y"]}" r="{s["r"]+s["travel"]}" fill="#232832" stroke="#3a4150"/>')
        p.append(f'<circle cx="{s["x"]}" cy="{s["y"]}" r="{s["r"]}" fill="#6b7383"/>')
    if "dpad" in e:
        d = e["dpad"]
        p.append(f'<rect x="{d["x"]-d["arm"]}" y="{d["y"]-d["thickness"]/2}" width="{d["arm"]*2}" height="{d["thickness"]}" rx="2" fill="#49515f"/>')
        p.append(f'<rect x="{d["x"]-d["thickness"]/2}" y="{d["y"]-d["arm"]}" width="{d["thickness"]}" height="{d["arm"]*2}" rx="2" fill="#49515f"/>')
    for f in e.get("faceButtons", []):
        p.append(f'<circle cx="{f["x"]}" cy="{f["y"]}" r="{f["r"]}" fill="#49515f"/>')
        p.append(f'<text x="{f["x"]}" y="{f["y"]+4}" font-size="11" font-family="monospace" fill="#e8e2d4" text-anchor="middle">{f["label"]}</text>')
    for s in e.get("smallButtons", []):
        p.append(f'<circle cx="{s["x"]}" cy="{s["y"]}" r="{s["r"]}" fill="#49515f"/>')
    p.append("</svg>")

    svg = out + ".svg"
    pathlib.Path(svg).write_text("\n".join(p))
    subprocess.run(["magick", svg, out], check=True)
    print("wrote", out)


if __name__ == "__main__":
    family = sys.argv[1] if len(sys.argv) > 1 else "xbox"
    out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/pad-%s.png" % family
    render(load(family), out)
