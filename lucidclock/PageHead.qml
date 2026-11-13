import QtQuick
import qs
import qs.lucidui

// a page's title, a line under it, and room on the right for its controls
Item {
    id: head

    property string title: ""
    property string subtitle: ""
    property color subtitleColor: Theme.subtext
    default property alias controls: tools.data

    implicitHeight: Theme.dp(112)

    Column {
        anchors.left: parent.left
        anchors.right: tools.left
        anchors.rightMargin: Theme.dp(16)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.dp(18)
        spacing: Theme.dp(2)

        LText {
            role: "headlineMedium"
            weight: 520
            text: head.title
        }

        LText {
            width: parent.width
            visible: head.subtitle !== ""
            role: "bodyMedium"
            color: head.subtitleColor
            elide: Text.ElideRight
            text: head.subtitle
        }

    }

    Row {
        id: tools

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.dp(18)
        spacing: Theme.dp(8)
    }

}
