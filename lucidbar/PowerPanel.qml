import QtQuick
import Quickshell.Services.UPower
import qs
import qs.lucidui

// the power tile's sub-view: one row per profile the daemon offers
Item {
    id: root

    property bool gameModeOn: false

    implicitHeight: col.implicitHeight

    Column {
        id: col

        width: root.width
        spacing: Theme.dp(4)

        Repeater {
            model: Power.available

            Rectangle {
                id: option

                required property int modelData
                readonly property bool selected: Power.profile === option.modelData

                width: col.width
                height: Theme.dp(50)
                radius: Theme.rad(12)
                color: option.selected ? Theme.withBlur(Theme.bgActive) : (optionArea.containsMouse ? Theme.withBlur(Theme.bgHover) : "transparent")

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.dp(9)
                    spacing: Theme.dp(10)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(30)
                        height: Theme.dp(30)
                        radius: Theme.dp(9)
                        color: Theme.alpha(Theme.accent, option.selected ? 0.22 : 0.12)

                        Icon {
                            anchors.centerIn: parent
                            name: Power.symbol(option.modelData)
                            size: Theme.dp(18)
                            fill: 1
                            color: Theme.accent
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barMs(150)
                            }

                        }

                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.dp(30) - Theme.dp(18) - Theme.dp(20)
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
                        width: Theme.dp(18)
                        height: Theme.dp(18)
                        radius: Theme.dp(9)
                        color: "transparent"
                        border.width: 2
                        border.color: option.selected ? Theme.accent : Theme.outlineStrong

                        Rectangle {
                            anchors.centerIn: parent
                            width: Theme.dp(8)
                            height: Theme.dp(8)
                            radius: Theme.dp(4)
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
            leftPadding: Theme.dp(4)
            rightPadding: Theme.dp(4)
            topPadding: Theme.dp(4)
            text: Power.degradationText(Power.degradation)
            color: Theme.warning
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
            wrapMode: Text.WordWrap
        }

        Text {
            visible: Power.holds.length > 0
            width: col.width
            leftPadding: Theme.dp(4)
            rightPadding: Theme.dp(4)
            topPadding: Theme.dp(4)
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
            leftPadding: Theme.dp(4)
            rightPadding: Theme.dp(4)
            topPadding: Theme.dp(4)
            text: "Game mode is on, and may set a profile of its own when it turns off."
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
            wrapMode: Text.WordWrap
        }

    }

}
