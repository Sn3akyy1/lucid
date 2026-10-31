import QtQuick
import qs
import qs.lucidui

// a plain tooltip, a beat after the pointer settles on whatever it sits in. on
// the shell's own surface rather than m3's inverse one, so it is dark in dark mode
Rectangle {
    id: tip

    property string text: ""
    property bool hovered: false
    // over its host while the toolbar sits low, under it while it sits high
    property bool above: true
    property bool ready: false

    visible: opacity > 0.01
    opacity: tip.ready && tip.hovered && tip.text !== "" ? 1 : 0
    z: 100
    width: label.implicitWidth + Theme.dp(16)
    height: Math.max(Theme.dp(24), label.implicitHeight + Theme.dp(8))
    radius: Theme.dp(4)
    color: Theme.surfaceHigh
    border.width: 1
    border.color: Theme.alpha(Theme.text, 0.1)
    x: Math.round((parent.width - tip.width) / 2)
    // clear of the toolbar's own edge, which sits up to 12dp past a button's
    y: tip.above ? -tip.height - Theme.dp(18) : parent.height + Theme.dp(18)
    onHoveredChanged: {
        if (tip.hovered) {
            delay.restart();
        } else {
            delay.stop();
            tip.ready = false;
        }
    }

    LText {
        id: label

        anchors.centerIn: parent
        role: "bodySmall"
        color: Theme.text
        text: tip.text
    }

    Timer {
        id: delay

        interval: 450
        onTriggered: tip.ready = true
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durFastEffects
        }

    }

}
