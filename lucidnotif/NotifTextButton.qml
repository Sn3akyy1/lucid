import QtQuick
import qs

// m3 text button: no container until you touch it
Item {
    id: btn

    property string label: ""
    property color labelColor: Theme.accent
    property bool enabled: true

    signal clicked()

    implicitWidth: text.implicitWidth + 20
    implicitHeight: 26
    opacity: btn.enabled ? 1 : 0.38

    Rectangle {
        anchors.fill: parent
        radius: area.pressed ? Theme.shapeSm : height / 2
        color: btn.labelColor
        opacity: !btn.enabled ? 0 : (area.pressed ? Theme.statePressed : (area.containsMouse ? Theme.stateHover : 0))

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(120)
            }

        }

    }

    Text {
        id: text

        anchors.centerIn: parent
        text: btn.label
        color: btn.labelColor
        font.family: Theme.fontFamily
        font.bold: true
        font.pixelSize: Theme.fs(11)
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
