import QtQuick
import qs

Item {
    id: sw

    property bool checked: false
    property bool enabled: true
    readonly property real contentOpacity: sw.enabled ? 1 : 0.38

    signal toggled(bool value)

    implicitWidth: 52
    implicitHeight: 32
    opacity: sw.contentOpacity

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: Theme.easeStandard
        }

    }

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Theme.accent : Theme.bgHigh
        border.width: sw.checked ? 0 : 2
        border.color: Theme.outlineStrong

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
                easing.type: Theme.easeStandard
            }

        }

        Behavior on border.width {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

    Rectangle {
        id: stateLayer

        anchors.fill: track
        radius: track.radius
        color: sw.checked ? Theme.onAccent : Theme.text
        opacity: !sw.enabled ? 0 : (area.pressed ? Theme.statePressed : (area.containsMouse ? Theme.stateHover : 0))

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durQuick
            }

        }

    }

    Rectangle {
        id: handle

        // 16 unselected / 24 selected / 28 pressed, per m3
        readonly property real size: area.pressed && sw.enabled ? 28 : (sw.checked ? 24 : 16)
        readonly property real restX: 4 + (24 - handle.size) / 2
        readonly property real onX: sw.width - 4 - 24 + (24 - handle.size) / 2

        width: handle.size
        height: handle.size
        radius: handle.size / 2
        x: sw.checked ? handle.onX : handle.restX
        anchors.verticalCenter: parent.verticalCenter
        color: sw.checked ? Theme.onAccent : Theme.outlineStrong

        Behavior on x {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeEmphasized
                easing.overshoot: Theme.emphasizedOvershoot
            }

        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Theme.easeStandard
            }

        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Theme.easeStandard
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

        Item {
            anchors.centerIn: parent
            width: 16
            height: 16
            opacity: sw.checked ? 1 : 0
            scale: sw.checked ? 1 : 0.4

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Theme.easeEmphasized
                    easing.overshoot: Theme.emphasizedOvershoot
                }

            }

            Rectangle {
                x: 3
                y: 8
                width: 5
                height: 2
                radius: 1
                rotation: 45
                transformOrigin: Item.Left
                color: Theme.accent
            }

            Rectangle {
                x: 5.4
                y: 10.6
                width: 8
                height: 2
                radius: 1
                rotation: -45
                transformOrigin: Item.Left
                color: Theme.accent
            }

        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        enabled: sw.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled(!sw.checked)
    }

}
