import QtQuick
import qs
import qs.lucidui

// a slider lying down, its icon at the start (a tap mutes, where it can), and
// a button after it where there is a list to pick from. its looks: plain;
// bold, thicker with the value inside; thin, a fine track with the icon
// before it and the value after; round, with capsule ends
Row {
    id: ls

    property string icon: ""
    property real value: 0
    property bool muted: false
    property bool iconClickable: false
    property string footIcon: ""
    property bool easeValue: false
    // plain, bold, thin or round
    property string look: "plain"
    readonly property bool bold: ls.look === "bold"
    readonly property bool thin: ls.look === "thin"

    signal moved(real v)
    signal iconClicked()
    signal footClicked()

    spacing: Theme.dp(8)

    // thin: the icon out before the track
    Item {
        visible: ls.thin
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.dp(32)
        height: Theme.dp(32)

        Icon {
            anchors.centerIn: parent
            name: ls.icon
            size: Theme.dp(20)
            color: ls.muted ? Theme.subtext : Theme.primary
        }

        StateLayer {
            visible: ls.iconClickable
            radius: width / 2
            onClicked: ls.iconClicked()
        }

    }

    Slider {
        width: ls.width - (foot.visible ? foot.width + ls.spacing : 0) - (ls.thin ? Theme.dp(32) + Theme.dp(44) + ls.spacing * 2 : 0)
        anchors.verticalCenter: parent.verticalCenter
        size: ls.bold ? "l" : (ls.thin ? "s" : "m")
        inlineValue: ls.bold
        showValue: !ls.thin
        outerR: ls.look === "round" ? Theme.dp(19) : (ls.bold ? Theme.dp(16) : (ls.thin ? Theme.dp(11) : Theme.dp(12)))
        icon: ls.thin ? "" : ls.icon
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

    // thin: the value after the track
    LText {
        visible: ls.thin
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.dp(44)
        horizontalAlignment: Text.AlignRight
        role: "labelLarge"
        weight: 640
        tabular: true
        color: ls.muted ? Theme.subtext : Theme.text
        text: Math.round(ls.value) + "%"
    }

    Rectangle {
        id: foot

        visible: ls.footIcon !== ""
        width: ls.thin ? Theme.dp(36) : Theme.dp(50)
        height: ls.bold ? Theme.dp(52) : (ls.thin ? Theme.dp(32) : Theme.dp(38))
        anchors.verticalCenter: parent.verticalCenter
        radius: ls.look === "round" || ls.thin ? height / 2 : (ls.bold ? Theme.rad(16) : Theme.rad(12))
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
