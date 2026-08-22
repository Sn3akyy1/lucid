import QtQuick
import qs

// The dock at its currently chosen size, spacing and edge treatment. Icon
// size and spacing in particular are the kind of setting where a number means
// nothing until you see it.
Rectangle {
    id: preview

    radius: Theme.radiusMd
    color: Theme.bgSunken
    clip: true
    implicitHeight: 116

    Rectangle {
        anchors.fill: parent
        anchors.margins: 10
        radius: Theme.radiusXs
        color: Theme.alpha(Theme.accent, 0.10)
        clip: true

        Rectangle {
            id: bar

            // the real dock is 62 tall around a 46 icon slot, so the mock
            // keeps that same 16px of chrome as the icon size moves
            readonly property real scaleFactor: 0.5

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Prefs.dockNotch ? 0 : Math.max(2, Prefs.dockBottomMargin * bar.scaleFactor * 0.5)
            width: icons.width + 12
            height: icons.height + 8
            color: Theme.bgOpaque
            radius: 5
            bottomLeftRadius: Prefs.dockNotch ? 0 : 5
            bottomRightRadius: Prefs.dockNotch ? 0 : 5

            Behavior on anchors.bottomMargin {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Theme.easeStandard
                }

            }

            Row {
                id: icons

                anchors.centerIn: parent
                spacing: Math.max(1, Prefs.dockSpacing * bar.scaleFactor)

                Repeater {
                    model: 6

                    Item {
                        required property int index

                        width: Math.max(6, Prefs.dockIconSize * bar.scaleFactor)
                        height: Math.max(6, Prefs.dockIconSize * bar.scaleFactor)

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: width * 0.24
                            // the middle icon stands in for a hovered one, so
                            // the magnification setting has something to show
                            scale: Prefs.dockMagnify && parent.index === 2 ? 1.35 : 1
                            color: Theme.alpha(Theme.text, parent.index === 2 ? 0.5 : 0.28)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.durMedium
                                    easing.type: Theme.easeEmphasized
                                    easing.overshoot: Theme.emphasizedOvershoot
                                }

                            }

                        }

                        Rectangle {
                            width: 3
                            height: 3
                            radius: 1.5
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: -3
                            visible: Prefs.dockShowIndicators && (parent.index === 1 || parent.index === 2)
                            color: Theme.accent
                        }

                    }

                }

            }

        }

    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 10
        text: (Prefs.dockNotch ? "Notch" : "Island") + (Prefs.dockAutoHide ? " · auto-hide" : "")
        color: Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabel
    }

}
