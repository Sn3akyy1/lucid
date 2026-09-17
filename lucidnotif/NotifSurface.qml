import QtQuick
import qs

// a card in the shade: its own surface, swipes sideways to dismiss
Item {
    id: item

    property var notification: null
    property int radius: Theme.shapeLg
    property int groupCount: 0
    property string groupKey: ""
    property bool inGroup: false
    // false on the lock screen, where a card must not be able to start anything
    property bool interactive: true

    property real arrivalGlow: 0
    readonly property real throwLimit: Math.max(56, item.width * 0.3)
    readonly property bool grouped: item.groupCount > 1

    implicitHeight: surface.height
    height: surface.height
    Component.onCompleted: {
        if (item.notification && Notifs.markShown(item.notification.id))
            glowAnim.start();

    }

    Rectangle {
        id: surface

        width: item.width
        height: body.implicitHeight + 22
        radius: item.radius
        color: item.arrivalGlow > 0 ? Theme._mix(Theme.bgHover, body.tint, item.arrivalGlow * 0.3) : Theme.bgHover
        opacity: 1 - Math.min(0.85, Math.abs(x) / (item.width * 0.8))
        clip: true

        NotifCard {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 13
            anchors.rightMargin: 13
            anchors.topMargin: 11
            notification: item.notification
            interactive: item.interactive
            bodyLines: 6
            showAppName: !item.inGroup
            showAvatar: !item.inGroup

            // the collapsed head of a stack shows how deep it goes
            trailingContent: [
                Row {
                    spacing: 2
                    visible: item.grouped

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(18, countText.implicitWidth + 12)
                        height: 18
                        radius: height / 2
                        color: Theme.bgHigh

                        Text {
                            id: countText

                            anchors.centerIn: parent
                            text: item.groupCount
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(10)
                        }

                    }

                    NotifGhostButton {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 22
                        iconSize: 15
                        iconPath: Notifs.icons.expand_more
                        onClicked: Notifs.toggleGroup(item.groupKey)
                    }

                }
            ]
        }

        MouseArea {
            id: dragArea

            property bool moved: false

            anchors.fill: parent
            z: -1
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            drag.target: surface
            drag.axis: Drag.XAxis
            drag.minimumX: -item.width
            drag.maximumX: item.width
            onPressed: dragArea.moved = false
            onPositionChanged: {
                if (Math.abs(surface.x) > 4)
                    dragArea.moved = true;

            }
            onReleased: {
                if (Math.abs(surface.x) > item.throwLimit)
                    throwOut.start();
                else
                    snapBack.start();
            }
            onClicked: {
                if (dragArea.moved)
                    return ;

                if (item.grouped) {
                    Notifs.toggleGroup(item.groupKey);
                    return ;
                }
                // a lone card behaves like its popup did: open what sent it
                const n = item.notification;
                if (!n || !n.actions)
                    return ;

                for (var i = 0; i < n.actions.length; i++) {
                    if (n.actions[i].identifier === "default") {
                        Notifs.invokeAction(n.actions[i]);
                        return ;
                    }
                }
            }
        }

        NumberAnimation {
            id: snapBack

            target: surface
            property: "x"
            to: 0
            duration: Theme.ms(260)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

        NumberAnimation {
            id: throwOut

            target: surface
            property: "x"
            to: surface.x > 0 ? item.width * 1.15 : -item.width * 1.15
            duration: Theme.ms(190)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedAccel
            onFinished: Notifs.dismiss(item.notification)
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(220)
            }

        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.ms(260)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

    }

    NumberAnimation {
        id: glowAnim

        target: item
        property: "arrivalGlow"
        from: 1
        to: 0
        duration: Theme.ms(900)
        easing.type: Easing.InCubic
    }

}
