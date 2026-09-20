import QtQuick
import Quickshell
import Quickshell.Io
import "session"
import "replay"

// Owner of everything that has to stay correct while nobody is looking.
//
// A `service` is mounted once per session; a `bar-widget` is mounted once per
// monitor. So session ownership, the replay process and the pad inventory live
// here, and the panel reaches them through
// `bar.shell.serviceFor("dielerorn.gamecenter")`.
//
// The rule this plugin is built around: the authoritative state is never in
// this process. Tokens, pid files and sockets live under $XDG_RUNTIME_DIR, so
// a shell restart mid-session recovers by reading the filesystem rather than
// by remembering anything. M1 builds the recovery path on top of this; M0 just
// establishes the directory and the IPC surface.
QtObject {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: home + "/.config/omarchy/plugins/dielerorn.gamecenter"

  // /run/user/1000/omarchy-game-center. Wiped at logout, which is exactly the
  // staleness boundary we want: anything found here belongs to this login.
  readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || ("/tmp/omarchy-game-center-" + Quickshell.env("UID"))) + "/omarchy-game-center"

  // Distinguishes "this boot's leftovers" from "a token that survived a
  // reboot" without trusting timestamps. Read once; it cannot change.
  property string bootId: ""

  // M1. Owns the session toggles and their recovery.
  property SessionController session: SessionController {
    pluginDir: root.pluginDir
    runtimeDir: root.runtimeDir
  }

  readonly property bool sessionActive: session.engaged

  // M2. Owns the replay buffer process and its socket.
  property ReplayController replay: ReplayController {
    pluginDir: root.pluginDir
    runtimeDir: root.runtimeDir
  }

  readonly property bool replayArmed: replay.armed

  // Pads land in M4.
  property int padCount: 0

  function statusJson() {
    return JSON.stringify({
      version: "0.1.0",
      session: root.sessionActive,
      replay: root.replayArmed,
      pads: root.padCount,
      runtimeDir: root.runtimeDir,
      bootId: root.bootId
    })
  }

  // FileView will not create a parent directory, so the runtime dir is made
  // once at mount rather than lazily inside a save path.
  property Process runtimeDirProcess: Process {
    command: ["mkdir", "-p", root.runtimeDir]
  }

  property Process bootIdProcess: Process {
    command: ["cat", "/proc/sys/kernel/random/boot_id"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.bootId = String(text).trim()
    }
  }

  // Commands the panel does not need: these exist so a keybinding or a script
  // can drive Game Center without opening it.
  //
  //   omarchy-shell gamecenter status
  //
  // The panel's own open/close/toggle lives on the `dielerorn.gamecenter`
  // target, which Ui.Panel provides for free from `ipcTarget`.
  property IpcHandler ipc: IpcHandler {
    target: "gamecenter"

    function status(): string {
      return root.statusJson()
    }

    // Bindable without opening the panel:
    //   bind = SUPER ALT, G, exec, omarchy-shell -q gamecenter sessionToggle
    function sessionOn(): string { root.session.engage(); return "engaging" }
    function sessionOff(): string { root.session.release(); return "releasing" }
    function sessionToggle(): string { root.session.toggle(); return "toggling" }

    // The one worth binding to a key:
    //   bind = SUPER ALT, R, exec, omarchy-shell -q gamecenter saveClip
    function saveClip(): string { root.replay.save(root.replay.seconds); return "saving" }
    function replayArm(): string { root.replay.arm(); return "arming" }
    function replayDisarm(): string { root.replay.disarm(); return "disarming" }
    function replayToggle(): string { root.replay.toggle(); return "toggling" }
  }

  Component.onCompleted: {
    runtimeDirProcess.running = true
    bootIdProcess.running = true
    // Recovery first: a session orphaned by a shell restart is put back before
    // any UI exists to show a stale claim.
    session.start()
    replay.refresh()
  }
}
