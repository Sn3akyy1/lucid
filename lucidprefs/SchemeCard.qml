import QtQuick
import qs

// one scheme from the gallery, drawn in its own colours: its background, its
// text, and its eight accents along the bottom. the buttons wear the scheme
// too, so the card is a preview of what adding it gives
Rectangle {
    id: card

    // { id, name, author, variant, colors: [base00 .. base0F] }
    property var scheme: ({})
    property bool added: false
    property bool busy: false
    readonly property var c: card.scheme.colors || []
    readonly property bool hovered: area.containsMouse || addArea.containsMouse || useArea.containsMouse
    readonly property bool showActions: card.hovered || card.busy
    // authors often trail a homepage or an address in brackets; the name is enough
    readonly property string author: (card.scheme.author || "").replace(/\s*[(<][^)>]*[)>]/g, "").trim()

    signal addRequested()
    signal useRequested()

    width: 204
    height: 108
    radius: Theme.radiusMd
    color: card.c[0] || Theme.bgHigh
    border.width: card.hovered ? 2 : 1
    border.color: card.hovered ? (card.c[13] || Theme.accent) : Theme.alpha(Theme.text, 0.12)

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
    }

    Column {
        x: 12
        y: 10
        width: parent.width - 24 - (actions.visible ? actions.width + 8 : (tick.visible ? 16 : 0))
        spacing: 2

        Text {
            width: parent.width
            text: card.scheme.name || ""
            color: card.c[5] || Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            // base24 doubles some base16 names; say which one this is
            text: (card.scheme.system === "base24" ? "base24" + (card.author !== "" ? " · " : "") : "") + card.author
            visible: text !== ""
            color: card.c[4] || Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel - 2
            elide: Text.ElideRight
        }

    }

    // base08 .. base0F, the scheme's accents
    Row {
        x: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        spacing: 3

        Repeater {
            model: 8

            delegate: Rectangle {
                required property int index

                width: 12
                height: 12
                radius: 3
                color: card.c[8 + index] || "transparent"
            }

        }

    }

    Row {
        id: actions

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 8
        anchors.topMargin: 8
        spacing: 6
        visible: card.showActions

        Rectangle {
            width: addLabel.implicitWidth + 16
            height: 24
            radius: height / 2
            visible: !card.added || card.busy
            color: card.c[2] || Theme.bgSunken

            Text {
                id: addLabel

                anchors.centerIn: parent
                text: card.busy ? "Adding..." : "Add"
                color: card.c[5] || Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel - 1
                font.bold: true
            }

            MouseArea {
                id: addArea

                anchors.fill: parent
                hoverEnabled: true
                enabled: !card.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: card.addRequested()
            }

        }

        Rectangle {
            width: useLabel.implicitWidth + 16
            height: 24
            radius: height / 2
            visible: !card.busy
            color: card.c[13] || Theme.accent

            Text {
                id: useLabel

                anchors.centerIn: parent
                text: "Use"
                color: card.c[0] || Theme.fgAccent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel - 1
                font.bold: true
            }

            MouseArea {
                id: useArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.useRequested()
            }

        }

    }

    // already a theme: a tick in the scheme's green
    Text {
        id: tick

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 10
        anchors.topMargin: 8
        visible: card.added && !card.showActions
        text: "✓"
        color: card.c[11] || Theme.accent
        font.pixelSize: Theme.fontLabel
        font.bold: true
    }

}
