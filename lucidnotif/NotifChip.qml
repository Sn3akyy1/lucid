import QtQuick
import qs

// m3 chip anatomy on the accent fill this panel has always used
Rectangle {
    id: chip

    property string label: ""
    property string iconPath: ""

    signal clicked()

    implicitWidth: row.implicitWidth + (chip.iconPath !== "" ? 20 : 24)
    implicitHeight: 26
    radius: area.pressed ? Theme.shapeSm : height / 2
    color: area.pressed ? Theme.accentPressed : (area.containsMouse ? Theme.accentHover : Theme.accent)

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 4

        NotifIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: chip.iconPath !== ""
            size: 14
            path: chip.iconPath
            color: Theme.fgAccent
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.label
            color: Theme.fgAccent
            font.family: Theme.fontFamily
            font.bold: true
            font.pixelSize: Theme.fs(10)
        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }

    Behavior on color {
        ColorAnimation {
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
