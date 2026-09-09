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
    property int hoveredIndex: -1
    property int pressedIndex: -1
    readonly property int gap: 10
    readonly property real cardWidth: (powerRow.width - powerRow.gap * (powerRow.actions.length - 1)) / powerRow.actions.length
    // off for one tick on open so the indicator snaps to the reset index instead of sliding
    property bool slideEnabled: true

    signal actionChosen(string id)

    function toneFor(id) {
        return (id === "shutdown" || id === "reboot") ? Theme.error : Theme.accent;
    }

    function armSlide() {
        powerRow.slideEnabled = true;
    }

    function step(delta) {
        powerRow.currentIndex = Math.max(0, Math.min(powerRow.actions.length - 1, powerRow.currentIndex + delta));
    }

    function activateCurrent() {
        var a = powerRow.actions[powerRow.currentIndex];
        if (a)
            powerRow.actionChosen(a.id);

    }

    onVisibleChanged: {
        powerRow.slideEnabled = false;
        Qt.callLater(powerRow.armSlide);
    }

    // one indicator that travels to the current card
    Rectangle {
        id: indicator

        readonly property var action: powerRow.actions[powerRow.currentIndex]
        readonly property bool onHovered: powerRow.hoveredIndex === powerRow.currentIndex
        readonly property bool onPressed: powerRow.pressedIndex === powerRow.currentIndex

        width: powerRow.cardWidth
        height: cards.height
        x: powerRow.currentIndex * (powerRow.cardWidth + powerRow.gap)
        // rides the hover lift of the card it sits on
        y: cards.y + (indicator.onHovered ? -4 : 0)
        radius: Theme.radiusLg
        color: powerRow.toneFor(indicator.action ? indicator.action.id : "")
        opacity: Theme.stateFocus
        scale: indicator.onPressed ? 0.96 : 1

        Behavior on x {
            enabled: powerRow.slideEnabled

            NumberAnimation {
                duration: Theme.durShort
                easing.type: Theme.easeStandard
            }

        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.OutCubic
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Easing.OutCubic
            }

        }

    }

    Row {
        id: cards

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.max(0, (powerRow.stableHeight - cards.height) / 2)
        height: Math.min(powerRow.stableHeight, 132)
        spacing: powerRow.gap

        Repeater {
            model: powerRow.actions

            delegate: Item {
                id: card

                required property var modelData
                required property int index

                readonly property bool hovered: hoverHandler.hovered
                readonly property bool pressed: tapHandler.pressed
                readonly property bool selected: powerRow.currentIndex === card.index
                readonly property color tone: powerRow.toneFor(card.modelData.id)

                width: powerRow.cardWidth
                height: parent.height
                y: card.hovered ? -4 : 0

                Rectangle {
                    id: container

                    anchors.fill: parent
                    radius: Theme.radiusLg
                    color: "transparent"
                    scale: card.pressed ? 0.96 : 1

                    // hover state layer, separate from the travelling indicator
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.text
                        opacity: card.pressed ? Theme.statePressed : (card.hovered ? Theme.stateHover : 0)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durQuick
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

                            Behavior on glyphColor {
                                ColorAnimation {
                                    duration: Theme.durShort
                                }

                            }

                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: card.modelData.label
                            color: (card.selected || card.hovered) ? Theme.text : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            font.weight: Font.Medium

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durShort
                                }

                            }

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
                        powerRow.hoveredIndex = card.index;
                    else if (powerRow.hoveredIndex === card.index)
                        powerRow.hoveredIndex = -1;
                }

                onPressedChanged: {
                    if (card.pressed)
                        powerRow.pressedIndex = card.index;
                    else if (powerRow.pressedIndex === card.index)
                        powerRow.pressedIndex = -1;
                }

                TapHandler {
                    id: tapHandler

                    onTapped: {
                        powerRow.currentIndex = card.index;
                        powerRow.actionChosen(card.modelData.id);
                    }
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
