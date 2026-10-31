import QtQuick
import QtQuick.Effects
import qs
import qs.lucidui

// the markup's ink and size, a small sheet off the toolbar's colour button
Item {
    id: sw

    property var stage: null
    property bool shown: false

    signal done()

    implicitWidth: sheet.width
    implicitHeight: sheet.height
    visible: sw.opacity > 0.01
    opacity: sw.shown ? 1 : 0
    scale: sw.shown ? 1 : 0.92

    RectangularShadow {
        anchors.fill: sheet
        radius: sheet.radius
        blur: Theme.dp(18)
        offset.y: Theme.dp(4)
        color: Theme.alpha(Theme.shadow, Theme.isLight ? 0.18 : 0.38)
    }

    Rectangle {
        id: sheet

        width: row.implicitWidth + Theme.dp(16)
        height: Theme.dp(56)
        radius: height / 2
        color: Theme.surfaceContainer

        Row {
            id: row

            anchors.centerIn: parent
            spacing: Theme.dp(4)

            Repeater {
                model: sw.stage ? sw.stage.inks : []

                Item {
                    id: swatch

                    required property var modelData
                    required property int index
                    readonly property bool on: sw.stage && sw.stage.inkIndex === swatch.index

                    width: Theme.dp(40)
                    height: Theme.dp(40)

                    Rectangle {
                        anchors.centerIn: parent
                        width: swatch.on ? Theme.dp(34) : Theme.dp(26)
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: swatch.on ? Theme.dp(2) : 0
                        border.color: Theme.text

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveFastSpatial
                            }

                        }

                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Theme.dp(26)
                        height: width
                        radius: width / 2
                        color: swatch.modelData
                        border.width: 1
                        border.color: Theme.alpha(Theme.text, 0.25)
                    }

                    StateLayer {
                        radius: width / 2
                        tint: Theme.text
                        onClicked: {
                            sw.stage.inkIndex = swatch.index;
                            sw.done();
                        }
                    }

                }

            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Theme.dp(24)
                color: Theme.alpha(Theme.outline, 0.7)
            }

            Repeater {
                model: 3

                Item {
                    id: dotSize

                    required property int index
                    readonly property bool on: sw.stage && sw.stage.sizeIndex === dotSize.index

                    width: Theme.dp(40)
                    height: Theme.dp(40)

                    Rectangle {
                        anchors.fill: parent
                        radius: dotSize.on ? Theme.rad(12) : width / 2
                        color: dotSize.on ? Theme.secondaryContainer : "transparent"

                        Behavior on radius {
                            NumberAnimation {
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveDefaultSpatial
                            }

                        }

                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Theme.dp([6, 10, 15][dotSize.index])
                        height: width
                        radius: width / 2
                        color: dotSize.on ? Theme.fgSecondaryContainer : Theme.subtext
                    }

                    StateLayer {
                        radius: dotSize.on ? Theme.rad(12) : width / 2
                        tint: Theme.text
                        onClicked: {
                            sw.stage.sizeIndex = dotSize.index;
                            sw.done();
                        }
                    }

                }

            }

        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durFastEffects
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.durFastSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveFastSpatial
        }

    }

}
