import QtQuick
import qs

// m3 badge: a 6px dot, or a 16px pill with a count
Rectangle {
    id: b

    property int count: -1
    property int max: 99
    property color tone: Theme.error
    property color fg: Theme.fgError
    readonly property bool dot: b.count < 0

    implicitWidth: b.dot ? Theme.dp(6) : Math.max(Theme.dp(16), num.implicitWidth + Theme.dp(8))
    implicitHeight: b.dot ? Theme.dp(6) : Theme.dp(16)
    radius: height / 2
    color: b.tone

    // digits sit on the baseline, so centring the line box leaves the number
    // riding high. place the baseline instead, so the cap-height box centres
    TextMetrics {
        id: cap

        font: num.font
        text: "7"
    }

    FontMetrics {
        id: fm

        font: num.font
    }

    LText {
        id: num

        visible: !b.dot
        anchors.horizontalCenter: parent.horizontalCenter
        y: (b.height - cap.tightBoundingRect.height) / 2 - cap.tightBoundingRect.y - fm.ascent
        role: "labelSmall"
        weight: 650
        size: Theme.fs(10.5)
        color: b.fg
        text: b.count > b.max ? b.max + "+" : String(b.count)
    }

}
