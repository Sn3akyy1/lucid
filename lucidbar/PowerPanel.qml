import QtQuick
import QtQuick.Shapes
import Quickshell.Services.UPower
import qs

// the power tile's sub-view: one row per profile the daemon offers
Item {
    id: root

    property bool gameModeOn: false

    implicitHeight: col.implicitHeight

    Column {
        id: col

        width: root.width
        spacing: 4

        Repeater {
            model: Power.available

            Rectangle {
                id: option

                required property int modelData
                readonly property bool selected: Power.profile === option.modelData

                width: col.width
                height: 50
                radius: 12
                color: option.selected ? Theme.withBlur(Theme.bgActive) : (optionArea.containsMouse ? Theme.withBlur(Theme.bgHover) : "transparent")

                Row {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 10

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        radius: 9
                        color: Theme.alpha(Theme.accent, option.selected ? 0.22 : 0.12)

                        Shape {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            scale: 16 / 24
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeWidth: 0
                                fillColor: Theme.accent

                                PathSvg {
                                    path: Power.icon(option.modelData)
                                }

                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barMs(150)
                            }

                        }

                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 30 - 18 - 20
                        spacing: 1

                        Text {
                            width: parent.width
                            text: Power.name(option.modelData)
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(12)
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: Power.description(option.modelData)
                            color: option.selected ? Theme.accent : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(10)
                            elide: Text.ElideRight
                        }

                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        radius: 9
                        color: "transparent"
                        border.width: 2
                        border.color: option.selected ? Theme.accent : Theme.outlineStrong

                        Rectangle {
                            anchors.centerIn: parent
                            width: 8
                            height: 8
                            radius: 4
                            color: Theme.accent
                            scale: option.selected ? 1 : 0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.barMs(180)
                                    easing.type: Easing.OutBack
                                }

                            }

                        }

                    }

                }

                MouseArea {
                    id: optionArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Power.set(option.modelData)
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.barMs(150)
                    }

                }

            }

        }

        Text {
            visible: Power.degradation !== ""
            width: col.width
            leftPadding: 4
            rightPadding: 4
            topPadding: 4
            text: Power.degradationText(Power.degradation)
            color: Theme.warning
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
            wrapMode: Text.WordWrap
        }

        Text {
            visible: Power.holds.length > 0
            width: col.width
            leftPadding: 4
            rightPadding: 4
            topPadding: 4
            text: {
                const h = Power.holds[0];
                if (!h)
                    return "";

                const extra = Power.holds.length > 1 ? " (and " + (Power.holds.length - 1) + " more)" : "";
                return (h.applicationId || "An application") + " is holding " + Power.name(h.profile) + (h.reason ? " - " + h.reason : "") + extra + ".";
            }
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
            wrapMode: Text.WordWrap
        }

        Text {
            visible: root.gameModeOn
            width: col.width
            leftPadding: 4
            rightPadding: 4
            topPadding: 4
            text: "Game mode is on, and may set a profile of its own when it turns off."
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
            wrapMode: Text.WordWrap
        }

    }

}
