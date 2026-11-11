import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

// Trackpad gestures: three or four fingers sliding between workspaces with the
// windows following the fingers, the way macOS moves between Spaces. The bar
// icon opens the settings panel; Service.qml applies the same settings when the
// shell starts, so the choice survives a restart even if this panel is never
// opened. gestures.py is the only writer: this panel and the CLI both go
// through it, and it owns both the JSON and the generated Hyprland Lua.
Panel {
  id: root
  moduleName: "nox.trackpad-gestures"
  ipcTarget: "nox.trackpad-gestures"

  // The bar sizes the slot from the widget itself, so lift the icon button's
  // size up; without this the widget occupies nothing and never shows.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property string helper: (Quickshell.env("HOME") || "")
    + "/.config/omarchy/plugins/nox.trackpad-gestures/gestures.py"
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color accent: Commons.Color.accent

  // Mirrors gestures.py. Every edit is echoed locally for an instant response,
  // then confirmed by re-reading the settings file through the helper.
  property bool enabled: true
  property int fingers: 4
  property bool invert: false
  property int distance: 300
  property bool animation: true
  property string errorText: ""
  property var queue: []

  readonly property string directionHint: invert
    ? "手指向左滑 → 上一个工作区"
    : "手指向左滑 → 下一个工作区"

  function sync(state) {
    if (!state) return
    enabled = state.enabled !== false
    fingers = Number(state.fingers) === 3 ? 3 : 4
    invert = state.invert === true
    distance = Math.round(Number(state.distance) || 300)
    animation = state.animation !== false
  }

  function update(key, value) {
    if (key === "enabled") enabled = value === true
    else if (key === "fingers") fingers = Number(value)
    else if (key === "invert") invert = value === true
    else if (key === "distance") distance = Math.round(Number(value))
    else if (key === "animation") animation = value === true
    errorText = ""
    enqueue(key, value)
  }

  // One helper at a time: a slider drag or a few fast clicks would otherwise
  // race each other over the settings file.
  function enqueue(key, value) {
    var next = queue.slice()
    next.push({ key: key, value: String(value) })
    queue = next
    pump()
  }

  function pump() {
    if (helperProc.running || queue.length === 0) return
    var rest = queue.slice()
    var request = rest.shift()
    queue = rest
    helperProc.command = ["python3", helper, "set", String(request.key), String(request.value)]
    helperProc.running = true
  }

  Component.onCompleted: stateProc.running = true
  onOpenedChanged: if (opened && !stateProc.running) stateProc.running = true

  Process {
    id: stateProc
    command: ["python3", helper, "state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw === "") return
        try {
          root.sync(JSON.parse(raw))
        } catch (e) {
          root.errorText = "读取设置失败"
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "") root.errorText = message
      }
    }
  }

  Process {
    id: helperProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // "set" answers with a status line and then the full settings JSON.
        var lines = String(text || "").trim().split("\n")
        for (var i = lines.length - 1; i >= 0; i--) {
          var line = lines[i].trim()
          if (line.charAt(0) !== "{") continue
          try {
            root.sync(JSON.parse(line))
          } catch (e) {
            root.errorText = "设置已写入，但回读失败"
          }
          return
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        root.errorText = message
        if (message === "") stateProc.running = true
      }
    }
    onRunningChanged: if (!running) root.pump()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰪿"
    opacity: root.enabled ? 1.0 : 0.45
    tooltipText: root.enabled
      ? "触控板手势：" + root.fingers + " 指左右滑动（右键关闭）"
      : "触控板手势已关闭（右键开启）"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.update("enabled", !root.enabled)
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(620))

    content: PanelKeyCatcher {
      id: keyCatcher
      implicitHeight: column.implicitHeight
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(14)

        PanelHero {
          id: hero
          width: parent.width
          title: "触控板手势"
          meta: root.enabled
            ? root.fingers + " 指左右滑动切换工作区"
            : "已关闭，切工作区回到键盘"
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: root.enabled ? 1.0 : 0.5
          iconComponent: Component {
            Text {
              textFormat: Text.PlainText
              text: "󰪿"
              color: hero.foreground
              font.family: hero.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            ToggleSwitch {
              checked: root.enabled
              foreground: hero.foreground
              onToggled: root.update("enabled", !root.enabled)
            }
          }
        }

        PanelSeparator {}

        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.enabled

          SectionLabel { text: "手指数量" }

          ButtonGroup {
            options: [
              { value: "3", label: "三指" },
              { value: "4", label: "四指" }
            ]
            value: String(root.fingers)
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            onChanged: function(value) { root.update("fingers", value) }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.enabled

          SectionLabel { text: "方向" }

          ButtonGroup {
            options: [
              { value: "natural", label: "自然" },
              { value: "inverted", label: "反向" }
            ]
            value: root.invert ? "inverted" : "natural"
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            onChanged: function(value) { root.update("invert", value === "inverted") }
          }

          Hint { text: root.directionHint }
        }

        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: root.enabled

          Item {
            width: parent.width
            implicitHeight: distanceLabel.implicitHeight

            SectionLabel {
              id: distanceLabel
              text: "手势行程"
            }

            Text {
              textFormat: Text.PlainText
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.distance + " px"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            minimum: 150
            maximum: 600
            step: 10
            integer: true
            value: root.distance
            // Dragging only moves the label; one write per release, so a slow
            // drag doesn't rewrite the settings and reload Hyprland thirty times.
            onMoved: function(value) { root.distance = Math.round(value) }
            onReleased: function(value) { root.update("distance", Math.round(value)) }
          }

          Hint { text: "要滑多远才算切换：数值越小越灵敏。" }
        }

        Toggle {
          width: parent.width
          visible: root.enabled
          label: "顺滑收尾动画"
          description: "松手后用一小段滑动把画面收进新工作区。关掉后 SUPER+1…0 会恢复成瞬切，滑动结束时也会跳一下。"
          checked: root.animation
          foreground: root.foreground
          accent: root.accent
          fontFamily: root.fontFamily
          onClicked: root.update("animation", !root.animation)
        }

        Text {
          width: parent.width
          visible: root.errorText !== ""
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: root.errorText
          color: root.foreground
          opacity: 0.8
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        PanelSeparator {}

        Hint {
          text: "设置写入 ~/.config/omarchy/trackpad-gestures.json，并生成 "
            + "~/.config/hypr/trackpad_gestures.lua，重载 Hyprland 后依然生效。"
        }
      }
    }
  }

  component SectionLabel: Text {
    textFormat: Text.PlainText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  component Hint: Text {
    width: parent ? parent.width : implicitWidth
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
