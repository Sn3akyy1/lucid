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

    implicitWidth: b.dot ? 6 : Math.max(16, num.implicitWidth + 8)
    implicitHeight: b.dot ? 6 : 16
    radius: height / 2
    color: b.tone

    LText {
        id: num

        visible: !b.dot
        anchors.centerIn: parent
        role: "labelSmall"
        weight: 650
        size: Theme.fs(10.5)
        color: b.fg
        text: b.count > b.max ? b.max + "+" : String(b.count)
    }

}
