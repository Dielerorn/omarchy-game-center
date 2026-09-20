import QtQuick
import qs.Commons

// An empty state that says what is true and what to do about it, rather than
// just "nothing here". Every tab uses the same one so the voice stays the same.
Column {
  id: root

  property string glyph: ""
  property string title: ""
  property string detail: ""
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  spacing: Style.spacing.xs

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    text: root.glyph
    color: root.foreground
    opacity: 0.3
    font.family: root.fontFamily
    font.pixelSize: Style.font.displayLarge
  }

  Text {
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    text: root.title
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }

  Text {
    width: parent.width
    visible: root.detail !== ""
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: root.detail
    color: root.foreground
    opacity: 0.55
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
