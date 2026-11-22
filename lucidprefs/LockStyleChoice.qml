import QtQuick
import qs
import qs.lucidui

// a pill in the lock style editor's bar that is one of two: the lock or the login screen
Rectangle {
    id: ch

    property string icon: "lock"
    property string label: ""
    property bool on: false

    signal clicked()

    width: chRow.implicitWidth + Theme.dp(30)
    height: Theme.dp(42)
    radius: height / 2
    color: ch.on ? Theme.accent : (chArea.containsMouse ? Theme.surfaceHighest : Theme.alpha(Theme.surfaceContainer, 0.9))

    Row {
        id: chRow

        anchors.centerIn: parent
        spacing: Theme.dp(7)

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: ch.icon
            size: Theme.dp(18)
            fill: ch.on ? 1 : 0
            color: ch.on ? Theme.fgAccent : Theme.text
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ch.label
            color: ch.on ? Theme.fgAccent : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelLg
            font.variableAxes: Theme.axes(Theme.fontLabelLg, 540, 0)
            font.weight: Font.Medium
        }

    }

    MouseArea {
        id: chArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ch.clicked()
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.ms(160)
        }

    }

}
