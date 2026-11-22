import QtQuick
import QtQuick.Shapes
import "symbols.js" as Symbols

// a material symbol, filled, from the table cut out of the shell's own. the
// lock and the login screen both draw through this, so they share outlines
Item {
    id: glyph

    // the old lock names, so callers can keep speaking them
    readonly property var aliases: ({
        "lock": "lock",
        "lockOpen": "lock_open",
        "arrow": "arrow_forward",
        "eye": "visibility",
        "eyeOff": "visibility_off",
        "caps": "keyboard_capslock",
        "wifi": "signal_wifi_4_bar",
        "wifiOff": "signal_wifi_off",
        "ethernet": "lan",
        "bluetoothOff": "bluetooth_disabled",
        "bell": "notifications",
        "bellOff": "notifications_off",
        "power": "power_settings_new",
        "restart": "restart_alt",
        "suspend": "bedtime",
        "hibernate": "ac_unit",
        "finger": "fingerprint",
        "host": "computer",
        "session": "desktop_windows",
        "expand": "expand_more",
        "back": "arrow_back",
        "personAdd": "person_add",
        "music": "music_note"
    })
    property string name: "lock"
    property color color: "white"
    property real size: 20
    readonly property string path: Symbols.p[glyph.aliases[glyph.name] || glyph.name] || ""
    // the symbols sit a touch small in their box, as the shell's Icon draws them
    readonly property real drawn: Math.round(glyph.size * 1.1)

    implicitWidth: Math.round(glyph.size)
    implicitHeight: Math.round(glyph.size)
    // the curve renderer chips a corner where it meets an edge at small sizes
    layer.enabled: glyph.path !== "" && glyph.width > 0
    layer.samples: 8
    layer.smooth: true

    Shape {
        x: (glyph.width - glyph.drawn) / 2
        y: (glyph.height - glyph.drawn) / 2
        width: 24
        height: 24
        visible: glyph.path !== ""
        preferredRendererType: Shape.GeometryRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: glyph.color

            PathSvg {
                path: glyph.path
            }

        }

        transform: Scale {
            xScale: glyph.drawn / 24
            yScale: glyph.drawn / 24
        }

    }

}
