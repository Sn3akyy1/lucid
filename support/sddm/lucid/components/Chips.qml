import QtQuick

// the glance chips. a greeter has no session to read wifi or battery out of,
// so the group carries what sddm does know: the machine, and the keymap. one
// connected group like the lock's, round at its ends and tight in between
Row {
    id: chips

    readonly property var layouts: keyboard.layouts || []
    readonly property bool canCycle: chips.layouts.length > 1
    readonly property string layoutName: {
        var l = chips.layouts[keyboard.currentLayout];
        if (!l)
            return "";

        return l.longName !== undefined && l.longName !== "" ? l.longName : String(l.shortName || "").toUpperCase();
    }

    spacing: 3

    component Chip: Rectangle {
        id: chip

        property string label: ""
        property string glyph: ""
        property bool interactive: false
        property bool lead: false
        property bool tail: false

        signal activated()

        implicitWidth: row.implicitWidth + 32
        implicitHeight: 40
        color: Theme.card
        topLeftRadius: chip.lead ? height / 2 : Theme.shapeSm
        bottomLeftRadius: chip.lead ? height / 2 : Theme.shapeSm
        topRightRadius: chip.tail ? height / 2 : Theme.shapeSm
        bottomRightRadius: chip.tail ? height / 2 : Theme.shapeSm

        Rectangle {
            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius
            bottomLeftRadius: parent.bottomLeftRadius
            topRightRadius: parent.topRightRadius
            bottomRightRadius: parent.bottomRightRadius
            color: Theme.text
            opacity: tap.pressed ? Theme.statePressed : (hover.hovered ? Theme.stateHover : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(120)
                }

            }

        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: 9

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.glyph
                size: 18
                color: Theme.subtext
                visible: chip.glyph !== ""
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
                font.weight: Font.Medium
            }

        }

        HoverHandler {
            id: hover

            // a pointer handler ignores Item.enabled unless told to
            enabled: chip.interactive && chip.enabled
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: tap

            enabled: chip.interactive
            onTapped: chip.activated()
        }

    }

    Chip {
        lead: true
        tail: !chips.canCycle
        glyph: "host"
        label: sddm.hostName
        visible: sddm.hostName !== ""
    }

    // one tap per layout, round and round
    Chip {
        lead: sddm.hostName === ""
        tail: true
        glyph: "keyboard"
        label: chips.layoutName
        interactive: true
        visible: chips.canCycle
        onActivated: keyboard.currentLayout = (keyboard.currentLayout + 1) % chips.layouts.length
    }

}
