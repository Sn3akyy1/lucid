import QtQuick
import Quickshell
import qs
import qs.lucidui

// the eyedropper: the colour under the pointer, read from the file itself, rides
// beside it; a click copies it
Item {
    id: picker

    required property var win
    required property var stage
    property bool active: false
    property string hex: ""
    property point at
    property bool inside: false
    property bool _asking: false
    property var _again: null

    // what the pointer is over, in the picture's own pixels, or null off it
    function pixelAt(x, y) {
        var pic = picker.stage.current;
        if (!pic || !pic.ready)
            return null;

        var p = pic.body.mapFromItem(picker, x, y);
        if (p.x < 0 || p.y < 0 || p.x >= pic.natW || p.y >= pic.natH)
            return null;

        // a neighbour decoded small reads the same spot in the full file
        var k = picker.win.info && picker.win.info.w ? picker.win.info.w / Math.max(1, pic.natW) : 1;
        return Qt.point(Math.floor(p.x * k), Math.floor(p.y * k));
    }

    function ask(x, y) {
        var c = picker.win.current, px = picker.pixelAt(x, y);
        picker.inside = px !== null;
        if (!c || !px)
            return ;

        // one question at a time: the newest waits its turn, the rest are dropped
        if (picker._asking) {
            picker._again = Qt.point(x, y);
            return ;
        }
        picker._asking = true;
        picker.win.app.call("pixel", {
            "path": c.decoded || c.path,
            "x": px.x,
            "y": px.y
        }, function(r) {
            picker._asking = false;
            if (r.ok)
                picker.hex = r.hex;

            var next = picker._again;
            picker._again = null;
            if (next)
                picker.ask(next.x, next.y);

        });
    }

    onActiveChanged: {
        picker.hex = "";
        picker.inside = false;
    }
    visible: picker.active

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.CrossCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPositionChanged: (mouse) => {
            picker.at = Qt.point(mouse.x, mouse.y);
            picker.ask(mouse.x, mouse.y);
        }
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton || !picker.inside || picker.hex === "") {
                picker.win.picking = false;
                return ;
            }
            Quickshell.execDetached(["wl-copy", picker.hex]);
            picker.win.say("Copied " + picker.hex.toUpperCase());
            picker.win.picking = false;
        }
    }

    Rectangle {
        x: Math.min(picker.width - width - Theme.dp(8), picker.at.x + Theme.dp(18))
        y: Math.min(picker.height - height - Theme.dp(8), picker.at.y + Theme.dp(18))
        width: row.implicitWidth + Theme.dp(20)
        height: Theme.dp(44)
        radius: height / 2
        color: Theme.alpha(Theme.surfaceHigh, 0.94)
        visible: picker.inside && picker.hex !== ""

        Row {
            id: row

            anchors.verticalCenter: parent.verticalCenter
            x: Theme.dp(8)
            spacing: Theme.dp(10)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(28)
                height: width
                radius: width / 2
                color: picker.hex || "transparent"
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.2)
            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "labelLarge"
                tabular: true
                text: picker.hex.toUpperCase()
            }

        }

    }

    // how to use it, at the top until the pointer finds the picture
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.dp(16)
        width: hint.implicitWidth + Theme.dp(32)
        height: Theme.dp(40)
        radius: height / 2
        color: Theme.alpha(Theme.surfaceHigh, 0.94)

        LText {
            id: hint

            anchors.centerIn: parent
            role: "labelLarge"
            text: "Click to copy a colour  ·  Esc to stop"
        }

    }

}
