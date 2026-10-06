import QtQuick
import qs
import qs.lucidui

Item {
    id: glyph

    property string kind: ""
    property color color: Theme.subtext
    property real size: Theme.dp(20)

    readonly property string path: ({
        "headphones": "headphones",
        "phone": "smartphone",
        "tablet": "tablet_android",
        "laptop": "computer",
        "desktop": "desktop_windows",
        "tv": "tv",
        "speaker": "speaker",
        "microphone": "mic",
        "webcam": "videocam",
        "keyboard": "keyboard",
        "mouse": "mouse",
        "watch": "watch",
        "gamepad": "sports_esports",
        "printer": "print",
        "car": "directions_car"
    })[glyph.kind] || "bluetooth"

    implicitWidth: glyph.size
    implicitHeight: glyph.size

    Icon {
        anchors.centerIn: parent
        name: glyph.path
        size: Math.round(glyph.size * 1.1)
        fill: 1
        color: glyph.color
    }

}
