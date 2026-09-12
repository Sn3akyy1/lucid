import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: check

    property string label: ""
    property bool checked: false
    property bool danger: false
    property bool enabled: true
    property string icon: ""

    readonly property color mark: check.danger ? Theme.error : Theme.accent

    signal toggled()

    implicitWidth: box.width + 9 + (check.icon !== "" ? appIcon.width + 9 : 0) + text.implicitWidth
    implicitHeight: check.icon !== "" ? 26 : 22
    opacity: check.enabled ? 1 : 0.38

    Rectangle {
        id: box

        width: 18
        height: 18
        radius: 5
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

        Shape {
            anchors.centerIn: parent
            width: 14
            height: 14
            opacity: check.checked ? 1 : 0
            preferredRendererType: Shape.CurveRenderer

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

            ShapePath {
                strokeWidth: 0
                fillColor: check.danger ? Theme.fgError : Theme.fgAccent

                PathSvg {
                    path: "M9,20.42L2.79,14.21L5.62,11.38L9,14.77L18.88,4.88L21.71,7.71L9,20.42Z"
                }

            }

            transform: Scale {
                xScale: 14 / 24
                yScale: 14 / 24
            }

        }

    }

    Image {
        id: appIcon

        anchors.left: box.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        sourceSize: Qt.size(44, 44)
        source: check.icon
        visible: check.icon !== ""
        smooth: true
        mipmap: true
    }

    Text {
        id: text

        anchors.left: check.icon !== "" ? appIcon.right : box.right
        anchors.leftMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        text: check.label
        color: check.checked ? Theme.text : Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabel
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
