import QtQuick
import qs

Row {
    id: bars

    // 0-100
    property real strength: 0
    property color onColor: Theme.accent
    property color offColor: Theme.bgTrack
    property int count: 4
    property real unit: 3.5

    readonly property int lit: Math.max(0, Math.min(bars.count, Math.ceil(bars.strength / (100 / bars.count))))

    height: 4 + (bars.count - 1) * bars.unit + 4
    spacing: 2

    Repeater {
        model: bars.count

        Rectangle {
            required property int index

            width: 3
            height: 4 + index * bars.unit
            y: bars.height - height
            radius: 1.5
            color: index < bars.lit ? bars.onColor : bars.offColor

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durQuick
                }

            }

        }

    }

}
