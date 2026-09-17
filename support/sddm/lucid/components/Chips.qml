import QtQuick

// the glance chips. a greeter has no session to read wifi or battery out of,
// so this slot carries the two choices sddm actually offers: who is logging
// in, and into what
Row {
    id: chips

    spacing: 8

    component Chip: Rectangle {
        id: chip

        property string label: ""
        property string glyph: ""
        property bool interactive: true

        signal activated()

        implicitWidth: row.implicitWidth + 28
        implicitHeight: 36
        radius: 999
        color: hover.hovered && chip.interactive ? Theme.cardHigh : Theme.card

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(160)
            }

        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: 7

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.glyph
                size: 15
                color: Theme.subtext
                visible: chip.glyph !== ""
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelSm
                font.weight: Font.Medium
            }

        }

        HoverHandler {
            id: hover

            enabled: chip.interactive
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: chip.interactive
            onTapped: chip.activated()
        }

    }

    // only worth offering when there is more than one of them
    Chip {
        label: Lock.displayName
        glyph: "user"
        visible: Lock.accounts.length > 1
        onActivated: Lock.pick((Lock.index + 1) % Lock.accounts.length)
    }

    Chip {
        label: Lock.sessionName
        glyph: "apps"
        visible: Lock.sessions.length > 1
        onActivated: Lock.sessionIndex = (Lock.sessionIndex + 1) % Lock.sessions.length
    }

}
