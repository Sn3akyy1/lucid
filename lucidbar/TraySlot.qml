import QtQuick
import Quickshell.Services.SystemTray
import qs

// one app in the tray's icons look, in a slot the way the apps module next to
// it has them: the slot lights under the pointer and stays lit while the app's
// menu is open, a press squashes the icon, its name shows after a beat, and an
// app asking for attention breathes a red mark under it. a click opens the
// tray, not the app; a right click, the app's menu
Item {
    id: cell

    required property int index
    required property int serial
    required property bool leaving
    property var tray: null
    readonly property var item: cell.tray ? cell.tray.itemOf(cell.serial) : null
    readonly property bool wants: !cell.leaving && Tray.wantsYou(cell.item)
    readonly property bool menuOpen: !!cell.tray && cell.tray.menuShown && cell.tray.menuSerial === cell.serial
    readonly property bool hot: area.containsMouse && !cell.leaving
    readonly property bool pressed: area.pressed
    // set once as it is made: a binding would empty every slot when the module comes up
    property real born: 1
    // 1 once the app has quit and its icon has shrunk away
    property real gone: 0

    width: cell.tray ? cell.tray.slot : 0
    height: cell.tray ? cell.tray.compactHeight : 0
    // its place in line; a reorder or a neighbour leaving glides it there
    x: cell.index * cell.width
    opacity: cell.born * (1 - cell.gone)
    onPressedChanged: cellJelly.kick(cell.pressed ? -0.13 : 0.1)
    // asking for attention: it hops, then breathes until answered
    onWantsChanged: {
        if (cell.wants)
            cellJelly.kickAfter(0.18, Theme.ms(40));

    }
    onLeavingChanged: {
        if (!cell.leaving)
            return ;

        if (cell.tray)
            cell.tray.unhover(cell);

        bornAnim.stop();
        goneAnim.start();
    }
    Component.onCompleted: {
        if (!cell.tray || !cell.tray.slotsReady)
            return ;

        cell.born = 0;
        bornAnim.start();
    }

    NumberAnimation {
        id: bornAnim

        target: cell
        property: "born"
        to: 1
        duration: Theme.durMedium
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasizedDecel
    }

    // leaving accelerates, as everything that goes does here
    NumberAnimation {
        id: goneAnim

        target: cell
        property: "gone"
        to: 1
        duration: Theme.durShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasizedAccel
    }

    Item {
        id: face

        readonly property bool jellyWobbling: cellJelly.wobbling

        anchors.fill: parent
        scale: cell.pressed ? 0.9 : 1

        Item {
            anchors.fill: parent
            scale: (0.6 + 0.4 * cell.born) * (1 - 0.4 * cell.gone)

            Rectangle {
                anchors.centerIn: parent
                width: cell.width - Theme.dp(4)
                height: cell.height - Theme.dp(8)
                radius: Theme.radiusMd
                color: Theme.text
                opacity: cell.pressed ? Theme.statePressed + 0.04 : (cell.menuOpen ? Theme.stateHover + 0.06 : (cell.hot ? Theme.stateHover + 0.02 : 0))

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutCubic
                    }

                }

            }

            TrayIcon {
                anchors.centerIn: parent
                item: cell.item
                size: cell.tray ? cell.tray.glyph : Theme.dp(16)
                hovered: cell.hot || cell.menuOpen
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }

        }

        transform: Jelly {
            id: cellJelly

            target: face
            anchorY: 0
            frequency: 5.5
        }

    }

    // as the apps module's mark for a window wanting attention: red, breathing
    Rectangle {
        id: mark

        property real pulse: 1
        readonly property bool breathing: cell.wants && cell.visible && !!cell.tray && cell.tray.shown

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.dp(3)
        width: Theme.barDp(4)
        height: Theme.barDp(3)
        radius: height / 2
        color: Theme.error
        opacity: cell.wants ? mark.pulse : 0
        visible: opacity > 0.01

        SequentialAnimation on pulse {
            running: mark.breathing
            loops: Animation.Infinite
            onRunningChanged: {
                if (!running)
                    mark.pulse = 1;

            }

            NumberAnimation {
                to: 0.3
                duration: Theme.ms(500)
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: Theme.ms(500)
                easing.type: Easing.InOutSine
            }

        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: !cell.leaving
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: cell.tray.hover(cell)
        onExited: cell.tray.unhover(cell)
        onPressed: cell.tray.hover(null)
        onClicked: (mouse) => {
            if (!cell.item)
                return ;

            if (mouse.button === Qt.RightButton) {
                cell.tray.toggleMenu(cell);
                return ;
            }
            if (mouse.button === Qt.MiddleButton) {
                cell.tray.closeMenu();
                cell.item.secondaryActivate();
                return ;
            }
            // the tray, whichever icon it lands on; the apps are a click away in its rows
            cell.tray.closeMenu();
            cell.tray.barClicked(Qt.LeftButton);
        }
        onWheel: (wheel) => {
            if (cell.item) {
                if (wheel.angleDelta.y !== 0)
                    cell.item.scroll(wheel.angleDelta.y, false);

                if (wheel.angleDelta.x !== 0)
                    cell.item.scroll(wheel.angleDelta.x, true);

            }
            wheel.accepted = true;
        }
    }

    Behavior on x {
        enabled: !!cell.tray && cell.tray.slotsReady

        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

}
