import QtQuick
import QtQuick.Shapes
import qs

Rectangle {
    id: preview

    radius: Theme.radiusMd
    color: Theme.bgTile
    implicitHeight: 150

    Rectangle {
        id: screen

        readonly property real unit: screen.height / 100
        readonly property real modH: screen.unit * 11
        readonly property real barY: Prefs.barFlush ? 0 : screen.unit * 7
        readonly property real sideM: screen.unit * 4
        readonly property real gap: screen.unit * 3

        anchors.fill: parent
        anchors.margins: 14
        radius: Theme.radiusXs
        color: Theme.bgSunken
        clip: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.accent, 0.16)
                }

                GradientStop {
                    position: 1
                    color: Theme.alpha(Theme.accent, 0.03)
                }

            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

        Rectangle {
            id: fullStrip

            width: screen.width
            height: screen.modH
            color: Theme.bgOpaque
            visible: Prefs.barFull
        }

        Repeater {
            model: Prefs.barFull ? [false, true] : []

            Shape {
                required property bool modelData
                readonly property real r: Math.max(0, Prefs.barFullCorner * 0.5)

                x: modelData ? screen.width - r : 0
                y: screen.modH
                width: r
                height: r
                visible: r > 0
                preferredRendererType: Shape.CurveRenderer

                transform: Scale {
                    xScale: modelData ? 1 : -1
                    origin.x: r / 2
                }

                ShapePath {
                    strokeWidth: 0
                    fillColor: Theme.bgOpaque
                    startX: r
                    startY: r

                    PathArc {
                        x: 0
                        y: 0
                        radiusX: r
                        radiusY: r
                        direction: PathArc.Counterclockwise
                    }

                    PathLine { x: r; y: 0 }
                    PathLine { x: r; y: r }
                }

            }

        }

        Row {
            id: leftRow

            x: screen.sideM
            y: screen.barY
            spacing: screen.gap

            Behavior on y {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Theme.easeStandard
                }

            }

            Repeater {
                model: [0.09, 0.16]

                Rectangle {
                    required property real modelData

                    width: screen.width * modelData
                    height: screen.modH
                    color: Prefs.barFull ? "transparent" : Theme.bgOpaque
                    topLeftRadius: Prefs.barFlush ? 0 : height / 2
                    topRightRadius: Prefs.barFlush ? 0 : height / 2
                    bottomLeftRadius: height / 2
                    bottomRightRadius: height / 2

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

            }

        }

        Rectangle {
            id: centreMod

            x: Math.round((screen.width - width) / 2)
            y: screen.barY
            width: screen.width * 0.13
            height: screen.modH
            color: Prefs.barFull ? "transparent" : Theme.bgOpaque
            topLeftRadius: Prefs.barFlush ? 0 : height / 2
            topRightRadius: Prefs.barFlush ? 0 : height / 2
            bottomLeftRadius: height / 2
            bottomRightRadius: height / 2

            Behavior on y {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Theme.easeStandard
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

        }

        Row {
            id: rightRow

            x: screen.width - width - screen.sideM
            y: screen.barY
            spacing: screen.gap

            Behavior on y {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Theme.easeStandard
                }

            }

            Repeater {
                model: [0.07, 0.07, 0.05]

                Rectangle {
                    required property real modelData

                    width: screen.width * modelData
                    height: screen.modH
                    color: Prefs.barFull ? "transparent" : Theme.bgOpaque
                    topLeftRadius: Prefs.barFlush ? 0 : height / 2
                    topRightRadius: Prefs.barFlush ? 0 : height / 2
                    bottomLeftRadius: height / 2
                    bottomRightRadius: height / 2

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

            }

            Item {
                width: screen.width * 0.13
                height: screen.modH

                Rectangle {
                    id: openPill

                    width: parent.width
                    height: screen.modH
                    color: Prefs.barFull ? "transparent" : Theme.bgOpaque
                    visible: Prefs.barPopupMode
                    topLeftRadius: Prefs.barFlush ? 0 : height / 2
                    topRightRadius: Prefs.barFlush ? 0 : height / 2
                    bottomLeftRadius: height / 2
                    bottomRightRadius: height / 2
                }

                Rectangle {
                    id: openPanel

                    width: parent.width
                    height: Prefs.barPopupMode ? screen.unit * 40 : screen.unit * 52
                    y: Prefs.barPopupMode ? screen.modH + Math.max(screen.unit * 1.5, Prefs.barPopupGap * screen.unit * 0.22) : 0
                    color: Theme.bgOpaque
                    radius: screen.unit * 4 * Theme.radiusScale
                    topLeftRadius: Prefs.barPopupMode || !Prefs.barFlush ? screen.unit * 4 * Theme.radiusScale : 0
                    topRightRadius: Prefs.barPopupMode || !Prefs.barFlush ? screen.unit * 4 * Theme.radiusScale : 0

                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.durMedium
                            easing.type: Theme.easeStandard
                        }

                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.durMedium
                            easing.type: Theme.easeStandard
                        }

                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: screen.unit * 4

                        Repeater {
                            model: 3

                            Rectangle {
                                width: openPanel.width * 0.62
                                height: screen.unit * 3
                                radius: height / 2
                                color: Theme.alpha(Theme.text, 0.3)
                            }

                        }

                    }

                }

            }

        }

    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        text: (Prefs.barFull ? "Full bar" : Prefs.barNotch ? "Notches" : "Islands") + "  ·  " + (Prefs.barPopupMode ? "pop-up" : "morph") + (Prefs.barAutoHide ? "  ·  auto-hide" : "")
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabel
        font.bold: true
    }

}
