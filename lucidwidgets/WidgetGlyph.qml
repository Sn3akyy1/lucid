import QtQuick
import qs
import qs.lucidui

Item {
    id: glyph

    // every path below is authored on material's 24x24 grid
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
        "widgets": "widgets"
    })
    property string name: "clock"
    property color color: Theme.subtext
    property real size: 18

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
