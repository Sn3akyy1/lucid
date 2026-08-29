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
                model: [0.09, 0.16]

                Rectangle {
                    required property real modelData

                    width: screen.width * modelData
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

        Rectangle {
            id: centreMod

            x: Math.round((screen.width - width) / 2)
            y: screen.barY
            width: screen.width * 0.13
            height: screen.modH
            color: Theme.bgOpaque
            topLeftRadius: Prefs.barNotch ? 0 : height / 2
            topRightRadius: Prefs.barNotch ? 0 : height / 2
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
        font.bold: true
    }

}
