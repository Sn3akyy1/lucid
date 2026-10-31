import QtQuick
import QtQuick.Effects
import qs
import qs.lucidui

// the colours collected with shift-click, waiting to be copied one by one or
// all at once
Item {
    id: pal

    property var stage: null
    property bool tipAbove: true
    readonly property var colours: pal.stage ? pal.stage.palette : []

    implicitWidth: sheet.width
    implicitHeight: sheet.height
    visible: pal.opacity > 0.01
    opacity: pal.colours.length > 0 ? 1 : 0

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

        Behavior on width {
            NumberAnimation {
                duration: Theme.durDefaultSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        Row {
            id: row

            x: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(4)

            Repeater {
                model: pal.colours

                Item {
                    id: chip

                    required property var modelData

                    width: Theme.dp(40)
                    height: Theme.dp(40)

                    Rectangle {
                        anchors.centerIn: parent
                        width: area.containsMouse ? Theme.dp(32) : Theme.dp(28)
                        height: width
                        radius: area.containsMouse ? Theme.rad(10) : width / 2
                        color: chip.modelData.hex
                        border.width: 1
                        border.color: Theme.alpha(Theme.text, 0.25)

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveFastSpatial
                            }

                        }

                        Behavior on radius {
                            NumberAnimation {
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveDefaultSpatial
                            }

                        }

                    }

                    StateLayer {
                        id: area

                        radius: width / 2
                        tint: Theme.text
                        hoverOpacity: 0
                        onClicked: pal.stage.copyColour(chip.modelData)
                    }

                    ShotTip {
                        text: chip.modelData.value
                        hovered: area.containsMouse
                        above: pal.tipAbove
                    }

                }

            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Theme.dp(24)
                color: Theme.alpha(Theme.outline, 0.7)
            }

            ShotButton {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.dp(40)
                icon: "delete_sweep"
                tip: "Clear the palette"
                tipAbove: pal.tipAbove
                onClicked: pal.stage.palette = []
            }

        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durFastEffects
        }

    }

}
