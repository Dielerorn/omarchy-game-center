import QtQuick
import Quickshell
import Quickshell.Io

// Controller inventory: which pads are here, what they are, and what each one
// can actually do.
//
// The probe is a one-shot subprocess rather than a resident daemon, fired when
// /dev/input changes and when the panel opens. A pad being plugged in is a rare
// event; a background process polling for it is not worth the wakeups, and the
// directory watcher has in-tree precedent (the idle service watches its
// indicator directory the same way).
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
  property int _blinkCount: 0
  function blinkLed(ledPath) {
    if (!ledPath) return
    root._blinkTarget = ledPath
    root._blinkCount = 6
    blinkTimer.start()
  }

  property string _blinkTarget: ""
  property Timer blinkTimer: Timer {
    interval: 180
    repeat: true
    onTriggered: {
      if (root._blinkCount <= 0 || root._blinkTarget === "") {
        stop()
        // Always finish bright: leaving someone's controller light off would
        // look like the pad died.
        root.writeLed(root._blinkTarget, 1)
        root._blinkTarget = ""
        return
      }
      root.writeLed(root._blinkTarget, root._blinkCount % 2)
      root._blinkCount--
    }
  }

  function writeLed(ledPath, value) {
    if (!ledPath) return
    ledProcess.command = ["sh", "-c",
      "echo " + String(value) + " > " + shellQuote(ledPath + "/brightness")]
    ledProcess.running = true
  }

  // Both help buttons open the same README section rather than running
  // anything: installing a udev rule is a root action and should be the user's
  // deliberate choice, made with the rule in front of them.
  function showLedHelp() { openDocs() }
  function showPairHelp() { openDocs() }
  function openDocs() {
    docsProcess.command = ["xdg-open", root.pluginDir + "/docs/UDEV.md"]
    docsProcess.running = true
  }

  property Process ledProcess: Process {}
  property Process docsProcess: Process {}

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

  // Hotplug without a resident process. A pad appearing or disappearing
  // creates or removes a node here, and the battery node shows up a moment
  // later, so both are watched.
  property FileView inputWatch: FileView {
    path: "/dev/input"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  property FileView batteryWatch: FileView {
    path: "/sys/class/power_supply"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  // Battery level changes without any filesystem event, so while the tab is
  // open there is a slow poll behind the watchers. Off when nobody is looking.
  property Timer poll: Timer {
    interval: 30000
    repeat: true
    running: root.watching
    onTriggered: root.refresh()
  }
}
