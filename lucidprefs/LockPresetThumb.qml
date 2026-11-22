import QtQuick
import Quickshell.Widgets
import qs
import qs.lucidui

// a preset at a glance: the real wallpaper, dimmed as the lock dims it, and
// the preset's arrangement drawn over it in the shell's own colours
Item {
    id: thumb

    property string preset: "centre"
    property string name: ""
    property bool current: false
    readonly property real w: thumb.width
    readonly property real h: thumb.width / 1.6
    readonly property color card: Theme.surfaceContainer
    readonly property color hour: Theme.atTone(Theme.cPrimary, Theme.isLight ? 25 : 92)
    readonly property color minute: Theme.accent

    signal chosen()

    // ── the arrangements, in screen fractions ───────────────────────────
    // a clock as two short bars, the hour pale over the accent minute
    component Clock: Column {
        property real s: 1

        spacing: thumb.h * 0.02 * s

        Rectangle {
            width: thumb.w * 0.09 * parent.s
            height: thumb.h * 0.07 * parent.s
            radius: height / 2
            color: thumb.hour
        }

        Rectangle {
            width: thumb.w * 0.12 * parent.s
            height: thumb.h * 0.07 * parent.s
            radius: height / 2
            color: thumb.minute
        }

    }

    component Card: Rectangle {
        radius: Math.max(2, thumb.h * 0.04)
        color: thumb.card
    }

    component Pill: Rectangle {
        radius: height / 2
        color: thumb.card
    }

    implicitHeight: thumb.h + label.implicitHeight + Theme.dp(8)

    ClippingRectangle {
        id: screenBox

        width: thumb.w
        height: thumb.h
        radius: Theme.shapeLg
        color: Theme.surfaceHighest

        Image {
            anchors.fill: parent
            source: "file://" + encodeURI(Lockscreen.wallpaper)
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 320
            asynchronous: true
            cache: true
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.cScrim
            opacity: 0.45
        }

        Item {
            anchors.fill: parent
            visible: thumb.preset === "centre"

            Clock {
                x: (thumb.w - width) / 2
                y: thumb.h * 0.24
                s: 1.25
            }

            Pill {
                x: thumb.w * 0.42
                y: thumb.h * 0.8
                width: thumb.w * 0.16
                height: thumb.h * 0.06
            }

            Pill {
                x: thumb.w * 0.84
                y: thumb.h * 0.07
                width: thumb.w * 0.1
                height: thumb.h * 0.05
            }

            Pill {
                x: thumb.w * 0.05
                y: thumb.h * 0.88
                width: thumb.w * 0.14
                height: thumb.h * 0.05
            }

        }

        Item {
            anchors.fill: parent
            visible: thumb.preset === "split"

            Clock {
                x: thumb.w * 0.07
                y: thumb.h * 0.36
            }

            Card {
                x: thumb.w * 0.7
                y: thumb.h * 0.26
                width: thumb.w * 0.24
                height: thumb.h * 0.24
            }

            Card {
                x: thumb.w * 0.7
                y: thumb.h * 0.54
                width: thumb.w * 0.24
                height: thumb.h * 0.16
            }

            Pill {
                x: thumb.w * 0.8
                y: thumb.h * 0.07
                width: thumb.w * 0.14
                height: thumb.h * 0.05
            }

            Pill {
                x: thumb.w * 0.07
                y: thumb.h * 0.88
                width: thumb.w * 0.14
                height: thumb.h * 0.05
            }

        }

        Item {
            anchors.fill: parent
            visible: thumb.preset === "panel"

            Clock {
                x: thumb.w * 0.07
                y: thumb.h * 0.62
                s: 1.4
            }

            Card {
                x: thumb.w * 0.69
                y: thumb.h * 0.2
                width: thumb.w * 0.26
                height: thumb.h * 0.6

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.32
                    width: parent.width * 0.26
                    height: width
                    radius: width / 2
                    color: Theme.accentContainer
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.62
                    width: parent.width * 0.72
                    height: thumb.h * 0.05
                    radius: height / 2
                    color: Theme.surfaceHighest
                }

            }

        }

        Item {
            anchors.fill: parent
            visible: thumb.preset === "minimal"

            Row {
                x: (thumb.w - width) / 2
                y: thumb.h * 0.42
                spacing: thumb.w * 0.015

                Rectangle {
                    width: thumb.w * 0.11
                    height: thumb.h * 0.1
                    radius: height / 2
                    color: thumb.hour
                }

                Rectangle {
                    width: thumb.w * 0.14
                    height: thumb.h * 0.1
                    radius: height / 2
                    color: thumb.minute
                }

            }

            Pill {
                x: (thumb.w - width) / 2
                y: thumb.h * 0.88
                width: thumb.w * 0.18
                height: thumb.h * 0.05
            }

        }

        Item {
            anchors.fill: parent
            visible: thumb.preset === "bento"

            Card {
                x: thumb.w * 0.27
                y: thumb.h * 0.24
                width: thumb.w * 0.22
                height: thumb.h * 0.3
                color: Theme.accentContainer
            }

            Card {
                x: thumb.w * 0.27
                y: thumb.h * 0.57
                width: thumb.w * 0.22
                height: thumb.h * 0.18
            }

            Card {
                x: thumb.w * 0.51
                y: thumb.h * 0.24
                width: thumb.w * 0.22
                height: thumb.h * 0.24
            }

            Card {
                x: thumb.w * 0.51
                y: thumb.h * 0.51
                width: thumb.w * 0.22
                height: thumb.h * 0.24
            }

        }

        Item {
            anchors.fill: parent
            visible: thumb.preset === "deck"

            // the cover in its ring, the title beside it, the play cookie under
            Rectangle {
                x: thumb.w * 0.07
                y: thumb.h * 0.29
                width: thumb.h * 0.38
                height: width
                radius: width / 2
                color: "transparent"
                border.width: Math.max(1.5, thumb.h * 0.018)
                border.color: thumb.minute

                MaterialShape {
                    anchors.centerIn: parent
                    width: parent.width * 0.78
                    height: width
                    shape: "cookie9"
                    color: Theme.accentContainer
                }

            }

            Pill {
                x: thumb.w * 0.33
                y: thumb.h * 0.34
                width: thumb.w * 0.2
                height: thumb.h * 0.08
                color: thumb.hour
            }

            Pill {
                x: thumb.w * 0.33
                y: thumb.h * 0.46
                width: thumb.w * 0.12
                height: thumb.h * 0.05
            }

            MaterialShape {
                x: thumb.w * 0.33
                y: thumb.h * 0.56
                width: thumb.h * 0.12
                height: width
                shape: "cookie9"
                color: thumb.minute
            }

            Clock {
                x: thumb.w * 0.76
                y: thumb.h * 0.34
                s: 1.15
            }

            Pill {
                x: thumb.w * 0.05
                y: thumb.h * 0.88
                width: thumb.w * 0.2
                height: thumb.h * 0.05
            }

            Pill {
                x: thumb.w * 0.66
                y: thumb.h * 0.86
                width: thumb.w * 0.29
                height: thumb.h * 0.08
            }

        }

        // chosen: a check on the corner, and an accent rim inside the edge
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.dp(6)
            width: Theme.dp(20)
            height: width
            radius: width / 2
            color: Theme.accent
            scale: thumb.current ? 1 : 0
            visible: scale > 0.01

            Icon {
                anchors.centerIn: parent
                name: "check"
                size: Theme.dp(14)
                color: Theme.fgAccent
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.ms(320)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveFastSpatial
                }

            }

        }

        Rectangle {
            anchors.fill: parent
            radius: screenBox.radius
            color: "transparent"
            border.width: Theme.dp(3)
            border.color: Theme.accent
            opacity: thumb.current ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(200)
                    easing.type: Easing.OutCubic
                }

            }

        }

        Rectangle {
            anchors.fill: parent
            radius: screenBox.radius
            color: Theme.text
            opacity: tap.pressed ? Theme.statePressed : (hover.hovered ? Theme.stateHover : 0)
        }

        HoverHandler {
            id: hover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: tap

            onTapped: thumb.chosen()
        }

    }

    Text {
        id: label

        anchors.horizontalCenter: parent.horizontalCenter
        y: thumb.h + Theme.dp(8)
        text: thumb.name
        color: thumb.current ? Theme.accent : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabelLg
        font.variableAxes: Theme.axes(Theme.fontLabelLg, thumb.current ? 600 : 500, 0)
        font.weight: thumb.current ? Font.DemiBold : Font.Medium
    }

}
