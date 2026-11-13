import QtQuick
import QtQuick.Effects
import qs

// one app in the collapsed look's stack: the first few icons overlapped, each
// behind the one before it, with a gap cut out where that one lies over it. a
// ring in the bar's colour would show as a second coat on a glass pill, so the
// gap is a hole in the icon instead
Item {
    id: pi

    required property int index
    required property int serial
    required property bool leaving
    property var tray: null
    readonly property var item: pi.tray ? pi.tray.itemOf(pi.serial) : null
    // its place among the apps staying; the first one is in front
    readonly property int rank: pi.tray ? pi.tray.rankOf(pi.serial) : -1
    readonly property bool inPile: !pi.leaving && pi.rank >= 0 && !!pi.tray && pi.rank < pi.tray.pileMax
    readonly property real gap: Theme.barDp(2)
    property real present: pi.inPile ? 1 : 0

    width: pi.tray ? pi.tray.glyph : 0
    height: pi.width
    x: pi.tray ? Math.max(0, Math.min(pi.rank, pi.tray.pileMax - 1)) * pi.tray.pileStep : 0
    z: -Math.max(0, pi.rank)
    opacity: pi.present
    scale: 0.6 + 0.4 * pi.present
    visible: pi.present > 0.01

    Item {
        anchors.fill: parent
        layer.enabled: pi.rank > 0
        layer.smooth: true

        TrayIcon {
            anchors.centerIn: parent
            item: pi.item
            size: pi.width
        }

        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: cut
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

    }

    // the one in front, a gap larger all round, as this icon sees it
    Item {
        id: cut

        width: pi.width
        height: pi.height
        visible: false
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            x: -(pi.tray ? pi.tray.pileStep : 0) - pi.gap
            y: -pi.gap
            width: pi.width + 2 * pi.gap
            height: pi.height + 2 * pi.gap
            radius: width * 0.32
            antialiasing: true
            color: "black"
        }

    }

    Behavior on present {
        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    Behavior on x {
        enabled: !!pi.tray && pi.tray.slotsReady

        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

}
