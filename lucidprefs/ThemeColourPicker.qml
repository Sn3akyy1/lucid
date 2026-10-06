import QtQuick
import Quickshell
import Quickshell.Io
import qs

// the one colour the "colour" theme is built from: typed as hex, picked from
// anywhere on screen with hyprpicker, or one of a few to start from
Column {
    id: picker

    property string colour: "#6750a4"
    // whether the colour theme is the one on screen, so there is no "Use it"
    property bool inUse: false
    property bool invalid: false
    readonly property var presets: ["#6750a4", "#3f51b5", "#1a73e8", "#0097a7", "#00897b", "#1e8e3e", "#7cb342", "#f9ab00", "#e8710a", "#b3261e", "#d81b60", "#795548", "#607d8b"]

    signal picked(string hex)
    signal useIt()

    // #rgb stays a mistake: matugen wants all six digits
    function accept(text) {
        var t = text.trim();
        if (!/^#?[0-9a-fA-F]{6}$/.test(t))
            return false;

        t = (t.charAt(0) === "#" ? t : "#" + t).toLowerCase();
        picker.invalid = false;
        picker.picked(t);
        return true;
    }

    function choose(hex) {
        hexField.set(hex);
        picker.accept(hex);
    }

    spacing: Theme.dp(14)

    Row {
        spacing: Theme.dp(12)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(46)
            height: Theme.dp(46)
            radius: Theme.radiusMd
            color: picker.colour
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.2)
        }

        M3TextField {
            id: hexField

            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(150)
            text: picker.colour
            placeholder: "#rrggbb"
            error: picker.invalid
            onEdited: (v) => {
                // a full colour applies as it is typed; half of one waits
                if (v.trim().length >= 6)
                    picker.invalid = !picker.accept(v);
                else
                    picker.invalid = false;
            }
            onAccepted: (v) => {
                picker.invalid = !picker.accept(v);
            }
        }

        M3Button {
            anchors.verticalCenter: parent.verticalCenter
            text: screenPick.running ? "Picking..." : "Pick from screen"
            enabled: !screenPick.running
            // eyedropper
            iconPath: "colorize"
            onClicked: {
                // no -q: in hyprpicker it silences the colour itself too
                screenPick.command = ["hyprpicker", "-f", "hex", "-b", "-l"];
                screenPick.running = true;
            }
        }

        M3Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "Use it"
            variant: "filled"
            visible: !picker.inUse
            onClicked: picker.useIt()
        }

    }

    Flow {
        width: picker.width
        spacing: Theme.dp(8)

        Repeater {
            model: picker.presets

            delegate: Rectangle {
                id: preset

                required property string modelData
                readonly property bool current: picker.colour.toLowerCase() === preset.modelData

                width: Theme.dp(34)
                height: Theme.dp(34)
                radius: height / 2
                color: preset.modelData
                border.width: preset.current ? 3 : (presetArea.containsMouse ? 2 : 0)
                border.color: Theme.text

                MouseArea {
                    id: presetArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.choose(preset.modelData)
                }

            }

        }

    }

    Process {
        id: screenPick

        stdout: StdioCollector {
            onStreamFinished: {
                // nothing when the pick was cancelled
                var hex = text.trim();
                if (hex !== "")
                    picker.choose(hex);

            }
        }

    }

}
