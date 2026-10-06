import QtQuick
import qs
import qs.lucidui

Item {
    id: glyph

    // widget glyph names, as the material symbols they draw
    readonly property var symbols: ({
        "clock": "schedule",
        "calendar": "calendar_month",
        "system": "speed",
        "battery": "battery_full",
        "media": "music_note",
        "weather": "partly_cloudy_day",
        "visualiser": "equalizer",
        "notes": "sticky_note_2",
        "todo": "checklist",
        "palette": "palette",
        "kdeconnect": "smartphone",
        "timer": "timer",
        "glance": "wb_twilight",
        "photo": "photo_library",
        "fetch": "terminal",
        "phone": "smartphone",
        "ring": "notifications_active",
        "clipboard": "content_paste",
        "lock": "lock",
        "share": "share",
        "send": "send",
        "grip": "drag_indicator",
        "pin": "keep",
        "close": "close",
        "tune": "tune",
        "layers": "layers",
        "play": "play_arrow",
        "pause": "pause",
        "next": "skip_next",
        "prev": "skip_previous",
        "add": "add",
        "check": "check",
        "trash": "delete",
        "refresh": "refresh",
        "chevron": "chevron_right",
        "bolt": "bolt",
        "drop": "water_drop",
        "wind": "air",
        "widgets": "widgets",
        "thermal": "thermostat",
        "network": "swap_vert",
        "games": "sports_esports",
        "fan": "mode_fan",
        "bell": "notifications",
        "folder": "folder",
        "wifi": "wifi",
        "lan": "lan",
        "shield": "shield",
        "down": "arrow_downward",
        "up": "arrow_upward",
        "flag": "flag"
    })
    property string name: "clock"
    property color color: Theme.subtext
    property real size: Theme.dp(18)

    implicitWidth: glyph.size
    implicitHeight: glyph.size

    Icon {
        anchors.centerIn: parent
        name: glyph.symbols[glyph.name] || glyph.name
        size: Math.round(glyph.size * 1.1)
        fill: 1
        color: glyph.color
    }

}
