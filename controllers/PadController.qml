import QtQuick
import Quickshell
import Quickshell.Io

// Controller inventory: which pads are here, what they are, and what each one
// can actually do.
//
// The probe is a one-shot subprocess, fired when a device node appears or
// disappears and when the panel opens. A pad being switched on is a rare event,
// so it is watched for rather than polled.
QtObject {
  id: root

  property string pluginDir: ""

  property var pads: []
  property var dongles: []
  property var drivers: []
  property string error: ""
  property bool probing: false

  // Set by the panel so the 30s safety poll only runs while someone is looking.
  property bool watching: false

  readonly property int padCount: pads.length
  readonly property var dongle: dongles.length > 0 ? dongles[0] : null

  // Any pad reporting Low is worth a dot on the bar chip.
  readonly property bool anyLowBattery: {
    for (var i = 0; i < pads.length; i++) {
      var b = pads[i].battery
      if (!b) continue
      if (b.level === "Low" || (b.percent !== null && b.percent <= 15)) return true
    }
    return false
  }

  signal rumbleFinished(string message)

  // ------------------------------------------------------- live input
  //
  // The streamer's lifetime *is* the subscription: it runs while the pads tab
  // is open and is killed when it closes. No idle process, no stdin protocol,
  // and a crash costs nothing but the picture until the next open.
  property string streamNode: ""
  property var padState: null
  property string streamBackend: ""
  property string streamError: ""

  function startStream(node) {
    if (node === root.streamNode && streamProcess.running) return
    stopStream()
    if (!node) return
    root.streamNode = node
    streamProcess.command = [root.pluginDir + "/bin/gc-pads", node, "--hz", "60"]
    streamProcess.running = true
  }

  function stopStream() {
    root.streamNode = ""
    root.padState = null
    root.streamBackend = ""
    root.streamError = ""
    if (streamProcess.running) streamProcess.running = false
  }

  property Process streamProcess: Process {
    stdout: SplitParser {
      onRead: function(line) {
        var t = String(line).trim()
        if (t === "") return
        var m
        try { m = JSON.parse(t) } catch (e) { return }
        // Refuse a protocol we do not know rather than guessing at its shape.
        if (m.v !== 1) return
        if (m.t === "state") root.padState = m
        else if (m.t === "hello") { root.streamBackend = String(m.backend || ""); root.streamError = "" }
        else if (m.t === "error") {
          root.streamError = m.code === "permission"
            ? "no permission to read this controller"
            : "controller disconnected"
        }
      }
    }
  }

  function refresh() {
    if (probeProcess.running) return
    root.probing = true
    probeProcess.command = [root.pluginDir + "/bin/gc-pad-probe"]
    probeProcess.running = true
  }

  function rumble(node, strong, weak, ms) {
    if (!node) return
    rumbleProcess.command = [root.pluginDir + "/bin/gc-rumble", node,
                             String(strong || 70), String(weak || 40), String(ms || 600)]
    rumbleProcess.running = true
  }

  // Pairing mode is a sysfs attribute the dongle driver exposes. Writing it
  // needs the udev rule; the panel only offers the button when `writable` says
  // the rule is in place, so this never fails silently.
  function startPairing() {
    if (!dongle || !dongle.writable) return
    pairProcess.command = ["sh", "-c",
      "echo 1 > " + shellQuote(dongle.path + "/pairing")]
    pairProcess.running = true
  }

  // The guide-button ring. `mode` on the xone LED takes blink patterns, but
  // brightness is the one every driver agrees on, so identify-by-blinking is
  // done by hand rather than by trusting a pattern number.
  //
  // Brightness is 0..max_brightness, and max is 50 on an Xbox pad — not 1.
  // The first version blinked between 0 and 1 and "restored" to 1, which is 2%
  // of full and looks exactly like a controller that has died. The level the
  // pad had before we touched it is read first and put back at the end.
  property int _blinkCount: 0
  property string _blinkTarget: ""
  property int _blinkRestore: 0
  property int _blinkHigh: 1

  function blinkLed(ledPath, current, max) {
    if (!ledPath) return
    if (root._blinkTarget !== "") return      // already blinking this or another
    root._blinkTarget = ledPath
    root._blinkRestore = Number(current) > 0 ? Number(current) : Number(max) || 1
    root._blinkHigh = Number(max) > 0 ? Number(max) : root._blinkRestore
    root._blinkCount = 6
    blinkTimer.start()
  }

  function endBlink() {
    blinkTimer.stop()
    if (root._blinkTarget === "") return
    root.writeLed(root._blinkTarget, root._blinkRestore)
    root._blinkTarget = ""
    root._blinkCount = 0
  }

  property Timer blinkTimer: Timer {
    interval: 180
    repeat: true
    onTriggered: {
      if (root._blinkCount <= 0 || root._blinkTarget === "") {
        root.endBlink()
        return
      }
      // Full brightness on, fully off — a blink you can actually see across
      // a desk, rather than two shades of dim.
      root.writeLed(root._blinkTarget,
                    root._blinkCount % 2 === 0 ? root._blinkHigh : 0)
      root._blinkCount--
    }
  }

  function writeLed(ledPath, value) {
    if (!ledPath) return
    ledProcess.command = ["sh", "-c",
      "echo " + String(value) + " > " + shellQuote(ledPath + "/brightness")]
    ledProcess.running = true
  }

  // Both help buttons open the same terminal flow: it prints the rule, says
  // what each line buys, and offers to install it.
  //
  // A terminal rather than anything in-panel, because installing the rule
  // needs root — and a bar widget that quietly raises a polkit prompt to write
  // a file in /etc is worse behaviour than one that shows you the four lines
  // and asks. The terminal is also where a password prompt belongs.
  function showLedHelp() { openUdevHelp() }
  function showPairHelp() { openUdevHelp() }
  function openUdevHelp() {
    // execDetached, not Process. The launcher exec's into a terminal that must
    // outlive this call; run as a tracked child it is torn down with the
    // Process object and the window never appears — which is exactly what
    // happened the first time.
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation",
                             root.pluginDir + "/bin/gc-udev"])
  }

  property Process ledProcess: Process {}

  function shellQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

  property Process probeProcess: Process {
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(String(text))
          root.pads = d.pads || []
          root.dongles = d.dongles || []
          root.drivers = d.drivers || []
          root.error = ""
        } catch (e) {
          root.error = "could not read controller state"
        }
        root.probing = false
      }
    }
    onExited: root.probing = false
  }

  property Process rumbleProcess: Process {
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var r = JSON.parse(String(text))
          root.rumbleFinished(r.ok ? "" : String(r.error || "rumble failed"))
        } catch (e) { root.rumbleFinished("") }
      }
    }
  }

  property Process pairProcess: Process { onExited: root.refresh() }

  // Hotplug.
  //
  // This started as a FileView on /dev/input, which never fired: FileView
  // watches a *file*, and pointing it at a directory silently does nothing, so
  // a controller switched on while the panel was closed stayed invisible until
  // the panel was opened. inotifywait is what the shell's own plugin registry
  // uses for the same job, it is genuinely event-driven rather than polled, and
  // it costs one sleeping process.
  property Process hotplug: Process {
    running: true
    command: ["inotifywait", "-m", "-q", "-e", "create,delete,move",
              "--format", "%f", "/dev/input", "/sys/class/power_supply"]
    stdout: SplitParser {
      // Every device node change lands here, so coalesce: plugging in one pad
      // creates several nodes in quick succession and each would otherwise be
      // its own probe.
      onRead: function(line) { debounce.restart() }
    }
    onExited: function(code) {
      // inotify-tools missing, or the watch died. Fall back to polling rather
      // than silently never noticing a controller again.
      if (root.hotplugFailed) return
      root.hotplugFailed = true
      root.refresh()
    }
  }

  property bool hotplugFailed: false

  property Timer debounce: Timer {
    interval: 400
    onTriggered: root.refresh()
  }

  // Battery level changes with no filesystem event behind it, so there is a
  // slow poll while the tab is open — and a slower one always, as the fallback
  // if the hotplug watcher is not available.
  property Timer poll: Timer {
    interval: root.watching ? 30000 : 60000
    repeat: true
    running: root.watching || root.hotplugFailed
    onTriggered: root.refresh()
  }
}
