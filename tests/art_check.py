#!/usr/bin/env python3
"""Structural checks on every controller family in PadArt.js.

These exist because the ways art goes wrong are not visual: a part placed
outside the canvas, a family whose art lights a button the streamer never
reports, or face buttons transposed against the input map. Each of those looks
plausible in the file and wrong on screen.

Run by tests/run.sh; also useful directly while adding a family.
"""
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from importlib.machinery import SourceFileLoader

preview = SourceFileLoader("preview", str(ROOT / "tools" / "pad-preview.py")).load_module()

DESIGN_W, DESIGN_H = 300, 200

failures = []


def check(condition, message):
    if not condition:
        failures.append(message)


def families():
    src = (ROOT / "controllers" / "PadArt.js").read_text()
    names = re.findall(r"^  ([a-z][A-Za-z0-9_]*): \{", src, re.M)
    return {n: preview.load(n) for n in names}


def known_button_keys():
    """The button names bin/gc-pads can actually emit."""
    src = (ROOT / "bin" / "gc-pads").read_text()
    block = re.search(r"BUTTONS = \{(.*?)\}", src, re.S).group(1)
    return set(re.findall(r'"(\w+)"', block))


def known_axis_keys():
    src = (ROOT / "bin" / "gc-pads").read_text()
    block = re.search(r"AXES = \{(.*?)\}", src, re.S).group(1)
    return set(re.findall(r'"(\w+)"', block))


buttons = known_button_keys()
axes = known_axis_keys()

for name, art in families().items():
    check("body" in art and art["body"].strip().startswith("M"),
          f"{name}: body must be an SVG path starting with M")
    check(isinstance(art.get("drivers"), list) and art["drivers"],
          f"{name}: needs a non-empty drivers list")
    for driver in art.get("drivers", []):
        check("-" not in driver,
              f"{name}: driver '{driver}' must use underscores, as gc-pad-probe normalises them")

    elements = art.get("elements", {})
    check(bool(elements), f"{name}: has no elements")

    for kind, items in elements.items():
        items = items if isinstance(items, list) else [items]
        for item in items:
            label = f"{name}.{kind}[{item.get('key', item.get('axis', '?'))}]"

            # Every key the art lights must be something the streamer reports,
            # or it is a part that can never light up.
            if "key" in item:
                check(item["key"] in buttons,
                      f"{label}: key '{item['key']}' is not emitted by gc-pads")

            # A trackpad clicked by quadrant lights these instead of `key`.
            # They need the same check, or a typo here is a direction that can
            # never light up — which is exactly how a d-pad ended up bound to
            # `padup` alone, with the other three quadrants dead.
            for quadrant in item.get("quadrants", []):
                check(quadrant.get("key") in buttons,
                      f"{label}: quadrant key '{quadrant.get('key')}' "
                      "is not emitted by gc-pads")
                check(quadrant.get("dx") in (-1, 0, 1)
                      and quadrant.get("dy") in (-1, 0, 1)
                      and (quadrant.get("dx"), quadrant.get("dy")) != (0, 0),
                      f"{label}: quadrant '{quadrant.get('key')}' needs a "
                      "direction, as dx/dy in -1..1 and not both zero")
            for axis_field in ("axisX", "axisY", "axis"):
                if axis_field in item:
                    check(item[axis_field] in axes,
                          f"{label}: axis '{item[axis_field]}' is not emitted by gc-pads")

            # Anything drawn outside the design space is off the canvas.
            x, y = item.get("x"), item.get("y")
            if x is None or y is None:
                continue
            reach = item.get("r", 0) + item.get("travel", 0)
            w, h = item.get("w", 0), item.get("h", 0)
            check(-1 <= x - reach and x + max(reach, w) <= DESIGN_W + 1,
                  f"{label}: sits outside the {DESIGN_W}-wide design space")
            check(-1 <= y - reach and y + max(reach, h) <= DESIGN_H + 1,
                  f"{label}: sits outside the {DESIGN_H}-tall design space")

    # Face buttons labelled A/B/X/Y must match the physical layout the button
    # map assumes: Y north, A south, X west, B east. The letters do not follow
    # the compass, and getting it wrong draws a pad that disagrees with itself.
    face = {f["label"].upper(): (f["x"], f["y"])
            for f in elements.get("faceButtons", []) if "label" in f}
    if {"A", "B", "X", "Y"} <= set(face):
        check(face["Y"][1] < face["A"][1], f"{name}: Y must sit above A")
        check(face["X"][0] < face["B"][0], f"{name}: X must sit left of B")
        check(face["X"][0] < face["Y"][0] < face["B"][0],
              f"{name}: Y must sit between X and B horizontally")

for message in failures:
    print(message, file=sys.stderr)
sys.exit(1 if failures else 0)
