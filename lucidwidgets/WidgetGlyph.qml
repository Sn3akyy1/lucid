import QtQuick
import QtQuick.Shapes
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
    // raw 24x24 path data, for an icon that lives in another singleton (Power)
    property string path: ""
    property color color: Theme.subtext
    property real size: 18

    implicitWidth: glyph.size
    implicitHeight: glyph.size

    Icon {
        visible: glyph.path === ""
        anchors.centerIn: parent
        name: glyph.symbols[glyph.name] || glyph.name
        size: Math.round(glyph.size * 1.1)
        fill: 1
        color: glyph.color
    }

    // raw path data from elsewhere (Power's profile icons) draws as it comes
    Shape {
        visible: glyph.path !== ""
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: glyph.color

            PathSvg {
                path: glyph.path
            }

        }

        transform: Scale {
            xScale: glyph.size / 24
            yScale: glyph.size / 24
        }

    }

}
