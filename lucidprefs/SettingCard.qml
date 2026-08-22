import QtQuick
import qs

// One group of related settings: a small section label sitting outside the
// surface, then a tonal container holding the rows. Grouping is done with
// whitespace and a single surface step rather than borders or shadows, which
// is how the rest of this shell separates things.
Item {
    id: card

    property string title: ""
    property string subtitle: ""
    default property alias content: inner.data

    implicitWidth: parent ? parent.width : 400
    implicitHeight: header.height + surface.implicitHeight

    Column {
        id: header

        width: parent.width
        spacing: 2

        Text {
            text: card.title
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            font.bold: true
            font.letterSpacing: 0.8
            visible: card.title !== ""
            bottomPadding: 8
        }

    }

    Rectangle {
        id: surface

        anchors.top: header.bottom
        width: parent.width
        implicitHeight: inner.implicitHeight + 8
        radius: Theme.radiusXl
        // tracks Glass like the pane under it, so the two stay a consistent
        // stack of glass rather than a solid card floating on a clear one
        color: Theme.withBlur(Theme.bgTile)

        Column {
            id: inner

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 4
            spacing: 0
        }

    }

}
