import QtQuick
import qs
import qs.lucidui

// a slider lying down, its icon at the start (a tap mutes, where it can), and
// a button after it where there is a list to pick from
Row {
    id: ls

    property string icon: ""
    property real value: 0
    property bool muted: false
    property bool iconClickable: false
    property string footIcon: ""
    property bool easeValue: false

    signal moved(real v)
    signal iconClicked()
    signal footClicked()

    spacing: Theme.dp(8)

    Slider {
        width: ls.width - (foot.visible ? foot.width + ls.spacing : 0)
        size: "m"
        icon: ls.icon
        iconClickable: ls.iconClickable
        from: 0
        to: 100
        value: ls.value
        activeColor: ls.muted ? Theme.outlineStrong : Theme.primary
        inactiveColor: Theme.withBlur(Theme.surfaceHighest)
        easeValue: ls.easeValue
        valueText: (v) => {
            return Math.round(v) + "%";
        }
        onMoved: (v) => {
            return ls.moved(v);
        }
        onIconClicked: ls.iconClicked()
    }

    Rectangle {
        id: foot

        visible: ls.footIcon !== ""
        width: Theme.dp(50)
        height: Theme.dp(38)
        anchors.verticalCenter: parent.verticalCenter
        radius: Theme.rad(12)
        color: Theme.withBlur(Theme.surfaceHighest)

        StateLayer {
            radius: parent.radius
            onClicked: ls.footClicked()
        }

        Icon {
            anchors.centerIn: parent
            name: ls.footIcon
            size: Theme.dp(20)
            color: Theme.subtext
        }

    }

}
