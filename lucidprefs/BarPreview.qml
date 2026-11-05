import QtQuick
import QtQuick.Shapes
import qs

Rectangle {
    id: preview

    radius: Theme.radiusMd
    color: Theme.bgTile
    implicitHeight: Theme.dp(150)

    Rectangle {
        id: screen

        readonly property real unit: screen.height / 100
        readonly property bool notchedPopup: Prefs.barPopupMode && Prefs.barPopupNotched

        // a rough width per module, so the sketch keeps the real proportions
        readonly property var pillSpan: ({
            "workspaces": 0.1,
            "media": 0.14,
            "tray": 0.06,
            "clock": 0.115,
            "notifications": 0.04,
            "system": 0.115,
            "apps": 0.2
        })

        function cellSpan(key) {
            return screen.pillSpan[key] || 0.06;
        }

        // whether the module at i in a zone is joined to the one after it
        function joinedAt(zone, i) {
            const keys = Prefs.barKeysOf(zone);
            return i >= 0 && i + 1 < keys.length && Prefs.barJoinedNow(keys[i], keys[i + 1]);
        }

        function zoneSpan(zone) {
            const keys = Prefs.barKeysOf(zone);
            var w = 0;
            for (var i = 0; i < keys.length; i++) w += screen.cellSpan(keys[i]) * screen.width + (i > 0 ? screen.gap : 0)
            return w;
        }
        readonly property real modH: screen.unit * 11
        readonly property real barY: Prefs.barFlush ? 0 : screen.unit * 7
        readonly property real sideM: screen.unit * 4
        readonly property real gap: screen.unit * 3

        anchors.fill: parent
        anchors.margins: Theme.dp(14)
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

        // the full bar's strip, and the corners it hangs into the screen sides
        Rectangle {
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

                    PathLine {
                        x: r
                        y: 0
                    }

                    PathLine {
                        x: r
                        y: r
                    }

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
                model: Prefs.barKeysOf("left")

                Rectangle {
                    required property var modelData
                    required property int index
                    // joined in the arrangement: no gap, and square where they meet
                    readonly property bool joinL: screen.joinedAt("left", index - 1)
                    readonly property bool joinR: screen.joinedAt("left", index)

                    // a joined one reaches across the gap to its neighbour
                    width: screen.width * screen.cellSpan(modelData) + (joinR ? screen.gap + 1 : 0)
                    height: screen.modH
                    color: Prefs.barFull ? "transparent" : Theme.bgOpaque
                    topLeftRadius: Prefs.barFlush || joinL ? 0 : height / 2
                    topRightRadius: Prefs.barFlush || joinR ? 0 : height / 2
                    bottomLeftRadius: joinL ? 0 : height / 2
                    bottomRightRadius: joinR ? 0 : height / 2

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

            }

        }

        Row {
            id: centreRow

            x: Math.round((screen.width - screen.zoneSpan("centre")) / 2)
            y: screen.barY
            spacing: screen.gap

            Behavior on y {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Theme.easeStandard
                }

            }

            Repeater {
                model: Prefs.barKeysOf("centre")

                Rectangle {
                    required property var modelData
                    required property int index
                    // joined in the arrangement: no gap, and square where they meet
                    readonly property bool joinL: screen.joinedAt("centre", index - 1)
                    readonly property bool joinR: screen.joinedAt("centre", index)

                    // a joined one reaches across the gap to its neighbour
                    width: screen.width * screen.cellSpan(modelData) + (joinR ? screen.gap + 1 : 0)
                    height: screen.modH
                    color: Prefs.barFull ? "transparent" : Theme.bgOpaque
                    topLeftRadius: Prefs.barFlush || joinL ? 0 : height / 2
                    topRightRadius: Prefs.barFlush || joinR ? 0 : height / 2
                    bottomLeftRadius: joinL ? 0 : height / 2
                    bottomRightRadius: joinR ? 0 : height / 2

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durShort
                        }

                    }

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
                model: Prefs.barKeysOf("right")

                Rectangle {
                    required property var modelData
                    required property int index
                    // joined in the arrangement: no gap, and square where they meet
                    readonly property bool joinL: screen.joinedAt("right", index - 1)
                    readonly property bool joinR: screen.joinedAt("right", index)

                    // a joined one reaches across the gap to its neighbour
                    width: screen.width * screen.cellSpan(modelData) + (joinR ? screen.gap + 1 : 0)
                    height: screen.modH
                    color: Prefs.barFull ? "transparent" : Theme.bgOpaque
                    topLeftRadius: Prefs.barFlush || joinL ? 0 : height / 2
                    topRightRadius: Prefs.barFlush || joinR ? 0 : height / 2
                    bottomLeftRadius: joinL ? 0 : height / 2
                    bottomRightRadius: joinR ? 0 : height / 2

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
                    // a notched pop-up hangs flush from it
                    bottomLeftRadius: screen.notchedPopup ? 0 : height / 2
                    bottomRightRadius: screen.notchedPopup ? 0 : height / 2
                }

                Rectangle {
                    id: openPanel

                    width: parent.width
                    height: Prefs.barPopupMode ? screen.unit * 40 : screen.unit * 52
                    y: Prefs.barPopupMode ? screen.modH + (screen.notchedPopup ? 0 : Math.max(screen.unit * 1.5, Prefs.barPopupGap * screen.unit * 0.22)) : 0
                    color: Theme.bgOpaque
                    radius: screen.unit * 4
                    topLeftRadius: (Prefs.barPopupMode && !screen.notchedPopup) || (!Prefs.barPopupMode && !Prefs.barFlush) ? screen.unit * 4 : 0
                    topRightRadius: (Prefs.barPopupMode && !screen.notchedPopup) || (!Prefs.barPopupMode && !Prefs.barFlush) ? screen.unit * 4 : 0

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

        // only shapes in here, so the sketch of a bottom bar is the top one mirrored
        transform: Scale {
            origin.y: screen.height / 2
            yScale: Prefs.barBottom ? -1 : 1
        }

    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(22)
        // on the side away from the bar
        y: Prefs.barBottom ? Theme.dp(20) : parent.height - height - Theme.dp(20)
        text: (Prefs.barFull ? "Full bar" : Prefs.barNotch ? "Notches" : "Islands") + "  ·  " + (Prefs.barPopupMode ? (screen.notchedPopup ? "notched pop-up" : "pop-up") : "morph") + (Prefs.barAutoHide ? "  ·  auto-hide" : "")
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabel
        font.variableAxes: Theme.axes(Theme.fontLabel, 640, 0)
        font.bold: true
    }

}
