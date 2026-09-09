import "../lucidwidgets"
import QtQuick
import Quickshell
import qs

Item {
    id: map

    readonly property var screenSize: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property real screenW: map.screenSize ? map.screenSize.width : 1920
    readonly property real screenH: map.screenSize ? map.screenSize.height : 1080
    readonly property real fit: Math.min(frame.width / map.screenW, frame.height / map.screenH)

    implicitHeight: 230

    Text {
        id: caption

        anchors.left: parent.left
        anchors.top: parent.top
        leftPadding: 22
        text: "Your desktop"
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontTitleSm
        font.weight: Font.DemiBold
        font.letterSpacing: 0.1
        bottomPadding: 12
    }

    Rectangle {
        id: frame

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: caption.bottom
        anchors.bottom: parent.bottom
        radius: Theme.radiusXl
        color: Theme.withBlur(Theme.bgTile)
        clip: true

        Item {
            id: canvas

            width: map.screenW * map.fit
            height: map.screenH * map.fit
            anchors.centerIn: parent

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSm
                color: Theme.bgSunken
            }

            // the bar, so the placement reads against something familiar
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Prefs.effectiveBarTopMargin * map.fit
                width: parent.width * 0.6
                height: Math.max(3, Prefs.barHeight * map.fit)
                radius: height / 2
                color: Theme.alpha(Theme.text, 0.12)
                visible: Prefs.barEnabled
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Prefs.effectiveDockBottomMargin * map.fit
                width: parent.width * 0.3
                height: Math.max(3, Prefs.dockIconSize * map.fit)
                radius: height / 2
                color: Theme.alpha(Theme.text, 0.12)
                visible: Prefs.dockEnabled
            }

            Repeater {
                model: Widgets.model

                Rectangle {
                    id: pip

                    required property string uid
                    required property string wtype
                    required property real wx
                    required property real wy
                    required property real bw
                    required property real bh
                    required property real zoom
                    required property bool pinned
                    required property bool closing
                    readonly property bool lit: pipArea.containsMouse

                    x: pip.wx * map.fit
                    y: pip.wy * map.fit
                    width: pip.bw * pip.zoom * map.fit
                    height: pip.bh * pip.zoom * map.fit
                    radius: Math.max(2, Theme.radiusMd * map.fit)
                    color: pip.lit ? Theme.accent : Theme.alpha(Theme.accent, 0.32)
                    opacity: pip.closing ? 0 : 1

                    WidgetGlyph {
                        anchors.centerIn: parent
                        name: pip.wtype
                        size: Math.min(16, Math.min(parent.width, parent.height) * 0.55)
                        color: pip.lit ? Theme.fgAccent : Theme.alpha(Theme.fgAccent, 0.75)
                    }

                    MouseArea {
                        id: pipArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Widgets.togglePinned(pip.uid)
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durQuick
                        }

                    }

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.durMedium
                            easing.type: Theme.easeStandard
                        }

                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.durMedium
                            easing.type: Theme.easeStandard
                        }

                    }

                }

            }

        }

        Column {
            anchors.centerIn: parent
            spacing: 3
            visible: Widgets.count === 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nothing placed yet"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Pick one below and it lands on the desktop."
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
            }

        }

    }

}
