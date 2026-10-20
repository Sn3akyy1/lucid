import QtQuick
import qs
import qs.lucidui

// a slider standing up: the one that lies down, turned so it fills from the
// bottom, its icon at the foot still upright (a tap mutes, where it can), and
// a button under it where there is a list to pick from
Item {
    id: vs

    property string icon: ""
    property real value: 0
    property bool muted: false
    property bool iconClickable: false
    property string footIcon: ""
    property bool easeValue: false
    // thicker
    property bool bold: false

    signal moved(real v)
    signal iconClicked()
    signal footClicked()

    width: Theme.dp(56)

    Item {
        id: room

        anchors.top: parent.top
        anchors.bottom: foot.visible ? foot.top : parent.bottom
        anchors.bottomMargin: foot.visible ? Theme.dp(8) : 0
        width: parent.width

        Slider {
            id: slider

            anchors.centerIn: parent
            width: room.height
            rotation: -90
            size: "m"
            // thicker, handle and all still inside the column
            trackH: vs.bold ? Theme.dp(46) : Theme.dp(38)
            handleH: vs.bold ? Theme.dp(52) : Theme.dp(50)
            icon: vs.icon
            iconTurn: 90
            iconClickable: vs.iconClickable
            showValue: false
            from: 0
            to: 100
            value: vs.value
            activeColor: vs.muted ? Theme.outlineStrong : Theme.primary
            inactiveColor: Theme.withBlur(Theme.surfaceHighest)
            easeValue: vs.easeValue
            onMoved: (v) => {
                return vs.moved(v);
            }
            onIconClicked: vs.iconClicked()
        }

        // the value over the handle while it is dragged, as the lying one shows it
        Rectangle {
            visible: opacity > 0.01
            opacity: slider.dragging ? 1 : 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: room.height - slider.handleX - slider.handleHNow / 2 - height - Theme.dp(8)
            width: Math.max(Theme.dp(36), bubbleText.implicitWidth + Theme.dp(20))
            height: Theme.dp(30)
            radius: Theme.dp(15)
            color: Theme.inverseSurface

            LText {
                id: bubbleText

                anchors.centerIn: parent
                role: "labelLarge"
                color: Theme.fgInverseSurface
                text: Math.round(slider.live) + "%"
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durFastEffects
                }

            }

        }

    }

    Rectangle {
        id: foot

        visible: vs.footIcon !== ""
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Theme.dp(50)
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
