import QtQuick
import qs

Item {
    id: powerRow

    readonly property var actions: [{
        "id": "lock",
        "label": "Lock",
        "glyph": DockIcons.lock
    }, {
        "id": "logout",
        "label": "Log Out",
        "glyph": DockIcons.logout
    }, {
        "id": "suspend",
        "label": "Suspend",
        "glyph": DockIcons.suspend
    }, {
        "id": "hibernate",
        "label": "Hibernate",
        "glyph": DockIcons.hibernate
    }, {
        "id": "reboot",
        "label": "Reboot",
        "glyph": DockIcons.reboot
    }, {
        "id": "shutdown",
        "label": "Shutdown",
        "glyph": DockIcons.power
    }]
    // settled height once the panel resize finishes
    property real stableHeight: height
    property int currentIndex: 0

    signal actionChosen(string id)

    function step(delta) {
        powerRow.currentIndex = Math.max(0, Math.min(powerRow.actions.length - 1, powerRow.currentIndex + delta));
    }

    function activateCurrent() {
        var a = powerRow.actions[powerRow.currentIndex];
        if (a)
            powerRow.actionChosen(a.id);

    }

    Row {
        id: cards

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.max(0, (powerRow.stableHeight - cards.height) / 2)
        height: Math.min(powerRow.stableHeight, 132)
        spacing: 10

        Repeater {
            model: powerRow.actions

            delegate: Item {
                id: card

                required property var modelData
                required property int index

                readonly property bool hovered: hoverHandler.hovered
                readonly property bool pressed: tapHandler.pressed
                readonly property bool selected: powerRow.currentIndex === card.index
                readonly property bool destructive: card.modelData.id === "shutdown" || card.modelData.id === "reboot"
                readonly property color tone: card.destructive ? Theme.error : Theme.accent

                width: (powerRow.width - 10 * (powerRow.actions.length - 1)) / powerRow.actions.length
                height: parent.height
                y: card.hovered ? -4 : 0

                Rectangle {
                    id: container

                    anchors.fill: parent
                    radius: Theme.radiusLg
                    color: "transparent"
                    scale: card.pressed ? 0.96 : 1

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: card.selected ? card.tone : Theme.text
                        opacity: card.pressed ? Theme.statePressed : (card.selected ? (card.hovered ? 0.16 : Theme.stateFocus) : (card.hovered ? Theme.stateHover : 0))

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durShort
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        DockGlyph {
                            width: 26
                            height: 26
                            anchors.horizontalCenter: parent.horizontalCenter
                            pathData: card.modelData.glyph
                            glyphColor: (card.selected || card.hovered) ? card.tone : Theme.subtext
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: card.modelData.label
                            color: (card.selected || card.hovered) ? Theme.text : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            font.weight: Font.Medium
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durQuick
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                HoverHandler {
                    id: hoverHandler
                }

                onHoveredChanged: {
                    if (card.hovered)
                        powerRow.currentIndex = card.index;

                }

                TapHandler {
                    id: tapHandler

                    onTapped: powerRow.actionChosen(card.modelData.id)
                }

                Behavior on y {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

    }

}
