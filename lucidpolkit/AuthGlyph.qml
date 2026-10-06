import QtQuick
import qs
import qs.lucidui

// the badge glyph, picked from what the action actually touches
Item {
    id: glyph

    // every path below is authored on material's 24x24 grid
    readonly property var symbols: ({
        "shield": "shield_lock",
        "terminal": "terminal_2",
        "drive": "hard_drive",
        "power": "power_settings_new",
        "network": "wifi",
        "user": "person",
        "package": "package_2",
        "key": "key",
        "check": "check"
    })
    property string name: "shield"
    property color color: Theme.fgAccentContainer
    property real size: Theme.dp(22)

    implicitWidth: glyph.size
    implicitHeight: glyph.size

    Icon {
        anchors.centerIn: parent
        name: glyph.symbols[glyph.name] || "shield_lock"
        size: Math.round(glyph.size * 1.1)
        fill: 1
        color: glyph.color
    }

}
