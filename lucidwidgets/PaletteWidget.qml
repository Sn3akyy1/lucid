import QtQuick
import Quickshell
import qs

WidgetBody {
    id: w

    readonly property bool showHex: w.opt("showHex") !== false
    readonly property var roles: [{
        "name": "Primary",
        "color": Theme.accent,
        "on": Theme.fgAccent
    }, {
        "name": "Container",
        "color": Theme.accentContainer,
        "on": Theme.fgAccentContainer
    }, {
        "name": "Secondary",
        "color": Theme.secondaryContainer,
        "on": Theme.fgSecondaryContainer
    }, {
        "name": "Tertiary",
        "color": Theme.tertiaryContainer,
        "on": Theme.fgTertiaryContainer
    }, {
        "name": "Surface",
        "color": Theme.bgTile,
        "on": Theme.text
    }, {
        "name": "Error",
        "color": Theme.errorContainer,
        "on": Theme.fgErrorContainer
    }]
    readonly property var tones: [95, 85, 75, 65, 55, 45, 35, 25, 15]

    property string copied: ""

    function copy(hex) {
        Quickshell.execDetached(["wl-copy", "--", hex]);
        w.copied = hex;
        copiedClear.restart();
    }

    Timer {
        id: copiedClear

        interval: 1400
        onTriggered: w.copied = ""
    }

    Text {
        id: title

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 18
        anchors.topMargin: 15
        text: w.copied !== "" ? "COPIED " + w.copied.toUpperCase() : Prefs.currentTheme.toUpperCase().replace("-", " ")
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1.4
    }

    Grid {
        id: swatches

        visible: w.variant === "swatches"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: title.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 10
        anchors.bottomMargin: 16
        columns: 3
        rowSpacing: 8
        columnSpacing: 8

        Repeater {
            model: w.roles

            Rectangle {
                id: swatch

                required property var modelData

                readonly property string hex: Theme.toHex(swatch.modelData.color)

                width: (swatches.width - swatches.columnSpacing * 2) / 3
                height: (swatches.height - swatches.rowSpacing) / 2
                radius: Theme.radiusSm
                color: swatch.modelData.color
                scale: swatchArea.pressed ? 0.95 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durQuick
                        easing.type: Theme.easeStandard
                    }

                }

                Column {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    spacing: -1

                    Text {
                        text: swatch.modelData.name
                        color: swatch.modelData.on
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                    }

                    Text {
                        text: swatch.hex
                        color: Theme.alpha(swatch.modelData.on, 0.65)
                        font.family: "monospace"
                        font.pixelSize: 10
                        visible: w.showHex
                    }

                }

                MouseArea {
                    id: swatchArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: w.copy(swatch.hex)
                }

            }

        }

    }

    Row {
        id: ramp

        visible: w.variant === "ramp"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: title.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 10
        anchors.bottomMargin: 16
        spacing: 3

        Repeater {
            model: w.tones

            Rectangle {
                id: step

                required property var modelData
                required property int index

                readonly property color shade: Theme.atTone(Theme.accent, step.modelData)
                readonly property string hex: Theme.toHex(step.shade)

                width: (ramp.width - ramp.spacing * (w.tones.length - 1)) / w.tones.length
                height: parent.height
                topLeftRadius: step.index === 0 ? Theme.radiusSm : 3
                bottomLeftRadius: step.index === 0 ? Theme.radiusSm : 3
                topRightRadius: step.index === w.tones.length - 1 ? Theme.radiusSm : 3
                bottomRightRadius: step.index === w.tones.length - 1 ? Theme.radiusSm : 3
                color: step.shade
                scale: stepArea.pressed ? 0.94 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durQuick
                        easing.type: Theme.easeStandard
                    }

                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 7
                    text: step.modelData
                    color: step.modelData > 55 ? Theme.atTone(Theme.accent, 10) : Theme.atTone(Theme.accent, 96)
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    visible: w.showHex
                }

                MouseArea {
                    id: stepArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: w.copy(step.hex)
                }

            }

        }

    }

}
