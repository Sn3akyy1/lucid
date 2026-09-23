import QtQuick
import qs
import qs.lucidui

// 24dp material paths, by the name the layout tables use
Item {
    id: glyph

    property string name: ""
    property color glyphColor: Theme.text

    readonly property var symbols: ({
        "backspace": "backspace",
        "enter": "keyboard_return",
        "tab": "keyboard_tab",
        "shift": "shift",
        "caps": "keyboard_capslock",
        "left": "chevron_left",
        "right": "chevron_right",
        "up": "keyboard_arrow_up",
        "down": "keyboard_arrow_down",
        "close": "close",
        "grip": "drag_indicator",
        "minus": "remove",
        "plus": "add",
        "prev": "skip_previous",
        "play": "play_pause",
        "next": "skip_next",
        "mute": "volume_off",
        "voldown": "volume_down",
        "volup": "volume_up",
        "dim": "brightness_low",
        "bright": "brightness_high"
    })
    readonly property string pathData: glyph.symbols[glyph.name] || ""

    implicitWidth: 24
    implicitHeight: 24
    visible: glyph.pathData !== ""

    Icon {
        anchors.centerIn: parent
        name: glyph.pathData
        size: Math.round(Math.min(glyph.width, glyph.height) * 1.1)
        fill: 1
        color: glyph.glyphColor
    }

}
