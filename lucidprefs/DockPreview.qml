import QtQuick
import qs

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

            readonly property real scaleFactor: 0.5

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Prefs.dockNotch ? 0 : Math.max(2, Prefs.dockBottomMargin * bar.scaleFactor * 0.5)
            width: icons.width + 12
            height: icons.height + 20 * bar.scaleFactor
            color: Theme.bgOpaque
            radius: Math.min(Theme.radiusXl * bar.scaleFactor, bar.height / 2)
            bottomLeftRadius: Prefs.dockNotch ? 0 : bar.radius
            bottomRightRadius: Prefs.dockNotch ? 0 : bar.radius

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
                            width: parent.index === 2 ? 9 : 3
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
