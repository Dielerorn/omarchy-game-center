import QtQuick
import qs.Commons

// Battery as five segments, or as a percentage when the driver actually has
// one.
//
// This exists because Xbox pads on `xone` report CAPACITY_LEVEL and nothing
// else — five buckets, Unknown through Full, with no percentage anywhere in
// the driver. Every tool that shows "72%" for one of these pads made that
// number up. Five segments is the honest rendering of five buckets, and a
// DualSense, which does report a real percentage, gets the number instead.
Row {
  id: root

  // "level" (5 buckets), "percent", or "none"
  property string kind: "none"
  property string level: ""
  property int percent: -1
  property string status: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  spacing: Style.spacing.xxs

  readonly property int filled: {
    if (kind === "percent" && percent >= 0)
      return Math.max(1, Math.ceil(percent / 20))
    switch (level) {
      case "Full": return 5
      case "High": return 4
      case "Normal": return 3
      case "Low": return 1
      default: return 0
    }
  }

  readonly property bool low: filled === 1 || (kind === "percent" && percent >= 0 && percent <= 15)
  readonly property bool charging: status === "Charging"

  Repeater {
    model: root.kind === "level" ? 5 : 0

    Rectangle {
      width: Style.space(7)
      height: Style.space(12)
      radius: Style.space(2)
      color: index < root.filled
        ? (root.low ? Color.urgent : root.foreground)
        : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
    }
  }

  Text {
    visible: root.kind === "percent" && root.percent >= 0
    text: root.percent + "%"
    color: root.low ? Color.urgent : root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Text {
    // "Unknown" is a real answer from the driver, not a failure: a pad that has
    // just connected reports it until the first battery packet arrives.
    visible: root.kind === "level" && root.filled === 0
    text: "unknown"
    color: root.foreground
    opacity: 0.5
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Text {
    visible: root.charging
    text: "󰂄"
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
