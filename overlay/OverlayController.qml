import QtQuick
import Quickshell
import Quickshell.Io

// Owns the stats overlay and the process feeding it.
//
// The streamer runs only while the overlay is shown — no overlay, no
// subprocess, no nvidia-smi call every second. Turning the overlay off is
// therefore genuinely free rather than just invisible.
QtObject {
  id: root

  property string pluginDir: ""

  property bool enabled: false
  property string corner: "top-right"
  property bool showCpu: true
  property bool showGpu: true
  property bool showRam: true
  property bool showVram: true
  property bool showTemps: true
  property bool showPower: false
  property real scale: 1.0
  property real interval: 1.0

  property var stats: null
  property string gpuKind: ""       // nvidia | amd | none
  property string error: ""

  // MangoHud is the only way to get real frames per second, because only
  // something inside the game can count them. Detected, not assumed.
  property bool mangohudInstalled: false

  function toggle() { enabled = !enabled }

  function detectMangohud() {
    whichProcess.command = ["sh", "-c", "command -v mangohud >/dev/null && echo yes || echo no"]
    whichProcess.running = true
  }

  function installMangohud() {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation",
                             "omarchy pkg add mangohud"])
  }

  // Writes the same metric choices into MangoHud's own config, so the in-game
  // overlay matches this one instead of being a second thing to configure.
  function writeMangohudConfig() {
    Quickshell.execDetached([root.pluginDir + "/bin/gc-mangohud",
                             "--position", root.corner,
                             "--metrics", root.metricList()])
  }

  function metricList() {
    var m = []
    if (showCpu) m.push("cpu")
    if (showGpu) m.push("gpu")
    if (showRam) m.push("ram")
    if (showVram) m.push("vram")
    if (showTemps) m.push("temps")
    if (showPower) m.push("power")
    return m.join(",")
  }

  onEnabledChanged: {
    if (enabled) {
      statsProcess.command = [root.pluginDir + "/bin/gc-stats",
                              "--interval", String(root.interval)]
      statsProcess.running = true
    } else {
      statsProcess.running = false
      root.stats = null
    }
  }

  property Process statsProcess: Process {
    stdout: SplitParser {
      onRead: function(line) {
        var t = String(line).trim()
        if (t === "") return
        var m
        try { m = JSON.parse(t) } catch (e) { return }
        if (m.v !== 1) return
        if (m.t === "stats") root.stats = m
        else if (m.t === "hello") { root.gpuKind = String(m.gpu || ""); root.error = "" }
      }
    }
    onExited: function(code) {
      if (root.enabled && code !== 0) {
        root.error = "the stats helper stopped unexpectedly"
        root.enabled = false
      }
    }
  }

  property Process whichProcess: Process {
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.mangohudInstalled = String(text).trim() === "yes"
    }
  }

  // One window per screen, so the overlay lands on the monitor being gamed on
  // rather than always the primary.
  property Variants windows: Variants {
    model: root.enabled ? Quickshell.screens : []

    StatsOverlay {
      required property var modelData
      screen: modelData
      visible: root.enabled
      stats: root.stats
      corner: root.corner
      showCpu: root.showCpu
      showGpu: root.showGpu
      showRam: root.showRam
      showVram: root.showVram
      showTemps: root.showTemps
      showPower: root.showPower
      scale: root.scale
    }
  }

  Component.onCompleted: detectMangohud()
}
