import QtQuick
import Quickshell
import qs
import qs.lucidui

WidgetBody {
    id: w

    readonly property bool showHex: w.opt("showHex") !== false
    // each role wears its own expressive shape
    readonly property var roles: [{
        "name": "Primary",
        "color": Theme.primary,
        "on": Theme.fgPrimary,
        "shape": "cookie9"
    }, {
        "name": "Secondary",
        "color": Theme.secondaryContainer,
        "on": Theme.fgSecondaryContainer,
        "shape": "clover4"
    }, {
        "name": "Tertiary",
        "color": Theme.tertiaryContainer,
        "on": Theme.fgTertiaryContainer,
        "shape": "sunny"
    }, {
        "name": "Container",
        "color": Theme.primaryContainer,
        "on": Theme.fgPrimaryContainer,
        "shape": "pentagon"
    }, {
        "name": "Surface",
        "color": Theme.surfaceHighest,
        "on": Theme.text,
        "shape": "square"
    }, {
        "name": "Error",
        "color": Theme.error,
        "on": Theme.fgError,
        "shape": "gem"
    }]
    readonly property var tones: [95, 90, 80, 70, 60, 50, 40, 30, 20, 10]
    // key colours walked down their tones, the way the theme builder lays them out
    readonly property var families: [{
        "name": "Primary",
        "seed": Theme.cPrimary
    }, {
        "name": "Secondary",
        "seed": Theme.cSecondary
    }, {
        "name": "Tertiary",
        "seed": Theme.cTertiary
    }, {
        "name": "Neutral",
        "seed": Theme.withSat(Theme.cSurface, 0.22)
    }]
    property string copied: ""

    function copy(c) {
        var hex = Theme.toHex(c);
        Quickshell.execDetached(["wl-copy", "--", hex]);
        w.copied = hex;
        copiedClear.restart();
    }

    Timer {
        id: copiedClear

        interval: 1600
        onTriggered: w.copied = ""
    }

    Row {
        id: head

        x: 18
        y: 14
        spacing: 8

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: w.copied !== "" ? "content_copy" : "palette"
            size: 18
            fill: 1
            color: w.inkAccent
        }

        LText {
            anchors.verticalCenter: parent.verticalCenter
            role: "titleSmall"
            color: w.ink
            text: w.copied !== "" ? "Copied " + w.copied.toUpperCase() : Prefs.currentTheme.charAt(0).toUpperCase() + Prefs.currentTheme.slice(1).replace("-", " ")
        }

    }

    // roles: six shapes, click one to copy it
    Grid {
        id: shapes

        visible: w.variant === "swatches"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 12
        anchors.topMargin: 8
        columns: 3
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: w.roles

            Item {
                id: sw

                required property var modelData
                readonly property real d: Math.min(width - 16, height - (w.showHex ? 34 : 20))

                width: (shapes.width - 4) / 3
                height: (shapes.height - 2) / 2

                MaterialShape {
                    id: blob

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: sw.d
                    height: sw.d
                    shape: sw.modelData.shape
                    color: sw.modelData.color
                    rotation: swTap.containsMouse ? 20 : 0
                    scale: swTap.pressed ? 0.9 : 1

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Theme.durDefaultSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveDefaultSpatial
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveFastSpatial
                        }

                    }

                    LText {
                        anchors.centerIn: parent
                        rotation: -blob.rotation
                        role: "labelSmall"
                        weight: 640
                        color: sw.modelData.on
                        text: "Aa"
                    }

                }

                Column {
                    anchors.top: blob.bottom
                    anchors.topMargin: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: -3

                    LText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        role: "labelSmall"
                        color: w.ink
                        text: sw.modelData.name
                    }

                    LText {
                        visible: w.showHex
                        anchors.horizontalCenter: parent.horizontalCenter
                        role: "labelSmall"
                        tabular: true
                        color: w.inkFaint
                        text: Theme.toHex(sw.modelData.color).toUpperCase()
                    }

                }

                MouseArea {
                    id: swTap

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: w.copy(sw.modelData.color)
                }

            }

        }

    }

    // ramp: the accent down its tones, as one segmented pill
    Item {
        visible: w.variant === "ramp"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        height: parent.height - head.height - 36

        Row {
            anchors.fill: parent
            spacing: 3

            Repeater {
                model: w.tones

                Rectangle {
                    id: stop

                    required property int modelData
                    required property int index
                    readonly property color c: Theme.atTone(Theme.cPrimary, stop.modelData)
                    readonly property bool hot: stopTap.containsMouse

                    width: (parent.width - 3 * (w.tones.length - 1)) / w.tones.length
                    height: parent.height
                    topLeftRadius: stop.index === 0 ? 16 : 5
                    bottomLeftRadius: stop.index === 0 ? 16 : 5
                    topRightRadius: stop.index === w.tones.length - 1 ? 16 : 5
                    bottomRightRadius: stop.index === w.tones.length - 1 ? 16 : 5
                    color: stop.c
                    scale: stop.hot ? 1.06 : 1
                    z: stop.hot ? 1 : 0

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveFastSpatial
                        }

                    }

                    LText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        role: "labelSmall"
                        tabular: true
                        color: stop.modelData > 55 ? Qt.rgba(0, 0, 0, 0.7) : Qt.rgba(1, 1, 1, 0.8)
                        text: stop.modelData
                    }

                    MouseArea {
                        id: stopTap

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: w.copy(stop.c)
                    }

                }

            }

        }

    }

    // scheme: four key colours, each a column of tones
    Row {
        id: scheme

        visible: w.variant === "scheme"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 14
        anchors.topMargin: 10
        spacing: 8

        Repeater {
            model: w.families

            Column {
                id: fam

                required property var modelData
                readonly property var steps: [90, 70, 50, 30, 10]

                width: (scheme.width - scheme.spacing * 3) / 4
                spacing: 2

                LText {
                    width: parent.width
                    role: "labelSmall"
                    color: w.inkDim
                    text: fam.modelData.name
                    elide: Text.ElideRight
                }

                Repeater {
                    model: fam.steps

                    Rectangle {
                        id: chip

                        required property int modelData
                        required property int index
                        readonly property color c: Theme.atTone(fam.modelData.seed, chip.modelData)

                        width: fam.width
                        height: (scheme.height - 18 - 8) / 5
                        topLeftRadius: chip.index === 0 ? 12 : 3
                        topRightRadius: chip.index === 0 ? 12 : 3
                        bottomLeftRadius: chip.index === 4 ? 12 : 3
                        bottomRightRadius: chip.index === 4 ? 12 : 3
                        color: chip.c

                        LText {
                            visible: w.showHex && chipTap.containsMouse
                            anchors.centerIn: parent
                            role: "labelSmall"
                            tabular: true
                            color: chip.modelData > 55 ? Qt.rgba(0, 0, 0, 0.72) : Qt.rgba(1, 1, 1, 0.85)
                            text: Theme.toHex(chip.c).toUpperCase()
                        }

                        MouseArea {
                            id: chipTap

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: w.copy(chip.c)
                        }

                    }

                }

            }

        }

    }

}
