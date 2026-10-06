import QtQuick
import qs
import qs.lucidui

Item {
    id: check

    property string label: ""
    property bool checked: false
    property bool danger: false
    property bool enabled: true
    property string icon: ""

    readonly property color mark: check.danger ? Theme.error : Theme.accent

    signal toggled()

    implicitWidth: box.width + Theme.dp(9) + (check.icon !== "" ? appIcon.width + Theme.dp(9) : 0) + text.implicitWidth
    implicitHeight: check.icon !== "" ? Theme.dp(26) : Theme.dp(22)
    opacity: check.enabled ? 1 : 0.38

    Rectangle {
        id: box

        width: Theme.dp(18)
        height: Theme.dp(18)
        radius: Theme.dp(5)
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: check.checked ? check.mark : "transparent"
        border.width: 1.6
        border.color: check.checked ? check.mark : (area.containsMouse ? Theme.text : Theme.outlineStrong)

        Behavior on color {
            ColorAnimation {
                duration: Theme.durQuick
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.durQuick
            }

        }

        Icon {
            anchors.centerIn: parent
            name: "check"
            size: Theme.dp(16)
            opacity: check.checked ? 1 : 0
            color: check.danger ? Theme.fgError : Theme.fgAccent

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

        }

    }

    Image {
        id: appIcon

        anchors.left: box.right
        anchors.leftMargin: Theme.dp(10)
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.dp(22)
        height: Theme.dp(22)
        sourceSize: Qt.size(44, 44)
        source: check.icon
        visible: check.icon !== ""
        smooth: true
        mipmap: true
    }

    Text {
        id: text

        anchors.left: check.icon !== "" ? appIcon.right : box.right
        anchors.leftMargin: Theme.dp(9)
        anchors.verticalCenter: parent.verticalCenter
        text: check.label
        color: check.checked ? Theme.text : Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabel
        font.variableAxes: Theme.axes(Theme.fontLabel, (check.checked) ? 640 : 420, 0)
        font.bold: check.checked
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: check.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: check.toggled()
    }

}
