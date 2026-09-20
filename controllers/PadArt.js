.pragma library

// Original geometry for an Xbox-style pad, drawn from measurements of the
// real thing rather than traced from anyone's artwork.
//
// Coordinates are in a 300x200 design space; PadShape scales them to whatever
// width it is given. Keeping the art as plain data means a different pad
// family can be added later — a DualSense has its sticks side by side and its
// face buttons in a diamond of shapes rather than letters — without touching
// the rendering or the input wiring.
//
// The outline is deliberately simple. At panel size, detail turns to mush and
// what matters is that the thing reads as "a controller" at a glance and that
// each part is in the place your thumb expects.

var design = { width: 300, height: 200 }

// Body: two grips descending from a rounded top shell.
var body =
  "M 66 44" +
  "C 40 44, 22 60, 16 92" +
  "C 8 132, 18 176, 44 186" +
  "C 66 194, 86 176, 100 150" +
  "C 110 132, 122 124, 150 124" +
  "C 178 124, 190 132, 200 150" +
  "C 214 176, 234 194, 256 186" +
  "C 282 176, 292 132, 284 92" +
  "C 278 60, 260 44, 234 44" +
  "Z"

// The four face buttons, in their true Xbox positions: Y north, A south,
// X west, B east. Getting this wrong on the picture would be the same bug the
// button map already had, just visible.
var faceButtons = [
  { key: "y", label: "Y", x: 228, y: 62, r: 12 },
  { key: "x", label: "X", x: 206, y: 84, r: 12 },
  { key: "b", label: "B", x: 250, y: 84, r: 12 },
  { key: "a", label: "A", x: 228, y: 106, r: 12 }
]

var sticks = [
  { key: "ls", axisX: "lx", axisY: "ly", x: 78, y: 78, r: 21, travel: 9 },
  { key: "rs", axisX: "rx", axisY: "ry", x: 182, y: 132, r: 21, travel: 9 }
]

// Eight-way pad drawn as a plus.
var dpad = { x: 118, y: 132, arm: 11, thickness: 9 }

var bumpers = [
  { key: "lb", x: 52, y: 30, w: 52, h: 13 },
  { key: "rb", x: 196, y: 30, w: 52, h: 13 }
]

// Triggers sit behind the bumpers and fill as they are pulled.
var triggers = [
  { axis: "lt", x: 58, y: 12, w: 40, h: 11 },
  { axis: "rt", x: 202, y: 12, w: 40, h: 11 }
]

var smallButtons = [
  { key: "view", x: 128, y: 82, r: 7 },
  { key: "menu", x: 172, y: 82, r: 7 },
  { key: "guide", x: 150, y: 58, r: 11 }
]
