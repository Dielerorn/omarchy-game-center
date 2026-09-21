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

  // Plugged in, but handed to a program that opened it directly. These have no
  // input node, so they get a sentence in the empty state rather than a row
  // with controls that could not work.
  readonly property var claimed: ready ? (pads.claimed || []) : []
  readonly property var claimedFirst: claimed.length > 0 ? claimed[0] : null

  // --------------------------------------------------------- empty state

  GcEmptyState {
    width: parent.width
    visible: root.count === 0
    glyph: "󰊴"
    title: {
      if (root.claimedFirst === null) return "No controllers connected"
      if (root.claimed.length > 1) return root.claimed.length + " controllers are in use"
      // An adapter is held by Steam whether or not a controller is switched
      // on, so claim only what is known: the adapter, not a controller.
      if (root.claimedFirst.connection === "dongle")
        return root.claimedFirst.name + " adapter is in use"
      return root.claimedFirst.name + " is in use"
    }
    detail: {
      if (!root.ready) return ""

      // A controller that is plugged in but claimed is the most specific thing
      // we can say, so it wins over the driver list. Naming the program is the
      // point: "Steam is using this controller" is the guess everyone makes,
      // and it is wrong whenever a Proton game holds it with Steam closed.
      if (root.claimedFirst !== null) {
        var c = root.claimedFirst
        var who = (c.holder && c.holder.name) ? c.holder.name : "another program"
        var subject = c.connection === "dongle"
              ? "Its wireless adapter is open in "
              : "It is open in "
        if (root.claimed.length > 1) subject = "They are open in "
        if (c.connection === "dongle" && root.claimed.length === 1)
          return subject + who + ", which takes over any controller paired to "
               + "it — they report there instead of to the system. Close that "
               + "program and they come back."
        return subject + who + ", which takes the controller over completely — "
             + "it reports there instead of to the system. Close that program "
             + "and the controller comes back."
      }

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
            text: root.padSubtitle(modelData)
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

      // An emulated pad is not the controller you are holding, and saying so
      // is the whole point: without this the panel calls a Steam Controller
      // "Microsoft X-Box 360 pad" and looks simply wrong.
      GcDegradedRow {
        width: parent.width
        visible: modelData.virtual === true && modelData.emulates !== null
        message: {
          if (!modelData.emulates) return ""
          var who = modelData.emulates.holder || "another program"
          return who + " has your " + modelData.emulates.name
               + " open and is presenting this emulated pad in its place, so "
               + "the buttons here are its translation rather than the real "
               + "controller. Close " + who + " to see the "
               + modelData.emulates.name + " itself."
        }
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

  // "wired · unknown" is two wrong claims about an emulated pad: there is no
  // cable and there is no driver, because there is no hardware.
  function padSubtitle(pad) {
    if (pad.virtual === true) {
      if (pad.emulates && pad.emulates.holder)
        return "emulated by " + pad.emulates.holder
      return "emulated"
    }
    return root.connectionText(pad) + " · " + pad.driver
  }

  function connectionText(pad) {
    switch (pad.connection) {
      case "usb": return "wired"
      case "dongle": return "wireless adapter"
      case "bluetooth": return "bluetooth"
      case "virtual": return "emulated"
      default: return "connected"
    }
  }
}
