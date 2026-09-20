.pragma library

// Controller artwork, as data.
//
// Each entry in `families` is one pad family: an outline path plus the
// positions of everything on it, in a 300x200 design space that PadShape
// scales to whatever width it is given. Adding a family is adding an entry
// here — the renderer and the input pipeline do not change.
//
// `drivers` lists the sysfs driver names (underscored, as gc-pad-probe
// normalises them) that this art is correct for. A pad whose driver matches
// nothing here gets the chip-grid fallback, which is deliberate: a silhouette
// is a claim about what you are holding, and showing an Xbox outline to
// someone holding a Steam Controller is worse than showing no picture at all.
//
// `elements` may contain any of: sticks, trackpads, dpad, faceButtons,
// bumpers, triggers, smallButtons, grips. Leave out what the pad does not
// have; PadShape draws only what is present. That is how a pad with two
// trackpads and one stick coexists with one that has two sticks and a d-pad.
//
// Every coordinate here was checked by rendering it — see
// tools/pad-preview.py, and docs/ADDING-A-CONTROLLER.md for the whole
// procedure. Do not place parts by eye in code; render them.

var design = { width: 300, height: 200 }

var families = {

  // ------------------------------------------------------------------ xbox
  //
  // Verified against an Xbox One S pad on xone, over the wireless adapter.
  xbox: {
    label: "Xbox",
    drivers: ["xone_gip_gamepad", "hid_xpadneo", "xpad"],

    // Two grips descending from a rounded top shell, with a shallow saddle
    // between them. The saddle is deliberately low: a higher one left no room
    // for the right stick, which then poked through the bottom edge.
    body:
      "M 70 50 " +
      "C 100 38, 200 38, 230 50 " +
      "C 262 58, 281 76, 279 104 " +
      "C 277 142, 262 179, 236 186 " +
      "C 214 192, 202 178, 196 158 " +
      "C 188 146, 170 152, 150 152 " +
      "C 130 152, 112 146, 104 158 " +
      "C 98 178, 86 192, 64 186 " +
      "C 38 179, 23 142, 21 104 " +
      "C 19 76, 38 58, 70 50 Z",

    elements: {
      // Y north, A south, X west, B east. The letters do not follow the
      // compass — that mismatch is the same one that transposed the button
      // map, and tests/run.sh asserts the drawing agrees with the input.
      faceButtons: [
        { key: "y", label: "Y", x: 228, y: 64, r: 12 },
        { key: "x", label: "X", x: 208, y: 84, r: 12 },
        { key: "b", label: "B", x: 248, y: 84, r: 12 },
        { key: "a", label: "A", x: 228, y: 104, r: 12 }
      ],

      // Left stick high on the left, right stick low and central — the
      // asymmetry that makes an Xbox pad read as an Xbox pad at a glance.
      sticks: [
        { key: "ls", axisX: "lx", axisY: "ly", x: 84, y: 88, r: 20, travel: 9 },
        { key: "rs", axisX: "rx", axisY: "ry", x: 166, y: 120, r: 19, travel: 8 }
      ],

      dpad: { x: 116, y: 128, arm: 12, thickness: 9 },

      bumpers: [
        { key: "lb", x: 52, y: 34, w: 54, h: 13 },
        { key: "rb", x: 194, y: 34, w: 54, h: 13 }
      ],

      // Triggers sit behind the bumpers and fill as they are pulled.
      triggers: [
        { axis: "lt", x: 60, y: 16, w: 40, h: 11 },
        { axis: "rt", x: 200, y: 16, w: 40, h: 11 }
      ],

      smallButtons: [
        { key: "view", x: 130, y: 78, r: 6.5 },
        { key: "menu", x: 170, y: 78, r: 6.5 },
        { key: "guide", x: 150, y: 58, r: 11 }
      ]
    }
  },

  // ---------------------------------------------------------------- steam
  //
  // Steam Controller (2015), on the in-kernel hid-steam driver.
  //
  // Drawn from Valve's documented layout and the driver's own comments; NOT
  // yet checked against hardware. docs/STEAM-CONTROLLER.md lists what to
  // confirm with a pad in hand.
  //
  // Structurally unlike an Xbox pad, which is why the renderer takes a list of
  // parts rather than assuming two sticks: one analog stick, two clickable
  // trackpads, and the ABXY diamond sits *below* the right pad rather than
  // where a right stick would be.
  steam: {
    label: "Steam Controller",
    drivers: ["hid_steam"],

    // Wider and flatter than an Xbox pad, with longer handles splayed further
    // out — they hold two AA cells.
    body:
      "M 60 46 " +
      "C 95 36, 205 36, 240 46 " +
      "C 272 54, 289 76, 287 104 " +
      "C 285 136, 274 168, 258 186 " +
      "C 246 198, 228 196, 219 180 " +
      "C 211 166, 200 162, 186 164 " +
      "C 170 167, 130 167, 114 164 " +
      "C 100 162, 89 166, 81 180 " +
      "C 72 196, 54 198, 42 186 " +
      "C 26 168, 15 136, 13 104 " +
      "C 11 76, 28 54, 60 46 Z",

    elements: {
      // The two round pads dominate the face. The left one doubles as the
      // d-pad: its click is reported as a quadrant (padup/paddown/...) and
      // never as "the pad was clicked", so it has no single click key. It
      // declares `quadrants` instead — the pad lights when any of them is
      // pressed, and a marker shows which. Binding `key` to one of the four,
      // as this did, leaves the other three lighting nothing at all.
      //
      // The finger dot only appears while the pad is actually touched,
      // because an untouched pad reports its centre.
      trackpads: [
        { touchKey: "lpadtouch", axisX: "hx", axisY: "hy",
          x: 80, y: 82, r: 28,
          quadrants: [
            { key: "padup",    dx:  0, dy: -1 },
            { key: "paddown",  dx:  0, dy:  1 },
            { key: "padleft",  dx: -1, dy:  0 },
            { key: "padright", dx:  1, dy:  0 }
          ] },
        { key: "rs", touchKey: "rpadtouch", axisX: "rx", axisY: "ry",
          x: 220, y: 82, r: 28 }
      ],

      // One stick, low on the left, roughly where an Xbox pad keeps its d-pad.
      sticks: [
        { key: "ls", axisX: "lx", axisY: "ly", x: 112, y: 134, r: 15, travel: 6 }
      ],

      // Xbox letters and Xbox positions — Valve matched them deliberately —
      // but sitting below the right trackpad rather than up where an Xbox
      // pad's cluster is.
      faceButtons: [
        { key: "y", label: "Y", x: 190, y: 118, r: 9 },
        { key: "x", label: "X", x: 174, y: 134, r: 9 },
        { key: "b", label: "B", x: 206, y: 134, r: 9 },
        { key: "a", label: "A", x: 190, y: 150, r: 9 }
      ],

      bumpers: [
        { key: "lb", x: 40, y: 32, w: 58, h: 12 },
        { key: "rb", x: 202, y: 32, w: 58, h: 12 }
      ],

      triggers: [
        { axis: "lt", x: 50, y: 14, w: 44, h: 11 },
        { axis: "rt", x: 206, y: 14, w: 44, h: 11 }
      ],

      // The rear paddles. They are on the back of the handles and invisible
      // from the front, so they are drawn as markers on the grips — the point
      // is to show them being pressed, not to be architecturally accurate.
      grips: [
        { key: "lgrip", x: 48, y: 150, w: 24, h: 9 },
        { key: "rgrip", x: 228, y: 150, w: 24, h: 9 }
      ],

      // Steam button dead centre, Back and Forward flanking it.
      smallButtons: [
        { key: "guide", x: 150, y: 120, r: 11 },
        { key: "view", x: 126, y: 104, r: 6 },
        { key: "menu", x: 174, y: 104, r: 6 }
      ]
    }
  }

  // ---------------------------------------------------------------- others
  //
  // A DualSense or a Switch Pro goes here as another entry. See
  // docs/ADDING-A-CONTROLLER.md — the short version is: measure the pad's real
  // button codes, add its capabilities to gc-pad-probe, add its art here, and
  // render it with tools/pad-preview.py before trusting it.
}

// Which family's art to use for a driver, or "" for the chip-grid fallback.
function familyFor(driver) {
  for (var name in families) {
    if (families[name].drivers.indexOf(driver) >= 0) return name
  }
  return ""
}
