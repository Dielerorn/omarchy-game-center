import QtQuick
import qs.Commons
import qs.Ui
import "session"
import "replay"

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
  readonly property var session: gameCenter ? gameCenter.session : null
  readonly property bool sessionOn: session ? session.engaged : false
  readonly property var replay: gameCenter ? gameCenter.replay : null
  readonly property bool replayArmed: replay ? replay.armed : false
  readonly property var clipStore: gameCenter ? gameCenter.clipStore : null

  // The probe costs four subprocesses, so it runs when the panel opens rather
  // than on a timer. While the panel is closed the marker watcher is the only
  // thing keeping state fresh, which is enough for the chip.
  onOpenedChanged: {
    if (!opened) return
    if (session) session.refresh()
    if (replay) replay.refresh()
    // One find per open, not a watcher on the video folder: that can live on a
    // network mount and a FileView there would stall the event loop.
    if (clipStore) clipStore.refresh()
  }

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
    if (session) {
      session.wantIdle = setting("keepAwake", true)
      session.wantDnd = setting("silenceNotifications", true)
      session.wantNightlight = setting("nightLightOff", true)
      session.wantPower = setting("performanceProfile", true)
    }
    if (replay) {
      replay.seconds = setting("replaySeconds", 30)
      replay.storage = setting("replayStorage", "ram")
      replay.quality = setting("replayQuality", "balanced")
      replay.audio = setting("replayAudio", "desktop")
    }
    loading = false
  }

  // The service outlives the panel, so its controller may already exist when
  // this widget mounts — or arrive a moment later on a cold start.
  onSessionChanged: if (session) loadSettings()
  onReplayChanged: if (replay) loadSettings()

  Connections {
    target: root.session
    ignoreUnknownSignals: true
    function onWantIdleChanged() { root.persist() }
    function onWantDndChanged() { root.persist() }
    function onWantNightlightChanged() { root.persist() }
    function onWantPowerChanged() { root.persist() }
  }

  Connections {
    target: root.replay
    ignoreUnknownSignals: true
    function onSecondsChanged() { root.persist() }
    function onStorageChanged() { root.persist() }
    function onQualityChanged() { root.persist() }
    function onAudioChanged() { root.persist() }
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
    if (root.session) {
      entry.keepAwake = root.session.wantIdle
      entry.silenceNotifications = root.session.wantDnd
      entry.nightLightOff = root.session.wantNightlight
      entry.performanceProfile = root.session.wantPower
    }
    if (root.replay) {
      entry.replaySeconds = root.replay.seconds
      entry.replayStorage = root.replay.storage
      entry.replayQuality = root.replay.quality
      entry.replayAudio = root.replay.audio
    }
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
    active: root.opened || root.sessionOn || root.replayArmed

    // One glyph, one state, in priority order. A bar widget that stacks
    // badges is the fastest route to being uninstalled, so the detail lives
    // in the tooltip.
    tooltipText: {
      if (!root.serviceReady) return "Game Center (starting)"
      var parts = []
      if (root.replayArmed) parts.push("replay armed (" + root.replay.seconds + "s)")
      if (root.sessionOn) parts.push("session on")
      if (root.replay && root.replay.stockRecording) parts.push("screen recording")
      return parts.length ? "Game Center — " + parts.join(" · ") : "Game Center"
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
          meta: {
            if (!root.serviceReady) return "Starting…"
            if (root.session && root.session.busy) return "Working…"
            return root.sessionOn ? "Session on" : "Session off"
          }
          foreground: root.panelForeground
          fontFamily: root.fontFamily

          iconComponent: Component {
            Text {
              text: "󰊴"
              color: root.sessionOn ? Color.accent : root.panelForeground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }

          // The master switch lives in the hero so it is reachable from every
          // tab without navigating back.
          trailingControl: Component {
            ToggleSwitch {
              checked: root.sessionOn
              busy: root.session ? root.session.busy : false
              interactive: root.serviceReady
              foreground: root.panelForeground
              accent: Color.accent
              onToggled: if (root.session) root.session.toggle()
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

        SessionTab {
          width: parent.width
          visible: root.tab === "session"
          session: root.session
          foreground: root.panelForeground
          fontFamily: root.fontFamily
        }

        ReplayTab {
          width: parent.width
          visible: root.tab === "clips"
          replay: root.replay
          clips: root.clipStore
          foreground: root.panelForeground
          fontFamily: root.fontFamily
        }

        // M4 replaces this.
        Text {
          width: parent.width
          visible: root.tab === "pads"
          wrapMode: Text.WordWrap
          color: root.panelForeground
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          text: "Controllers land in M4."
        }
      }
    }
  }
}
