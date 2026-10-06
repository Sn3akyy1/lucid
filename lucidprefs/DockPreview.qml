import QtQuick
import qs

Rectangle {
    id: preview

    radius: Theme.radiusMd
    color: Theme.bgSunken
    clip: true
    implicitHeight: Theme.dp(116)

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.dp(10)
        radius: Theme.radiusXs
        color: Theme.alpha(Theme.accent, 0.10)
        clip: true

        Rectangle {
            id: bar

            readonly property real scaleFactor: 0.5

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Prefs.dockNotch ? 0 : Math.max(Theme.dp(2), Prefs.dockBottomMargin * bar.scaleFactor * 0.5)
            width: icons.width + Theme.dp(12)
            height: icons.height + 20 * bar.scaleFactor
            color: Theme.bgOpaque
            radius: Math.min(Prefs.dockRadius * bar.scaleFactor, bar.height / 2)
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

                        width: Math.max(Theme.dp(6), Prefs.dockIconSize * bar.scaleFactor)
                        height: Math.max(Theme.dp(6), Prefs.dockIconSize * bar.scaleFactor)

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: Math.max(1, Prefs.dockIconInset * bar.scaleFactor)
                            radius: Math.min(Math.max(1, (Prefs.dockItemRadius - Prefs.dockIconInset) * bar.scaleFactor), width / 2)
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
                            width: parent.index === 2 ? Theme.dp(9) : Theme.dp(3)
                            height: Theme.dp(3)
                            radius: 1.5
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: -Theme.dp(3)
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
        anchors.rightMargin: Theme.dp(16)
        anchors.top: parent.top
        anchors.topMargin: Theme.dp(10)
        text: (Prefs.dockNotch ? "Notch" : "Island") + (Prefs.dockAutoHide ? " · auto-hide" : "")
        color: Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabel
        font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
    }

}
