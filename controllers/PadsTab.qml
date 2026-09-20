import QtQuick
import qs.Commons
import qs.Ui
import "../ui"

// The Pads tab.
//
// Rule for this whole tab: a control that cannot work is absent, not disabled.
// Xbox pads differ from DualSense in what Linux exposes, and they differ from
// each other depending on whether they came in over the dongle, a cable or
// Bluetooth — so the probe computes capabilities per pad and every control here
// is bound to one of them.
//
// The things deliberately not here: a deadzone slider (no Linux Xbox driver
// has deadzone control; that lives in Steam Input or the game) and a battery
// percentage for pads whose driver only reports five levels.
Column {
  id: root

  property var pads: null
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  spacing: Style.spacing.md

  readonly property bool ready: pads !== null
  readonly property int count: ready ? pads.padCount : 0
  readonly property var dongle: ready ? pads.dongle : null

  // --------------------------------------------------------- empty state

  GcEmptyState {
    width: parent.width
    visible: root.count === 0
    glyph: "󰊴"
    title: "No controllers connected"
    detail: {
      if (!root.ready) return ""
      if (root.dongle)
        return "An Xbox Wireless Adapter is plugged in. Turn on a controller, "
             + "or use Pair below to connect a new one."
      if ((root.pads.drivers || []).length > 0)
        return "Drivers loaded: " + root.pads.drivers.join(", ") + "."
      return "Plug in a controller, or turn one on."
    }
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  // --------------------------------------------------------- the pads

  Repeater {
    model: root.ready ? root.pads.pads : []

    Column {
      width: parent.width
      spacing: Style.spacing.xs

      Row {
        width: parent.width
        spacing: Style.spacing.md

        Column {
          width: parent.width - battery.width - Style.spacing.md
          spacing: Style.spacing.xxs

          Text {
            width: parent.width
            elide: Text.ElideRight
            text: modelData.name
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.connectionText(modelData) + " · " + modelData.driver
            color: root.foreground
            opacity: 0.55
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        BatterySegments {
          id: battery
          anchors.verticalCenter: parent.verticalCenter
          kind: modelData.caps.batteryKind
          level: modelData.battery && modelData.battery.level ? modelData.battery.level : ""
          percent: modelData.battery && modelData.battery.percent !== null
            ? modelData.battery.percent : -1
          status: modelData.battery && modelData.battery.status ? modelData.battery.status : ""
          foreground: root.foreground
          fontFamily: root.fontFamily
          visible: modelData.caps.batteryKind !== "none"
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: modelData.caps.batteryKind === "none"
          text: modelData.connection === "usb" ? "wired" : "no battery"
          color: root.foreground
          opacity: 0.45
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Row {
        spacing: Style.spacing.sm

        Button {
          visible: modelData.caps.rumble && modelData.nodeWritable
          text: "Test rumble"
          bordered: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: if (root.ready) root.pads.rumble(modelData.node, 70, 40, 600)
        }

        Button {
          // The LED is real on xone and root-owned, so this appears only once
          // the udev rule has made it writable.
          visible: modelData.caps.led && modelData.led && modelData.led.writable
          text: "Blink light"
          bordered: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: if (root.ready) root.pads.blinkLed(modelData.led.path,
                                                        modelData.led.brightness,
                                                        modelData.led.max)
        }
      }

      // Live input is only streamed for the pad whose view is open: one
      // controller's worth of events is plenty, and nobody watches two.
      Toggle {
        width: parent.width
        label: "Show live input"
        description: root.ready && root.pads.streamError !== ""
          ? root.pads.streamError
          : "every button and stick, as you press them"
        checked: root.ready && root.pads.streamNode === modelData.node
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: {
          if (!root.ready) return
          if (root.pads.streamNode === modelData.node) root.pads.stopStream()
          else root.pads.startStream(modelData.node)
        }
      }

      PadInputView {
        width: parent.width
        visible: root.ready && root.pads.streamNode === modelData.node
        state: root.ready ? root.pads.padState : null
        driver: modelData.driver
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      GcDegradedRow {
        width: parent.width
        visible: modelData.caps.led && modelData.led && !modelData.led.writable
        message: "The guide-button light needs a one-time udev rule before it can be changed."
        actionText: "Show me"
        foreground: root.foreground
        fontFamily: root.fontFamily
        onActivated: if (root.ready) root.pads.showLedHelp()
      }

      PanelSeparator { width: parent.width }
    }
  }

  // --------------------------------------------------------- dongle

  Column {
    width: parent.width
    visible: root.dongle !== null
    spacing: Style.spacing.xs

    PanelSectionHeader {
      width: parent.width
      text: "Xbox Wireless Adapter"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.foreground
      opacity: 0.55
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      text: {
        if (!root.dongle) return ""
        if (root.dongle.pairing) return "Pairing — hold the button on the controller."
        var n = root.dongle.activeClients
        return (n === 0 || n === null ? "No controllers" : n + " connected") + " on the adapter."
      }
    }

    Button {
      visible: root.dongle && root.dongle.writable && !root.dongle.pairing
      text: "Pair a controller"
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: if (root.ready) root.pads.startPairing()
    }

    GcDegradedRow {
      width: parent.width
      visible: root.dongle && !root.dongle.writable
      message: "Pairing from here needs a one-time udev rule. Without it, pairing still "
             + "works the usual way: press the button on the adapter, then on the controller."
      actionText: "Show me"
      foreground: root.foreground
      fontFamily: root.fontFamily
      onActivated: if (root.ready) root.pads.showPairHelp()
    }
  }

  // --------------------------------------------------------- footer

  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    visible: text !== ""
    color: root.foreground
    opacity: 0.5
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    text: {
      if (!root.ready) return "starting…"
      if (root.pads.error !== "") return root.pads.error
      if (root.count === 0) return ""
      // Said once, at the bottom, rather than as a slider that would not work.
      return "Stick deadzones are set per game — in Steam Input, or the game's own settings."
    }
  }

  function connectionText(pad) {
    switch (pad.connection) {
      case "usb": return "wired"
      case "dongle": return "wireless adapter"
      case "bluetooth": return "bluetooth"
      default: return "connected"
    }
  }
}
