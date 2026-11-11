import QtQuick
import Quickshell
import Quickshell.Io

// Applies the gesture settings when the shell starts. Normally there is nothing
// to do: the panel wrote both the settings file and the generated Lua already,
// so the helper reports "unchanged" and Hyprland is left alone. This heals the
// cases the panel can't: a fresh install, `omarchy refresh hyprland` dropping
// the include line, or a settings file edited by hand.
QtObject {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string helper: (Quickshell.env("HOME") || "")
    + "/.config/omarchy/plugins/nox.trackpad-gestures/gestures.py"

  Component.onCompleted: applyOnce.running = true

  property Process applyOnce: Process {
    id: applyProcess
    command: ["python3", root.helper, "apply"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var status = String(text || "").trim()
        if (status !== "" && status !== "ok" && status !== "unchanged")
          console.warn("trackpad-gestures: " + status)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "") console.warn("trackpad-gestures: " + message)
      }
    }
  }
}
