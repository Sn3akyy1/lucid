import QtQuick
import qs
import qs.lucidui

Item {
    id: glyph

    // the lock's names for material symbols
    readonly property var symbols: ({
        "lock": "lock",
        "lockOpen": "lock_open",
        "key": "key",
        "arrow": "arrow_forward",
        "check": "check",
        "close": "close",
        "eye": "visibility",
        "eyeOff": "visibility_off",
        "caps": "keyboard_capslock",
        "wifi": "signal_wifi_4_bar",
        "wifiOff": "signal_wifi_off",
        "ethernet": "lan",
        "bluetooth": "bluetooth",
        "bluetoothOff": "bluetooth_disabled",
        "batteryCharge": "battery_charging_full",
        "bell": "notifications",
        "bellOff": "notifications_off",
        "play": "play_arrow",
        "pause": "pause",
        "next": "skip_next",
        "prev": "skip_previous",
        "music": "music_note",
        "power": "power_settings_new",
        "restart": "restart_alt",
        "logout": "logout",
        "suspend": "bedtime",
        "hibernate": "ac_unit"
    })
    property string name: "lock"
    property color color: Theme.text
    property real size: Theme.dp(20)
    property real fill: 1

    implicitWidth: Math.round(glyph.size)
    implicitHeight: Math.round(glyph.size)

    Icon {
        anchors.centerIn: parent
        name: glyph.symbols[glyph.name] || glyph.name
        size: Math.round(glyph.size * 1.1)
        fill: glyph.fill
        color: glyph.color
    }

}
