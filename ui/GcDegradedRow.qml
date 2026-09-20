import QtQuick
import qs.Commons
import qs.Ui

// One sentence of cause plus one thing to do about it.
//
// This is the shape every missing capability takes in this plugin: a feature
// that cannot work explains itself in place, instead of appearing as a control
// that does nothing or vanishing with no explanation at all.
Rectangle {
  id: root

  property string message: ""
  property string actionText: ""
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  signal activated()

  height: visible ? row.implicitHeight + Style.spacing.md * 2 : 0
  radius: Style.cornerRadius
  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)

  Row {
    id: row
    anchors.fill: parent
    anchors.margins: Style.spacing.md
    spacing: Style.spacing.md

    Text {
      width: parent.width - (action.visible ? action.width + Style.spacing.md : 0)
      wrapMode: Text.WordWrap
      text: root.message
      color: root.foreground
      opacity: 0.7
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Button {
      id: action
      anchors.verticalCenter: parent.verticalCenter
      visible: root.actionText !== ""
      text: root.actionText
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.activated()
    }
  }
}
