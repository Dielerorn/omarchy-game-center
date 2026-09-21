import QtQuick
import QtQuick.Shapes
import qs.Commons
import "PadArt.js" as Art

// A controller that lights up as you press it.
//
// The renderer knows about kinds of parts — sticks, trackpads, a d-pad, face
// buttons, bumpers, triggers, grips — and draws whichever of them the family
// declares in PadArt.js. A pad with two trackpads and one stick therefore
// needs no code here, only data.
//
// Everything scales from a 300x200 design space, so the drawing follows the
// panel width. Colours come from the theme rather than from the artwork, which
// is why it reads correctly on a light theme as well as a dark one.
Item {
  id: root

  property var state: null
  property string family: "xbox"
  property color foreground: Color.popups.text
  property color accent: Color.accent

  readonly property var art: Art.families[family] || null
  readonly property var parts: art ? art.elements : ({})
  readonly property real k: width / Art.design.width

  implicitWidth: 300
  implicitHeight: width * (Art.design.height / Art.design.width)
  height: implicitHeight
  visible: art !== null

  function pressed(name) { return state && state.b && state.b[name] === true }
  // A trackpad whose click is reported per quadrant has no single "clicked"
  // key, so the body lights when any quadrant does.
  function pressedQuadrant(quadrants) {
    if (!quadrants) return false
    for (var i = 0; i < quadrants.length; i++)
      if (root.pressed(quadrants[i].key)) return true
    return false
  }
  function axis(name) {
    if (!state || !state.a) return 0
    var v = state.a[name]
    return v === undefined ? 0 : v
  }
  function restColor(alpha) {
    return Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, alpha)
  }

  // ------------------------------------------------------------- body
  //
  // PathSvg coordinates are literal — unlike every other element here, they do
  // not go through `k` — so the Shape is laid out at design size and scaled as
  // a whole. Without this the body draws at 1:1 while the buttons sit `k`
  // times further out, which looks like wrong geometry but is a missing
  // transform.
  Shape {
    width: Art.design.width
    height: Art.design.height
    transform: Scale { xScale: root.k; yScale: root.k }
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true
    visible: root.art !== null

    ShapePath {
      strokeColor: root.restColor(0.45)
      // Divided by k because the Shape is scaled up afterwards, so a raw
      // width here would thicken on a wide panel.
      strokeWidth: Math.max(1, 1.6 / Math.max(root.k, 0.01))
      fillColor: root.restColor(0.07)
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin

      PathSvg { path: root.art ? root.art.body : "" }
    }
  }

  // ------------------------------------------------------------- triggers

  Repeater {
    model: root.parts.triggers || []

    Rectangle {
      x: modelData.x * root.k
      y: modelData.y * root.k
      width: modelData.w * root.k
      height: modelData.h * root.k
      radius: height / 2
      color: root.restColor(0.12)
      clip: true

      // Fills from the outside edge inward, the way the trigger travels.
      Rectangle {
        width: parent.width * root.axis(modelData.axis)
        height: parent.height
        anchors.right: modelData.axis === "lt" ? undefined : parent.right
        anchors.left: modelData.axis === "lt" ? parent.left : undefined
        radius: parent.radius
        color: root.accent
        Behavior on width { NumberAnimation { duration: 40 } }
      }
    }
  }

  // ------------------------------------------------------------- bumpers

  Repeater {
    model: root.parts.bumpers || []

    Rectangle {
      x: modelData.x * root.k
      y: modelData.y * root.k
      width: modelData.w * root.k
      height: modelData.h * root.k
      radius: height / 2
      color: root.pressed(modelData.key) ? root.accent : root.restColor(0.18)
      Behavior on color { ColorAnimation { duration: 60 } }
    }
  }

  // ------------------------------------------------------------- grips
  //
  // The paddles underneath a Steam Controller, and the back buttons on an
  // Elite. Drawn as soft lozenges on the grips.

  Repeater {
    model: root.parts.grips || []

    Rectangle {
      x: modelData.x * root.k
      y: modelData.y * root.k
      width: modelData.w * root.k
      height: modelData.h * root.k
      radius: Math.min(width, height) / 2
      color: root.pressed(modelData.key) ? root.accent : root.restColor(0.14)
      Behavior on color { ColorAnimation { duration: 60 } }
    }
  }

  // ------------------------------------------------------------- trackpads
  //
  // A trackpad shows the finger where it is, and lights when clicked. A pad
  // with no finger on it reports its centre, so `touch` (when the family's
  // input provides one) is what decides whether to draw the dot at all.

  Repeater {
    model: root.parts.trackpads || []

    Item {
      x: (modelData.x - modelData.r) * root.k
      y: (modelData.y - modelData.r) * root.k
      width: modelData.r * 2 * root.k
      height: width

      Rectangle {
        anchors.fill: parent
        radius: modelData.round === false ? Style.cornerRadius : width / 2
        color: (root.pressed(modelData.key) || root.pressedQuadrant(modelData.quadrants))
                 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
                 : root.restColor(0.07)
        border.width: 1
        border.color: root.restColor(0.18)
      }

      Rectangle {
        width: Math.max(6, modelData.r * 0.34) * root.k
        height: width
        radius: width / 2
        color: root.accent
        visible: modelData.touchKey === undefined || root.pressed(modelData.touchKey)
        x: (parent.width - width) / 2 + root.axis(modelData.axisX) * (parent.width - width) / 2
        y: (parent.height - height) / 2 - root.axis(modelData.axisY) * (parent.height - height) / 2
        Behavior on x { NumberAnimation { duration: 40 } }
        Behavior on y { NumberAnimation { duration: 40 } }
      }

      // Which way the pad was clicked. The driver gives the direction, so
      // showing all four the same way would throw away something true.
      Repeater {
        model: modelData.quadrants || []

        Rectangle {
          // `modelData` is the quadrant here, not the trackpad, so the size
          // comes from the parent's width (already scaled by k) rather than
          // from a `r` this object does not have.
          width: Math.max(4, parent.width * 0.08)
          height: width
          radius: width / 2
          color: root.accent
          visible: root.pressed(modelData.key)
          x: (parent.width - width) / 2 + modelData.dx * parent.width * 0.33
          y: (parent.height - height) / 2 + modelData.dy * parent.height * 0.33
        }
      }
    }
  }

  // ------------------------------------------------------------- sticks

  Repeater {
    model: root.parts.sticks || []

    Item {
      x: (modelData.x - modelData.r - modelData.travel) * root.k
      y: (modelData.y - modelData.r - modelData.travel) * root.k
      width: (modelData.r + modelData.travel) * 2 * root.k
      height: width

      // The well the stick sits in, so travel is legible.
      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.restColor(0.06)
        border.width: 1
        border.color: root.restColor(0.14)
      }

      Rectangle {
        width: modelData.r * 2 * root.k
        height: width
        radius: width / 2
        color: root.pressed(modelData.key) ? root.accent : root.restColor(0.3)
        x: (parent.width - width) / 2 + root.axis(modelData.axisX) * modelData.travel * root.k
        y: (parent.height - height) / 2 - root.axis(modelData.axisY) * modelData.travel * root.k
        Behavior on x { NumberAnimation { duration: 40 } }
        Behavior on y { NumberAnimation { duration: 40 } }
        Behavior on color { ColorAnimation { duration: 60 } }

        // A notch, so the stick reads as a stick even when centred.
        Rectangle {
          anchors.centerIn: parent
          width: parent.width * 0.45
          height: width
          radius: width / 2
          color: root.restColor(0.25)
        }
      }
    }
  }

  // ------------------------------------------------------------- d-pad

  Loader {
    active: root.parts.dpad !== undefined
    sourceComponent: Item {
      id: dpadItem
      readonly property var d: root.parts.dpad
      x: (d.x - d.arm) * root.k
      y: (d.y - d.arm) * root.k
      width: d.arm * 2 * root.k
      height: width

      Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: dpadItem.d.thickness * root.k
        radius: height / 4
        color: root.restColor(0.18)

        Rectangle {
          anchors.left: parent.left
          width: parent.width / 2
          height: parent.height
          radius: parent.radius
          color: root.axis("hx") < -0.5 ? root.accent : "transparent"
        }
        Rectangle {
          anchors.right: parent.right
          width: parent.width / 2
          height: parent.height
          radius: parent.radius
          color: root.axis("hx") > 0.5 ? root.accent : "transparent"
        }
      }

      Rectangle {
        anchors.centerIn: parent
        width: dpadItem.d.thickness * root.k
        height: parent.height
        radius: width / 4
        color: root.restColor(0.18)

        Rectangle {
          anchors.top: parent.top
          width: parent.width
          height: parent.height / 2
          radius: parent.radius
          color: root.axis("hy") < -0.5 ? root.accent : "transparent"
        }
        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: parent.height / 2
          radius: parent.radius
          color: root.axis("hy") > 0.5 ? root.accent : "transparent"
        }
      }
    }
  }

  // ------------------------------------------------------------- face buttons

  Repeater {
    model: root.parts.faceButtons || []

    Item {
      x: (modelData.x - modelData.r) * root.k
      y: (modelData.y - modelData.r) * root.k
      width: modelData.r * 2 * root.k
      height: width

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.pressed(modelData.key) ? root.accent : root.restColor(0.16)
        Behavior on color { ColorAnimation { duration: 60 } }
      }

      Text {
        anchors.centerIn: parent
        text: modelData.label
        color: root.pressed(modelData.key) ? Color.background : root.foreground
        opacity: root.pressed(modelData.key) ? 1.0 : 0.7
        font.pixelSize: Math.max(8, modelData.r * root.k)
        font.bold: true
      }
    }
  }

  // ------------------------------------------------------------- small buttons

  Repeater {
    model: root.parts.smallButtons || []

    Rectangle {
      x: (modelData.x - modelData.r) * root.k
      y: (modelData.y - modelData.r) * root.k
      width: modelData.r * 2 * root.k
      height: width
      radius: width / 2
      color: root.pressed(modelData.key) ? root.accent : root.restColor(0.16)
      Behavior on color { ColorAnimation { duration: 60 } }
    }
  }
}
