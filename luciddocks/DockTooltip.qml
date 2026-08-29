import QtQuick
import qs

Rectangle {
    id: tip

    property string label: ""
    property string detail: ""
    property bool open: false
    property real gap: 10
    property real lift: 0

    property int fadeDuration: Theme.durShort

    onOpenChanged: tip.fadeDuration = tip.open ? Theme.durShort : Theme.durQuick

    opacity: tip.open ? 1 : 0
    visible: tip.opacity > 0.01
    scale: tip.open ? 1 : 0.92
    transformOrigin: Item.Bottom

    implicitWidth: Math.max(labelText.implicitWidth, detailText.implicitWidth) + 20
    implicitHeight: content.implicitHeight + 12
    width: tip.implicitWidth
    height: tip.implicitHeight

    radius: Theme.radiusXs
    color: Theme.bgHigh
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    y: -height - tip.gap - tip.lift
    z: 60

    Column {
        id: content

        anchors.centerIn: parent
        spacing: 1

        Text {
            id: labelText

            anchors.horizontalCenter: parent.horizontalCenter
            text: tip.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.weight: Font.Medium
        }

        Text {
            id: detailText

            anchors.horizontalCenter: parent.horizontalCenter
            text: tip.detail
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            visible: tip.detail !== ""
            height: visible ? implicitHeight : 0
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: tip.fadeDuration
            easing.type: Easing.OutCubic
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: tip.fadeDuration
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    Behavior on y {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: Easing.OutCubic
        }

    }

}
