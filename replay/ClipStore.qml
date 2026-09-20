import QtQuick
import Quickshell
import Quickshell.Io

// The list of saved clips.
//
// Kept deliberately cheap: one `find` when the panel opens and one more
// whenever a clip is actually saved (the -sc hook writes a file we already
// watch). No directory watcher on the video folder — that can sit on a network
// mount, and a FileView on it would stall the shell's event loop.
QtObject {
  id: root

  property string pluginDir: ""
  property var clips: []
  property bool loading: false
  property string error: ""

  // path → thumbnail path. Populated lazily, only for rows the panel asks for.
  // Always replaced with a fresh object rather than mutated: QML only emits
  // thumbsChanged when the reference changes, and the bindings in the clip
  // rows are what draw the picture.
  property var thumbs: ({})

  function setThumb(path, value) {
    var next = {}
    for (var k in root.thumbs) next[k] = root.thumbs[k]
    next[path] = value
    root.thumbs = next
  }

  function script(args) { return [root.pluginDir + "/bin/gc-replay"].concat(args) }

  function refresh() {
    if (listProcess.running) return
    root.loading = true
    listProcess.command = script(["clips"])
    listProcess.running = true
  }

  function remove(path) {
    deleteProcess.command = script(["delete", path])
    deleteProcess.running = true
  }

  function open(path) { openProcess.command = ["xdg-open", path]; openProcess.running = true }

  function reveal(path) {
    // Most file managers understand --select; xdg-open on the folder is the
    // fallback that always works.
    revealProcess.command = ["sh", "-c",
      "nautilus --select " + shellQuote(path) + " 2>/dev/null || " +
      "xdg-open " + shellQuote(dirOf(path))]
    revealProcess.running = true
  }

  function copyPath(path) {
    copyProcess.command = ["wl-copy", "--", path]
    copyProcess.running = true
  }

  function shellQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
  function dirOf(p) { var i = String(p).lastIndexOf("/"); return i > 0 ? String(p).substring(0, i) : "/" }

  // Thumbnails are generated one at a time. Fifty clips on screen would
  // otherwise mean fifty concurrent ffmpeg processes competing with the game
  // the user is playing.
  property var _thumbQueue: []
  function requestThumb(path) {
    if (!path || root.thumbs[path] !== undefined) return
    if (root._thumbQueue.indexOf(path) >= 0) return
    root._thumbQueue.push(path)
    pumpThumbs()
  }

  function pumpThumbs() {
    if (thumbProcess.running || root._thumbQueue.length === 0) return
    var next = root._thumbQueue[0]
    thumbProcess.command = [root.pluginDir + "/bin/gc-thumb", next]
    thumbProcess.running = true
  }

  property Process listProcess: Process {
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.clips = JSON.parse(String(text))
          root.error = ""
        } catch (e) {
          root.clips = []
          root.error = "could not list clips"
        }
        root.loading = false
      }
    }
  }

  property Process thumbProcess: Process {
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var done = root._thumbQueue.shift()
        var out = String(text).trim()
        if (done && out !== "") root.setThumb(done, out)
        Qt.callLater(root.pumpThumbs)
      }
    }
    onExited: function(code) {
      // ffmpeg missing, or a clip we cannot read: drop it from the queue so one
      // bad file does not stall every thumbnail behind it.
      if (code !== 0 && root._thumbQueue.length > 0) {
        root.setThumb(root._thumbQueue.shift(), "")
      }
      Qt.callLater(root.pumpThumbs)
    }
  }

  property Process deleteProcess: Process { onExited: root.refresh() }
  property Process openProcess: Process {}
  property Process revealProcess: Process {}
  property Process copyProcess: Process {}
}
