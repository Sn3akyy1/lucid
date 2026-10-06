import QtQuick
import qs
import qs.lucidui

// the same symbols the bar's wifi panel draws, so one signal reads the same
// in both places. see lucidbar/WifiPanel.qml
Item {
    id: glyph

    // 0-100
    property real strength: 0
    property bool off: false
    property real size: Theme.dp(20)
    property color color: Theme.accent

    readonly property var levels: ["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "signal_wifi_4_bar"]

    implicitWidth: glyph.size
    implicitHeight: glyph.size

    Icon {
        anchors.centerIn: parent
        name: glyph.off ? "signal_wifi_off" : glyph.levels[Math.max(0, Math.min(4, Math.floor(glyph.strength / 20)))]
        size: Math.round(glyph.size * 1.1)
        fill: 1
        color: glyph.color
    }

}
