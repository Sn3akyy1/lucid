import QtQuick
import qs

// one waiting notification. it swipes up, back towards the bar it came from,
// because it lives inside the module's own clipping surface.
Item {
    id: popupCard

    property var notification: null
    property color surfaceColor: "transparent"
    property int radius: Theme.radiusLg
    property int sidePadding: 14
    // driven by the pill's swap animation; anchors own y, so this is a transform
    property real swapOffset: 0

    readonly property int notifId: popupCard.notification ? popupCard.notification.id : -1

    function defaultAction() {
        const n = popupCard.notification;
        if (!n || !n.actions)
            return null;

        for (var i = 0; i < n.actions.length; i++) {
            if (n.actions[i].identifier === "default")
                return n.actions[i];

        }
        return null;
    }

    function activate() {
        const a = popupCard.defaultAction();
        if (a)
            Notifs.invokeAction(a);
        else
            Notifs.shadeRequested();
        Notifs.popupDrop(popupCard.notifId);
    }

    // a replacement at the top should start from rest, not from a stale drag
    onNotificationChanged: sled.y = 0
    implicitHeight: body.implicitHeight + 22
    height: popupCard.implicitHeight
    transform: Translate {
        y: popupCard.swapOffset
    }

    Rectangle {
        anchors.fill: parent
        radius: popupCard.radius
        color: popupCard.surfaceColor
        clip: true

        Item {
            id: sled

            width: parent.width
            height: parent.height
            opacity: Math.max(0, 1 - (-sled.y) / 110)

            NotifCard {
                id: body

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: popupCard.sidePadding
                anchors.rightMargin: popupCard.sidePadding
                anchors.topMargin: 11
                notification: popupCard.notification
                bodyLines: Prefs.toastBodyLines
                onReplyToggled: (open) => {
                    Notifs.replyingId = open ? popupCard.notifId : -1;
                }
            }

            MouseArea {
                id: dragArea

                property bool moved: false

                anchors.fill: parent
                // the chips and the reply field sit above this and take their own clicks
                z: -1
                cursorShape: Qt.PointingHandCursor
                drag.target: sled
                drag.axis: Drag.YAxis
                drag.minimumY: -(sled.height + 40)
                drag.maximumY: 0
                onPressed: dragArea.moved = false
                onPositionChanged: {
                    if (Math.abs(sled.y) > 4)
                        dragArea.moved = true;

                }
                onReleased: {
                    if (-sled.y > 34)
                        throwOut.start();
                    else
                        snapBack.start();
                }
                onClicked: {
                    if (!dragArea.moved)
                        popupCard.activate();

                }
            }

            NumberAnimation {
                id: snapBack

                target: sled
                property: "y"
                to: 0
                duration: Theme.ms(240)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

            NumberAnimation {
                id: throwOut

                target: sled
                property: "y"
                to: -(sled.height + 40)
                duration: Theme.ms(190)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedAccel
                onFinished: Notifs.dismiss(popupCard.notification)
            }

        }

    }

}
