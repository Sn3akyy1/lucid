import QtQuick
import qs
import qs.lucidui

// a slider standing up, on the grid: the level fills a tall pill
// from the bottom, its icon at the foot (a tap mutes, where it can), the
// value over it, and a button under it where there is a list to pick from
Item {
    id: vs

    property string icon: ""
    property real value: 0
    property bool muted: false
    property bool iconClickable: false
    property string footIcon: ""
    property real dragValue: -1
    readonly property real shownValue: vs.dragValue >= 0 ? vs.dragValue : vs.value
    readonly property real level: Math.max(0, Math.min(1, vs.shownValue / 100))

    signal moved(real v)
    signal iconClicked()
    signal footClicked()

    width: Theme.dp(56)

    LText {
        id: vsValue

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        role: "labelMedium"
        weight: 600
        color: vs.muted ? Theme.subtextDim : Theme.subtext
        text: Math.round(vs.shownValue) + "%"
    }

    Rectangle {
        id: vsTrack

        anchors.top: vsValue.bottom
        anchors.topMargin: Theme.dp(4)
        anchors.bottom: vsFoot.visible ? vsFoot.top : parent.bottom
        anchors.bottomMargin: vsFoot.visible ? Theme.dp(8) : 0
        width: parent.width
        radius: Theme.rad(18)
        color: Theme.withBlur(Theme.surfaceHighest)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            // never shorter than its own round end, so the icon always sits on it
            height: Math.max(width, parent.height * vs.level)
            radius: parent.radius
            color: vs.muted ? Theme.outlineStrong : Theme.primary

            Behavior on height {
                enabled: vs.dragValue < 0

                NumberAnimation {
                    duration: Theme.barMs(160)
                    easing.type: Easing.OutCubic
                }

            }

        }

        MouseArea {
            function valueAt(my) {
                return Math.round(Math.max(0, Math.min(100, (1 - my / vsTrack.height) * 100)));
            }

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: (mouse) => {
                vs.dragValue = valueAt(mouse.y);
                vs.moved(vs.dragValue);
            }
            onPositionChanged: (mouse) => {
                if (!pressed)
                    return ;

                vs.dragValue = valueAt(mouse.y);
                vs.moved(vs.dragValue);
            }
            onReleased: vs.dragValue = -1
            onCanceled: vs.dragValue = -1
            onWheel: (wheel) => {
                vs.moved(Math.max(0, Math.min(100, vs.value + (wheel.angleDelta.y > 0 ? 5 : -5))));
            }
        }

        Item {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: parent.width

            Icon {
                anchors.centerIn: parent
                name: vs.icon
                size: Theme.dp(22)
                fill: 1
                color: vs.muted ? Theme.text : Theme.fgPrimary
            }

            StateLayer {
                visible: vs.iconClickable
                radius: vsTrack.radius
                tint: Theme.fgPrimary
                onClicked: vs.iconClicked()
            }

        }

    }

    Rectangle {
        id: vsFoot

        visible: vs.footIcon !== ""
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.dp(38)
        radius: Theme.rad(12)
        color: Theme.withBlur(Theme.surfaceHighest)

        StateLayer {
            radius: parent.radius
            onClicked: vs.footClicked()
        }

        Icon {
            anchors.centerIn: parent
            name: vs.footIcon
            size: Theme.dp(20)
            color: Theme.subtext
        }

    }

}
