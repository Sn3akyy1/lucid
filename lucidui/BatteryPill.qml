import QtQuick
import qs

// a horizontal battery with the percentage inside it. the number is drawn twice
// and clipped at the fill edge, so it stays legible on either side of it
Item {
    id: bp

    property int percent: 0
    property bool charging: false
    property bool low: bp.percent <= 20 && !bp.charging
    property bool showText: true
    readonly property color fillColor: bp.charging ? Theme.success : (bp.low ? Theme.error : Theme.text)
    readonly property color emptyColor: Theme.alpha(Theme.text, 0.28)
    readonly property real level: Math.max(0, Math.min(1, bp.percent / 100))

    implicitWidth: bp.showText ? 30 : 22
    implicitHeight: 15

    Item {
        id: body

        width: bp.width - 3
        height: bp.height

        Rectangle {
            anchors.fill: parent
            radius: 4.5
            color: bp.emptyColor
        }

        Item {
            id: fillClip

            width: Math.round(body.width * bp.level)
            height: body.height
            clip: true

            Rectangle {
                width: body.width
                height: body.height
                radius: 4.5
                color: bp.fillColor

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }

                }

            }

            LText {
                visible: bp.showText
                width: body.width
                height: body.height
                horizontalAlignment: Text.AlignHCenter
                role: "labelSmall"
                size: Theme.fs(10.5)
                weight: 700
                text: bp.percent
                color: Theme.bgOpaque
            }

        }

        Item {
            x: fillClip.width
            width: body.width - fillClip.width
            height: body.height
            clip: true

            LText {
                visible: bp.showText
                x: -fillClip.width
                width: body.width
                height: body.height
                horizontalAlignment: Text.AlignHCenter
                role: "labelSmall"
                size: Theme.fs(10.5)
                weight: 700
                text: bp.percent
                color: Theme.text
            }

        }

    }

    Rectangle {
        anchors.left: body.right
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 6
        radius: 1
        color: bp.level >= 0.99 ? bp.fillColor : bp.emptyColor
    }

    Icon {
        visible: bp.charging && !bp.showText
        anchors.centerIn: body
        name: "bolt"
        size: 12
        fill: 1
        color: Theme.bgOpaque
    }

}
