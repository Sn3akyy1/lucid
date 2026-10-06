import QtQuick
import qs

// m3 chip anatomy on the accent fill this panel has always used
Rectangle {
    id: chip

    property string label: ""
    property string iconPath: ""

    signal clicked()

    implicitWidth: row.implicitWidth + (chip.iconPath !== "" ? Theme.dp(20) : Theme.dp(24))
    implicitHeight: Theme.dp(26)
    radius: area.pressed ? Theme.shapeSm : height / 2
    color: Theme.layer(Theme.secondaryContainer, Theme.fgSecondaryContainer, area.pressed ? Theme.statePressed : (area.containsMouse ? Theme.stateHover : 0))

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.dp(4)

        NotifIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: chip.iconPath !== ""
            size: Theme.dp(14)
            path: chip.iconPath
            color: Theme.fgSecondaryContainer
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.label
            color: Theme.fgSecondaryContainer
            font.family: Theme.fontFamily
            font.bold: true
            font.pixelSize: Theme.fs(10)
            font.variableAxes: Theme.axes(Theme.fs(10), 640, 0)
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
