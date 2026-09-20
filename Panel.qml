import QtQuick
import qs.Commons
import qs.Ui

// Bar chip plus popout. The panel owns view state only — which tab is
// showing, where the keyboard cursor is — while everything that outlives the
// popout belongs to Service.qml.
//
// The chip is deliberately quiet. One glyph, one state, picked by a strict
// priority ladder (recording > replay armed > session on > idle), because a
// gaming widget that stacks counts and badges into the bar is the fastest
// route to being uninstalled. The sentence goes in the tooltip.
Panel {
  id: root

  moduleName: "dielerorn.gamecenter"
  ipcTarget: "dielerorn.gamecenter"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color panelForeground: Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // A service is mounted once per session and may not exist yet on the very
  // first paint, so every read goes through this null check.
  readonly property var gameCenter: bar && bar.shell ? bar.shell.serviceFor("dielerorn.gamecenter") : null
  readonly property bool serviceReady: gameCenter !== null

  readonly property int panelWidth: setting("panelWidth", 380)

  // ------------------------------------------------------------- tabs

  readonly property var tabs: [
    { value: "session", label: "Session" },
    { value: "pads", label: "Pads" },
    { value: "clips", label: "Clips" }
  ]

  property string tab: "session"
  property bool loading: false

  function loadSettings() {
    loading = true
    var wanted = String(setting("startTab", "session"))
    tab = tabs.some(function(t) { return t.value === wanted }) ? wanted : "session"
    loading = false
  }

  function tabIndex(value) {
    for (var i = 0; i < tabs.length; i++) if (tabs[i].value === value) return i
    return 0
  }

  function moveTab(delta) {
    var next = tabIndex(root.tab) + delta
    if (next < 0) next = tabs.length - 1
    if (next >= tabs.length) next = 0
    setTab(tabs[next].value)
  }

  function setTab(value) {
    if (root.tab === value) return
    root.tab = value
    persist()
  }

  // Stepping through three tabs is three clicks, and each one would otherwise
  // be its own rewrite of shell.json.
  function persist() {
    if (loading) return
    persistTimer.restart()
  }

  function persistNow() {
    if (!root.bar || !root.bar.shell || typeof root.bar.shell.updateEntryInline !== "function") return
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry.startTab = root.tab
    if (JSON.stringify(entry) === JSON.stringify(root.settings)) return
    root.settings = entry
    root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  Timer {
    id: persistTimer
    interval: 500
    onTriggered: root.persistNow()
  }

  Component.onCompleted: loadSettings()
  onSettingsChanged: if (!loading) loadSettings()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ------------------------------------------------------------- bar chip

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar

    // nf-md-microsoft_xbox_controller (U+F02B4): reads as "gamepad" at bar
    // size, where a more detailed glyph turns to mush.
    text: "󰊴"
    active: root.opened || (root.gameCenter ? root.gameCenter.sessionActive : false)

    tooltipText: {
      if (!root.serviceReady) return "Game Center (starting)"
      if (root.gameCenter.replayArmed) return "Game Center — replay armed"
      if (root.gameCenter.sessionActive) return "Game Center — session on"
      return "Game Center"
    }

    onPressed: function(b) { root.toggle() }
  }

  // ------------------------------------------------------------- popout

  KeyboardPanel {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(root.panelWidth))
    contentHeight: Math.round(Math.min(
      Math.max(popup.verticalContentInset, content.implicitHeight + popup.verticalContentInset),
      popup.availableCardHeight))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) { if (dx !== 0) root.moveTab(dx) }

      Column {
        id: content
        width: parent.width
        spacing: Style.spacing.md

        PanelHero {
          width: parent.width
          title: "Game Center"
          meta: root.serviceReady ? "Ready" : "Starting…"
          foreground: root.panelForeground
          fontFamily: root.fontFamily

          iconComponent: Component {
            Text {
              text: "󰊴"
              color: root.panelForeground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        ButtonGroup {
          options: root.tabs
          value: root.tab
          foreground: root.panelForeground
          accent: Color.accent
          fontFamily: root.fontFamily
          onChanged: function(value) { root.setTab(value) }
        }

        PanelSeparator { width: parent.width }

        // M0 placeholder. Each tab becomes its own component in M1/M2/M4;
        // for now the panel exists to prove the plugin contract end to end.
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          color: root.panelForeground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          text: {
            if (root.tab === "session") return "Session toggles land in M1."
            if (root.tab === "pads") return "Controllers land in M4."
            return "Instant replay lands in M2."
          }
        }

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          color: root.panelForeground
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          text: root.serviceReady
            ? "service ok · runtime " + root.gameCenter.runtimeDir
            : "service not reachable"
        }
      }
    }
  }
}
