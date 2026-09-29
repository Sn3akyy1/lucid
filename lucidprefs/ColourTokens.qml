import QtQuick
import Quickshell
import qs

// every colour role the last change had, as a swatch. clicking one copies the
// matugen variable that writes it, in the format picked above them
Column {
    id: tokens

    property string format: "hex"
    property string copied: ""
    readonly property var formats: [{
        "key": "hex",
        "label": "#rrggbb"
    }, {
        "key": "hex_stripped",
        "label": "rrggbb"
    }, {
        "key": "rgb",
        "label": "rgb()"
    }, {
        "key": "rgba",
        "label": "rgba()"
    }, {
        "key": "hsl",
        "label": "hsl()"
    }]

    function variable(role) {
        return "{{colors." + role + ".default." + tokens.format + "}}";
    }

    spacing: 14

    M3Segmented {
        width: Math.min(tokens.width, 440)
        current: tokens.format
        options: tokens.formats
        onChosen: (key) => {
            return tokens.format = key;
        }
    }

    Text {
        width: tokens.width
        text: Templates.roles.length === 0 ? "There are no colours yet. They come with the next change of theme or wallpaper." : (tokens.copied !== "" ? "Copied " + tokens.copied : "Click a colour to copy its variable.")
        color: tokens.copied !== "" ? Theme.accent : Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBody
        wrapMode: Text.WordWrap
    }

    Flow {
        width: tokens.width
        spacing: 6

        Repeater {
            model: Templates.roles

            delegate: Rectangle {
                id: chip

                required property string modelData
                readonly property string hex: Templates.colours[chip.modelData] || "#000000"

                width: chipRow.implicitWidth + 20
                height: 34
                radius: height / 2
                color: chipArea.containsMouse ? Theme.bgHigh : Theme.bgSunken

                Row {
                    id: chipRow

                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        radius: height / 2
                        color: chip.hex
                        border.width: 1
                        border.color: Theme.alpha(Theme.text, 0.18)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                    }

                }

                MouseArea {
                    id: chipArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var v = tokens.variable(chip.modelData);
                        Quickshell.execDetached(["wl-copy", v]);
                        tokens.copied = v;
                        forget.restart();
                    }
                }

            }

        }

    }

    Timer {
        id: forget

        interval: 4000
        onTriggered: tokens.copied = ""
    }

}
