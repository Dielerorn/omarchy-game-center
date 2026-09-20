import QtQuick
import qs.Commons
import qs.Ui

// One saved clip: thumbnail, name, how long ago, how big, and the three things
// you actually want to do with it.
//
// The actions only appear on hover or when the keyboard cursor is on the row.
// A list of clips where every row carries three buttons reads as clutter, and
// the common case is that you want to watch the one you just saved.
Rectangle {
  id: root

  property var clip: null
  property string thumb: ""
  property bool hasCursor: false
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  signal openRequested()
  signal revealRequested()
  signal copyRequested()
  signal deleteRequested()
  signal thumbNeeded()

  readonly property bool showActions: mouse.containsMouse || hasCursor

  height: Style.space(64)
  radius: Style.cornerRadius
  color: showActions ? Style.hoverFill : "transparent"

  Component.onCompleted: if (thumb === "") root.thumbNeeded()

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onClicked: root.openRequested()
  }

  Row {
    anchors.fill: parent
    anchors.margins: Style.spacing.sm
    spacing: Style.spacing.md

    // 16:9 slot, so rows do not jump around as thumbnails arrive.
    Rectangle {
      width: Style.space(84)
      height: parent.height
      radius: Style.cornerRadius
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      clip: true

      Image {
        id: thumbImage
        anchors.fill: parent
        source: root.thumb !== "" ? "file://" + root.thumb : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: status === Image.Ready
      }

      // Shown while the thumbnail is being made, when ffmpeg is missing, and
      // when the cached still has been pruned out from under us — the cache is
      // trimmed to 200 files, so a long-lived panel can outlive its own
      // thumbnails. A clip with no picture is still a clip.
      Text {
        anchors.centerIn: parent
        visible: root.thumb === "" || thumbImage.status !== Image.Ready
        text: "󰕧"
        color: root.foreground
        opacity: 0.35
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
      }
    }

    Column {
      width: parent.width - Style.space(84) - Style.spacing.md
        - (root.showActions ? actions.width + Style.spacing.md : 0)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.xxs

      Text {
        width: parent.width
        elide: Text.ElideMiddle
        text: root.clip ? root.clip.name : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        width: parent.width
        elide: Text.ElideRight
        text: root.clip ? root.ageText(root.clip.mtime) + " · " + root.sizeText(root.clip.size) : ""
        color: root.foreground
        opacity: 0.55
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Row {
      id: actions
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.xs
      visible: root.showActions

      PanelActionButton {
        iconText: "󰐊"
        tooltipText: "Play"
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.openRequested()
      }
      PanelActionButton {
        iconText: "󰉋"
        tooltipText: "Show in files"
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.revealRequested()
      }
      PanelActionButton {
        iconText: "󰆏"
        tooltipText: "Copy path"
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.copyRequested()
      }
      PanelActionButton {
        iconText: "󰩹"
        tooltipText: "Delete"
        foreground: Color.urgent
        fontFamily: root.fontFamily
        onClicked: root.deleteRequested()
      }
    }
  }

  function sizeText(bytes) {
    var mb = bytes / 1048576
    return mb >= 1024 ? (mb / 1024).toFixed(1) + " GB" : Math.round(mb) + " MB"
  }

  function ageText(mtime) {
    var secs = Math.max(0, Math.floor(Date.now() / 1000) - mtime)
    if (secs < 60) return "just now"
    if (secs < 3600) return Math.floor(secs / 60) + "m ago"
    if (secs < 86400) return Math.floor(secs / 3600) + "h ago"
    return Math.floor(secs / 86400) + "d ago"
  }
}
