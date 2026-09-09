import QtQuick
import qs

SettingCard {
    id: card

    required property var dev

    property real pendingX: 0
    property real pendingY: 0
    property real lastX: 0
    property real lastY: 0
    property bool tracking: false
    property bool moved: false
    property bool typing: false

    readonly property bool canType: !!card.dev.keyboard

    function special(key) {
        switch (key) {
        case Qt.Key_Backspace:
            return KdeConnect.specialKeys.backspace;
        case Qt.Key_Tab:
            return KdeConnect.specialKeys.tab;
        case Qt.Key_Left:
            return KdeConnect.specialKeys.left;
        case Qt.Key_Up:
            return KdeConnect.specialKeys.up;
        case Qt.Key_Right:
            return KdeConnect.specialKeys.right;
        case Qt.Key_Down:
            return KdeConnect.specialKeys.down;
        case Qt.Key_PageUp:
            return KdeConnect.specialKeys.pageup;
        case Qt.Key_PageDown:
            return KdeConnect.specialKeys.pagedown;
        case Qt.Key_Home:
            return KdeConnect.specialKeys.home;
        case Qt.Key_End:
            return KdeConnect.specialKeys.end;
        case Qt.Key_Return:
            return KdeConnect.specialKeys.return;
        case Qt.Key_Enter:
            return KdeConnect.specialKeys.enter;
        case Qt.Key_Delete:
            return KdeConnect.specialKeys.delete;
        case Qt.Key_Escape:
            return KdeConnect.specialKeys.escape;
        default:
            return 0;
        }
    }

    title: "USE THIS MACHINE AS A REMOTE"

    // one packet per frame instead of one per mouse event
    Timer {
        interval: 30
        repeat: true
        running: card.tracking
        onTriggered: {
            if (card.pendingX === 0 && card.pendingY === 0)
                return ;

            KdeConnect.cursor(card.dev.id, card.pendingX, card.pendingY);
            card.pendingX = 0;
            card.pendingY = 0;
        }
    }

    SettingRow {
        title: "Touchpad"
        description: "Drag inside the panel to move the phone's pointer. A tap is a click."
        stacked: true

        Column {
            width: parent.width
            spacing: 12

            Rectangle {
                width: parent.width
                height: 170
                radius: Theme.radiusLg
                color: pad.pressed ? Theme.bgActive : (pad.containsMouse ? Theme.bgHover : Theme.bgSunken)
                border.width: 1
                border.color: pad.containsMouse ? Theme.accentBorder : Theme.outline

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durQuick
                    }

                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.durQuick
                    }

                }

                Text {
                    anchors.centerIn: parent
                    text: card.tracking ? "" : "Drag here"
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                }

                MouseArea {
                    id: pad

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.BlankCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onPressed: (mouse) => {
                        card.lastX = mouse.x;
                        card.lastY = mouse.y;
                        card.tracking = true;
                        card.moved = false;
                    }
                    onPositionChanged: (mouse) => {
                        if (!card.tracking)
                            return ;

                        const dx = mouse.x - card.lastX;
                        const dy = mouse.y - card.lastY;
                        card.lastX = mouse.x;
                        card.lastY = mouse.y;
                        card.pendingX += dx;
                        card.pendingY += dy;
                        if (Math.abs(dx) > 1 || Math.abs(dy) > 1)
                            card.moved = true;

                    }
                    onReleased: (mouse) => {
                        card.tracking = false;
                        card.pendingX = 0;
                        card.pendingY = 0;
                        if (card.moved)
                            return ;

                        if (mouse.button === Qt.RightButton)
                            KdeConnect.click(card.dev.id, "rightclick");
                        else if (mouse.button === Qt.MiddleButton)
                            KdeConnect.click(card.dev.id, "middleclick");
                        else
                            KdeConnect.click(card.dev.id, "singleclick");
                    }
                }

            }

            Row {
                spacing: 10

                M3Button {
                    variant: "tonal"
                    text: "Left click"
                    onClicked: KdeConnect.click(card.dev.id, "singleclick")
                }

                M3Button {
                    variant: "tonal"
                    text: "Middle"
                    onClicked: KdeConnect.click(card.dev.id, "middleclick")
                }

                M3Button {
                    variant: "tonal"
                    text: "Right click"
                    onClicked: KdeConnect.click(card.dev.id, "rightclick")
                }

                M3Button {
                    variant: "text"
                    text: "Double click"
                    onClicked: KdeConnect.click(card.dev.id, "doubleclick")
                }

            }

        }

    }

    SettingRow {
        title: "Keyboard"
        enabled: card.canType
        disabledReason: "The phone is not showing a text field, so there is nowhere for the keys to go."
        description: card.typing ? "Every key you press now goes to the phone. Click away to stop." : "Click the box, then type. What you type lands in whatever the phone has open."
        stacked: true
        showDivider: false

        Rectangle {
            width: parent.width
            height: 46
            radius: Theme.radiusSm
            color: Theme.bgSunken
            border.width: card.typing ? 2 : 1
            border.color: card.typing ? Theme.accent : Theme.outlineStrong

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: card.typing ? "Listening — type away" : "Click to send keys to the phone"
                color: card.typing ? Theme.accent : Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
            }

            Item {
                id: keySink

                anchors.fill: parent
                focus: false
                onActiveFocusChanged: card.typing = keySink.activeFocus
                Keys.onPressed: (event) => {
                    event.accepted = true;
                    const sp = card.special(event.key);
                    if (sp === 0 && event.text === "")
                        return ;

                    KdeConnect.key(card.dev.id, sp === 0 ? event.text : "", sp, !!(event.modifiers & Qt.ShiftModifier), !!(event.modifiers & Qt.ControlModifier), !!(event.modifiers & Qt.AltModifier));
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: card.canType
                cursorShape: Qt.IBeamCursor
                onClicked: keySink.forceActiveFocus()
            }

        }

    }

}
