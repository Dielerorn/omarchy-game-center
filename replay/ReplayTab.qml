import QtQuick
import qs.Commons
import qs.Ui

// The Clips tab: arm the buffer, then save the last N seconds of it.
//
// The buffer's cost is stated up front — memory, bitrate, monitor — because
// arming one is a decision with a price, and a widget that quietly holds
// 300MB of your RAM for a whole evening should say so.
Column {
  id: root

  property var replay: null
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  spacing: Style.spacing.md

  readonly property bool ready: replay !== null
  readonly property bool armed: ready && replay.armed

  // kbps × seconds ÷ 8 is the payload. The encoder's working set is a large
  // fixed cost on top of it (measured 180–300MB depending on capture
  // resolution), so quoting the payload alone would understate a 15s buffer by
  // a factor of five. Same arithmetic as the launcher's preflight.
  readonly property int estimateMb: {
    if (!ready) return 0
    var kbps = replay.activeKbps > 0 ? replay.activeKbps : 26000
    return Math.round(kbps * replay.seconds / 8 / 1024) + 400
  }

  // --------------------------------------------------------- state row

  Toggle {
    width: parent.width
    label: root.armed ? "Replay buffer running" : "Replay buffer"
    description: {
      if (!root.ready) return ""
      if (root.replay.busy) return "working…"
      if (root.armed)
        return "holding the last " + root.replay.seconds + "s of "
             + root.replay.activeMonitor + " · ~" + root.estimateMb + "MB"
      return "keeps the last " + root.replay.seconds + "s so you can save it after it happens"
    }
    checked: root.armed
    foreground: root.foreground
    fontFamily: root.fontFamily
    onClicked: if (root.ready) root.replay.toggle()
  }

  // --------------------------------------------------------- save

  Button {
    width: parent.width
    text: "Save the last " + (root.ready ? root.replay.seconds : 30) + " seconds"
    enabled: root.armed
    opacity: root.armed ? 1.0 : 0.4
    bordered: true
    foreground: root.foreground
    fontFamily: root.fontFamily
    onClicked: if (root.armed) root.replay.save(root.ready ? root.replay.seconds : 0)
  }

  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    color: root.foreground
    opacity: 0.55
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    text: "Bind this to a key so you don't have to open the panel:\n"
        + "omarchy-shell -q gamecenter saveClip"
  }

  PanelSeparator { width: parent.width }

  // --------------------------------------------------------- settings

  PanelSectionHeader {
    width: parent.width
    text: "Buffer length"
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  ButtonGroup {
    options: [
      { value: "15", label: "15s" },
      { value: "30", label: "30s" },
      { value: "60", label: "60s" },
      { value: "120", label: "2m" }
    ]
    value: root.ready ? String(root.replay.seconds) : "30"
    foreground: root.foreground
    accent: Color.accent
    fontFamily: root.fontFamily
    // Changing length means restarting the capture, so it only takes effect on
    // the next arm — said plainly below rather than silently ignored.
    onChanged: function(v) { if (root.ready) root.replay.seconds = parseInt(v) }
  }

  Row {
    width: parent.width
    spacing: Style.spacing.md

    Dropdown {
      label: "Quality"
      width: (parent.width - Style.spacing.md) / 2
      options: ["low", "balanced", "high", "ultra"]
      value: root.ready ? root.replay.quality : "balanced"
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(v) { if (root.ready) root.replay.quality = v }
    }

    Dropdown {
      label: "Audio"
      width: (parent.width - Style.spacing.md) / 2
      options: ["desktop", "both", "none"]
      value: root.ready ? root.replay.audio : "desktop"
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(v) { if (root.ready) root.replay.audio = v }
    }
  }

  Text {
    width: parent.width
    visible: root.armed
    wrapMode: Text.WordWrap
    color: root.foreground
    opacity: 0.55
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    text: "Changes apply the next time the buffer starts."
  }

  // --------------------------------------------------------- footer

  PanelSeparator { width: parent.width }

  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    color: root.ready && root.replay.error !== "" ? Color.urgent : root.foreground
    opacity: root.ready && root.replay.error !== "" ? 1.0 : 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    text: {
      if (!root.ready) return "starting…"
      if (root.replay.error !== "") return root.replay.error
      if (root.replay.stockRecording) return "A screen recording is also running — both share the GPU encoder."
      if (root.replay.lastClip !== "")
        return "Last clip: " + String(root.replay.lastClip).split("/").pop()
      return root.armed ? "Nothing saved yet." : "Clip list arrives in M3."
    }
  }
}
