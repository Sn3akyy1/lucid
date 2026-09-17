import QtQuick
import qs

// m3 standard icon button: flat, round, state layer only
Item {
    id: btn

    property string iconPath: ""
    property int size: 26
    property int iconSize: 17
    property bool active: false
    property color tint: Theme.subtext
    property color activeTint: Theme.accent
    property bool enabled: true

    signal clicked()

    implicitWidth: btn.size
    implicitHeight: btn.size
    opacity: btn.enabled ? 1 : 0.38

    Rectangle {
        anchors.fill: parent
        radius: area.pressed ? Theme.shapeSm : width / 2
        color: btn.active ? btn.activeTint : Theme.text
        opacity: {
            if (!btn.enabled)
                return 0;

            if (btn.active)
                return 1;

            return area.pressed ? Theme.statePressed : (area.containsMouse ? Theme.stateHover : 0);
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(120)
            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: Theme.ms(220)
                easing.type: Theme.easeEmphasized
                easing.overshoot: Theme.emphasizedOvershoot
            }

        }

    }

    NotifIcon {
        anchors.centerIn: parent
        size: btn.iconSize
        path: btn.iconPath
        color: btn.active ? Theme.fgAccent : (area.containsMouse ? Theme.text : btn.tint)

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(140)
            }

        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.ms(150)
        }

    }

}
