import QtQuick
import qs

// the same nerd font glyphs the bar's system pill uses, so one signal reads
// the same in both places. see lucidbar/System.qml
Text {
    id: glyph

    // 0-100
    property real strength: 0
    property bool off: false
    property real size: 20

    readonly property var levels: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]

    text: glyph.off ? "󰤮" : glyph.levels[Math.max(0, Math.min(4, Math.floor(glyph.strength / 20)))]
    color: Theme.accent
    font.family: Theme.fontFamily
    font.pixelSize: glyph.size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
