import QtQuick
import QtQuick.Effects
import qs
import qs.lucidui

// a countdown in m3 expressive shapes: every second the shape morphs into the
// next one and turns on a little, with the number riding on top
Item {
    id: cd

    property int value: 3
    property color fill: Theme.primaryContainer
    property color ink: Theme.fgPrimaryContainer
    property string caption: ""
    readonly property var shapes: ["cookie9", "sunny", "clover4", "softBurst", "pentagon", "cookie6", "flower", "puffy", "gem", "cookie12"]
    property string fromShape: "circle"
    property string toShape: "circle"
    property real morph: 1
    property real spin: 0
    property real pop: 1

    signal tapped()

    function tick() {
        cd.fromShape = cd.toShape;
        cd.toShape = cd.shapes[Math.max(0, cd.value) % cd.shapes.length];
        step.restart();
    }

    implicitWidth: Theme.dp(176)
    implicitHeight: Theme.dp(176) + (cd.caption !== "" ? Theme.dp(48) : 0)
    onValueChanged: cd.tick()
    Component.onCompleted: cd.tick()

    Item {
        id: badge

        width: Theme.dp(176)
        height: Theme.dp(176)
        anchors.horizontalCenter: parent.horizontalCenter
        scale: cd.pop

        RectangularShadow {
            anchors.centerIn: parent
            width: parent.width * 0.72
            height: width
            radius: width / 2
            blur: Theme.dp(28)
            offset.y: Theme.dp(6)
            color: Theme.alpha(Theme.shadow, 0.35)
        }

        MaterialShape {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            shape: cd.fromShape
            to: cd.toShape
            morph: cd.morph
            spin: cd.spin
            color: cd.fill
        }

        LText {
            anchors.centerIn: parent
            role: "displayLarge"
            size: Theme.fs(72)
            weight: 640
            tabular: true
            color: cd.ink
            text: String(Math.max(0, cd.value))
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: cd.tapped()
        }

    }

    Rectangle {
        visible: cd.caption !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        y: badge.height + Theme.dp(14)
        width: capText.implicitWidth + Theme.dp(28)
        height: Theme.dp(34)
        radius: height / 2
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.1)

        LText {
            id: capText

            anchors.centerIn: parent
            role: "labelLarge"
            color: Theme.text
            text: cd.caption
        }

    }

    ParallelAnimation {
        id: step

        NumberAnimation {
            target: cd
            property: "morph"
            from: 0
            to: 1
            duration: Theme.durDefaultSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

        NumberAnimation {
            target: cd
            property: "spin"
            to: cd.spin + 60
            duration: Theme.durSlowSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

        SequentialAnimation {
            NumberAnimation {
                target: cd
                property: "pop"
                to: 0.86
                duration: Theme.durFastEffects
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: cd
                property: "pop"
                to: 1
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

    }

}
