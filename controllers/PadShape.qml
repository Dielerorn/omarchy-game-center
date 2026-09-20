import QtQuick
import QtQuick.Shapes
import qs.Commons
import "PadArt.js" as Art

// A controller that lights up as you press it.
//
// Everything scales from a 300x200 design space, so the drawing is resolution
// independent and follows the panel width. Colours come from the theme rather
// than from the artwork, which is why this reads correctly on a light theme as
// well as a dark one.
Item {
  id: root

  property var state: null
  property color foreground: Color.popups.text
  property color accent: Color.accent

  readonly property real k: width / Art.design.width

  implicitWidth: 300
  implicitHeight: width * (Art.design.height / Art.design.width)
  height: implicitHeight

  function pressed(name) { return state && state.b && state.b[name] === true }
  function axis(name) {
    if (!state || !state.a) return 0
    var v = state.a[name]
    return v === undefined ? 0 : v
  }

  // Idle colour for a part, so every element dims the same way.
  function restColor(alpha) {
    return Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, alpha)
  }

  // ------------------------------------------------------------- body

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true

    ShapePath {
      strokeColor: root.restColor(0.45)
      strokeWidth: Math.max(1, 1.6 * root.k)
      fillColor: root.restColor(0.07)
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin

      PathSvg { path: Art.body }
    }
  }

  // ------------------------------------------------------------- triggers

  Repeater {
    model: Art.triggers

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
    model: Art.bumpers

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

  // ------------------------------------------------------------- sticks

  Repeater {
    model: Art.sticks

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

        // A notch so rotation is visible even when the stick is centred.
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

  Item {
    x: (Art.dpad.x - Art.dpad.arm) * root.k
    y: (Art.dpad.y - Art.dpad.arm) * root.k
    width: Art.dpad.arm * 2 * root.k
    height: width

    Rectangle {
      anchors.centerIn: parent
      width: parent.width
      height: Art.dpad.thickness * root.k
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
      width: Art.dpad.thickness * root.k
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

  // ------------------------------------------------------------- face buttons

  Repeater {
    model: Art.faceButtons

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
    model: Art.smallButtons

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
