import QtQuick
import qs
import qs.lucidui

// a phone's reception, as the cellular symbol that matches it
Icon {
    id: bars

    // 0-100
    property real strength: 0
    readonly property int lit: Math.max(0, Math.min(4, Math.ceil(bars.strength / 25)))

    name: ["signal_cellular_0_bar", "signal_cellular_1_bar", "signal_cellular_2_bar", "signal_cellular_3_bar", "signal_cellular_4_bar"][bars.lit]
    size: 17
    fill: 1
    color: Theme.accent
}
