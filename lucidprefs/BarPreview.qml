import QtQuick
import qs

Rectangle {
    id: preview

    radius: Theme.radiusMd
    color: Theme.bgTile
    implicitHeight: 150

    Rectangle {
        id: screen

        readonly property real unit: screen.height / 100

        // a rough width per module, so the sketch keeps the real proportions
        readonly property var pillSpan: ({
            "workspaces": 0.1,
            "media": 0.14,
            "tray": 0.06,
            "clock": 0.115,
            "notifications": 0.04,
            "system": 0.115
        })

        function cellSpan(key) {
            return screen.pillSpan[key] || 0.06;
        }

        function zoneSpan(zone) {
            const keys = Prefs.barKeysOf(zone);
            var w = 0;
            for (var i = 0; i < keys.length; i++) w += screen.cellSpan(keys[i]) * screen.width + (i > 0 ? screen.gap : 0)
            return w;
        }
        readonly property real modH: screen.unit * 11
        readonly property real barY: Prefs.barNotch ? 0 : screen.unit * 7
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

                    width: screen.width * screen.cellSpan(modelData)
                    height: screen.modH
                    color: Theme.bgOpaque
                    topLeftRadius: Prefs.barNotch ? 0 : height / 2
                    topRightRadius: Prefs.barNotch ? 0 : height / 2
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

                    width: screen.width * screen.cellSpan(modelData)
                    height: screen.modH
                    color: Theme.bgOpaque
                    topLeftRadius: Prefs.barNotch ? 0 : height / 2
                    topRightRadius: Prefs.barNotch ? 0 : height / 2
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

                    width: screen.width * screen.cellSpan(modelData)
                    height: screen.modH
                    color: Theme.bgOpaque
                    topLeftRadius: Prefs.barNotch ? 0 : height / 2
                    topRightRadius: Prefs.barNotch ? 0 : height / 2
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
                    color: Theme.bgOpaque
                    visible: Prefs.barPopupMode
                    topLeftRadius: Prefs.barNotch ? 0 : height / 2
                    topRightRadius: Prefs.barNotch ? 0 : height / 2
                    bottomLeftRadius: height / 2
                    bottomRightRadius: height / 2
                }

                Rectangle {
                    id: openPanel

                    width: parent.width
                    height: Prefs.barPopupMode ? screen.unit * 40 : screen.unit * 52
                    y: Prefs.barPopupMode ? screen.modH + Math.max(screen.unit * 1.5, Prefs.barPopupGap * screen.unit * 0.22) : 0
                    color: Theme.bgOpaque
                    radius: screen.unit * 4
                    topLeftRadius: Prefs.barPopupMode || !Prefs.barNotch ? screen.unit * 4 : 0
                    topRightRadius: Prefs.barPopupMode || !Prefs.barNotch ? screen.unit * 4 : 0

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
        text: (Prefs.barNotch ? "Notches" : "Islands") + "  ·  " + (Prefs.barPopupMode ? "pop-up" : "morph")
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabel
        font.variableAxes: Theme.axes(Theme.fontLabel, 640, 0)
        font.bold: true
    }

}
