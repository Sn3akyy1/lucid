import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: powerRow

    property var actions: [{
        "id": "lock",
        "label": "Lock",
        "iconPath": "M6 10V8a6 6 0 1 1 12 0v2h1a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V11a1 1 0 0 1 1-1h1Zm2 0h8V8a4 4 0 1 0-8 0v2Zm4 4a1.5 1.5 0 0 1 1 2.63V18a1 1 0 1 1-2 0v-1.37A1.5 1.5 0 0 1 12 14Z"
    }, {
        "id": "logout",
        "label": "Log Out",
        "iconPath": "M10 17v-2H3v-6h7V7l5 5-5 5Zm9 3H12v-2h7V6h-7V4h7a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2Z"
    }, {
        "id": "suspend",
        "label": "Suspend",
        "iconPath": "M12 3a9 9 0 1 0 8.94 10.06.5.5 0 0 0-.66-.54A7 7 0 1 1 11.48 3.72a.5.5 0 0 0-.54-.66A9.06 9.06 0 0 0 12 3Z"
    }, {
        "id": "shutdown",
        "label": "Shutdown",
        "iconPath": "M13 3h-2v10h2V3Zm4.83 2.17-1.42 1.42A6.98 6.98 0 0 1 19 12a7 7 0 1 1-11.66-5.24L5.92 5.34A9 9 0 1 0 21 12a8.97 8.97 0 0 0-3.17-6.83Z"
    }, {
        "id": "hibernate",
        "label": "Hibernate",
        "iconPath": "M9.37 5.51A7.5 7.5 0 0 0 9.1 20.94a7.5 7.5 0 0 0 9.32-5.05.5.5 0 0 0-.58-.65 6 6 0 0 1-7.4-7.4.5.5 0 0 0-.07-.33.5.5 0 0 0-.62-.22 7.53 7.53 0 0 0-.38.22Z"
    }, {
        "id": "reboot",
        "label": "Reboot",
        "iconPath": "M12 4V1L8 5l4 4V6a6 6 0 1 1-6 6H4a8 8 0 1 0 8-8Z"
    }]
    // settled height once resize finishes, see WallpaperStrip.qml
    property real stableHeight: height

    signal actionChosen(string id)

    Row {
        id: actionsRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: powerRow.stableHeight
        spacing: 12

        Repeater {
            model: powerRow.actions

            delegate: Item {
                id: card

                required property var modelData
                property bool hovered: hoverHandler.hovered
                property bool pressed: tapHandler.pressed

                width: (powerRow.width - 12 * 5) / 6
                height: parent.height
                y: card.hovered ? -4 : 0

                Rectangle {
                    id: cardBg

                    anchors.fill: parent
                    radius: 16
                    color: card.hovered ? Theme.alpha(Theme.accent, 0.14) : Theme.alpha(Theme.text, 0.04)
                    scale: card.pressed ? 0.96 : 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        Shape {
                            width: 26
                            height: 26
                            anchors.horizontalCenter: parent.horizontalCenter
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: Theme.accent
                                strokeWidth: 0

                                PathSvg {
                                    path: card.modelData.iconPath
                                }

                            }

                            transform: Scale {
                                xScale: 26 / 24
                                yScale: 26 / 24
                            }

                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: card.modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(11)
                            font.bold: true
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.ms(180)
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.ms(120)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                HoverHandler {
                    id: hoverHandler
                }

                TapHandler {
                    id: tapHandler

                    onTapped: powerRow.actionChosen(card.modelData.id)
                }

                Behavior on y {
                    NumberAnimation {
                        duration: Theme.ms(180)
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

    }

}
