import QtQuick
import qs.Commons
import qs.Ui

// Live input: lit chips for the buttons, a box with a dot per stick, a bar per
// trigger.
//
// Chips rather than a drawn controller silhouette, on purpose for now. A
// silhouette is prettier but only honest for the pad it was drawn as, and the
// moment someone connects a DualSense or a Switch Pro it is showing them a
// picture of the wrong hardware. Chips are correct for anything and legible at
// panel size; PadArt can arrive later behind the same data.
Column {
  id: root

  property var state: null          // { b: {...}, a: {...} }
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  spacing: Style.spacing.sm

  function pressed(name) {
    return state && state.b && state.b[name] === true
  }

  function axis(name) {
    if (!state || !state.a) return 0
    var v = state.a[name]
    return v === undefined ? 0 : v
  }

  // --------------------------------------------------------- sticks

  Row {
    width: parent.width
    spacing: Style.spacing.md

    Repeater {
      model: [
        { x: "lx", y: "ly", click: "ls", label: "L" },
        { x: "rx", y: "ry", click: "rs", label: "R" }
      ]

      Rectangle {
        width: Style.space(64)
        height: Style.space(64)
        radius: Style.cornerRadius
        color: root.pressed(modelData.click)
          ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
          : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
        border.width: 1
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)

        // Crosshair, so a centred stick still reads as centred.
        Rectangle {
          anchors.centerIn: parent
          width: parent.width - Style.space(10)
          height: 1
          color: root.foreground
          opacity: 0.12
        }
        Rectangle {
          anchors.centerIn: parent
          width: 1
          height: parent.height - Style.space(10)
          color: root.foreground
          opacity: 0.12
        }

        Rectangle {
          width: Style.space(12)
          height: width
          radius: width / 2
          color: Color.accent
          x: parent.width / 2 - width / 2 + root.axis(modelData.x) * (parent.width / 2 - width)
          y: parent.height / 2 - height / 2 - root.axis(modelData.y) * (parent.height / 2 - height)
          Behavior on x { NumberAnimation { duration: 40 } }
          Behavior on y { NumberAnimation { duration: 40 } }
        }

        Text {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.margins: Style.spacing.xs
          text: modelData.label
          color: root.foreground
          opacity: 0.4
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }

    // --------------------------------------------------------- triggers

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.sm

      Repeater {
        model: [{ a: "lt", label: "LT" }, { a: "rt", label: "RT" }]

        Row {
          spacing: Style.spacing.xs

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.label
            color: root.foreground
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(90)
            height: Style.space(10)
            radius: height / 2
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

            Rectangle {
              width: parent.width * root.axis(modelData.a)
              height: parent.height
              radius: parent.radius
              color: Color.accent
              Behavior on width { NumberAnimation { duration: 40 } }
            }
          }
        }
      }
    }
  }

  // --------------------------------------------------------- buttons

  Flow {
    width: parent.width
    spacing: Style.spacing.xs

    Repeater {
      model: [
        { k: "a", t: "A" }, { k: "b", t: "B" }, { k: "x", t: "X" }, { k: "y", t: "Y" },
        { k: "lb", t: "LB" }, { k: "rb", t: "RB" },
        { k: "view", t: "View" }, { k: "menu", t: "Menu" }, { k: "guide", t: "Guide" }
      ]

      Rectangle {
        width: Math.max(Style.space(26), label.implicitWidth + Style.spacing.md)
        height: Style.space(22)
        radius: Style.cornerRadius
        color: root.pressed(modelData.k) ? Color.accent
                                         : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

        Text {
          id: label
          anchors.centerIn: parent
          text: modelData.t
          color: root.pressed(modelData.k) ? Color.background : root.foreground
          opacity: root.pressed(modelData.k) ? 1.0 : 0.65
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  // --------------------------------------------------------- d-pad

  Row {
    spacing: Style.spacing.xs

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "D-pad"
      color: root.foreground
      opacity: 0.5
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Repeater {
      model: [
        { t: "←", on: root.axis("hx") < -0.5 },
        { t: "→", on: root.axis("hx") > 0.5 },
        { t: "↑", on: root.axis("hy") < -0.5 },
        { t: "↓", on: root.axis("hy") > 0.5 }
      ]

      Rectangle {
        width: Style.space(22)
        height: Style.space(22)
        radius: Style.cornerRadius
        color: modelData.on ? Color.accent
                            : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

        Text {
          anchors.centerIn: parent
          text: modelData.t
          color: modelData.on ? Color.background : root.foreground
          opacity: modelData.on ? 1.0 : 0.65
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
