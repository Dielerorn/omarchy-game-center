.pragma library

// Original geometry for an Xbox-style pad, drawn from measurements of the real
// thing rather than traced from anyone's artwork.
//
// Coordinates are in a 300x200 design space; PadShape scales them to whatever
// width it is given. Keeping the art as plain data means a different pad family
// can be added later — a DualSense has its sticks side by side and its face
// buttons as shapes rather than letters — without touching the rendering or the
// input wiring.
//
// Every element was placed against a rendered outline rather than by eye in
// code: scratch/pad.py in the history draws this same data to a PNG, which is
// how the first version's collisions (d-pad straddling the bottom edge, right
// stick under the X button) were found. If these numbers are edited, render
// them before trusting them.

var design = { width: 300, height: 200 }

// Two grips descending from a rounded top shell, with a shallow saddle between
// them. The saddle is deliberately low: an earlier, higher one left no room for
// the right stick, which then poked through the bottom edge.
var body =
  "M 70 50 " +
  "C 100 38, 200 38, 230 50 " +
  "C 262 58, 281 76, 279 104 " +
  "C 277 142, 262 179, 236 186 " +
  "C 214 192, 202 178, 196 158 " +
  "C 188 146, 170 152, 150 152 " +
  "C 130 152, 112 146, 104 158 " +
  "C 98 178, 86 192, 64 186 " +
  "C 38 179, 23 142, 21 104 " +
  "C 19 76, 38 58, 70 50 Z"

// The four face buttons in their true Xbox positions: Y north, A south,
// X west, B east. The letters do not follow the compass — that mismatch is the
// same one that transposed the button map, and tests/run.sh asserts this
// agrees with it.
var faceButtons = [
  { key: "y", label: "Y", x: 228, y: 64, r: 12 },
  { key: "x", label: "X", x: 208, y: 84, r: 12 },
  { key: "b", label: "B", x: 248, y: 84, r: 12 },
  { key: "a", label: "A", x: 228, y: 104, r: 12 }
]

// Left stick high on the left, right stick low and central — the asymmetry
// that makes an Xbox pad read as an Xbox pad at a glance.
var sticks = [
  { key: "ls", axisX: "lx", axisY: "ly", x: 84, y: 88, r: 20, travel: 9 },
  { key: "rs", axisX: "rx", axisY: "ry", x: 166, y: 120, r: 19, travel: 8 }
]

var dpad = { x: 116, y: 128, arm: 12, thickness: 9 }

var bumpers = [
  { key: "lb", x: 52, y: 34, w: 54, h: 13 },
  { key: "rb", x: 194, y: 34, w: 54, h: 13 }
]

// Triggers sit behind the bumpers and fill as they are pulled.
var triggers = [
  { axis: "lt", x: 60, y: 16, w: 40, h: 11 },
  { axis: "rt", x: 200, y: 16, w: 40, h: 11 }
]

var smallButtons = [
  { key: "view", x: 130, y: 78, r: 6.5 },
  { key: "menu", x: 170, y: 78, r: 6.5 },
  { key: "guide", x: 150, y: 58, r: 11 }
]
