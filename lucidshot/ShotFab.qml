import QtQuick
import QtQuick.Effects
import qs
import qs.lucidui

// the shutter: an m3 fab beside the toolbar, coloured by what a press does.
// a new job turns the glyph over rather than swapping it
Item {
    id: fab

    property string icon: "photo_camera"
    property string tip: ""
    property color fill: Theme.primaryContainer
    property color ink: Theme.fgPrimaryContainer
    property bool busy: false
    property bool disabled: false
    property bool tipAbove: true
    // what the glyph shows, a beat behind icon while it turns over
    property string shown: ""
    readonly property bool jellyWobbling: squish.wobbling

    signal clicked()

    implicitWidth: Theme.dp(56)
    implicitHeight: Theme.dp(56)
    opacity: fab.disabled ? 0.5 : 1
    Component.onCompleted: fab.shown = fab.icon
    onIconChanged: {
        if (fab.shown === "" || !fab.visible) {
            fab.shown = fab.icon;
            return ;
        }
        turn.restart();
    }

    RectangularShadow {
        anchors.fill: box
        radius: box.radius
        blur: Theme.dp(14)
        offset.y: Theme.dp(3)
        color: Theme.alpha(Theme.shadow, Theme.isLight ? 0.18 : 0.38)
    }

    Rectangle {
        id: box

        anchors.fill: parent
        radius: area.pressed ? Theme.rad(12) : Theme.rad(16)
        color: fab.fill

        StateLayer {
            id: area

            radius: box.radius
            tint: fab.ink
            disabled: fab.disabled || fab.busy
            onPressedChanged: squish.kick(area.pressed ? -0.14 : 0.1)
            onClicked: fab.clicked()
        }

        Behavior on radius {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }

        }

    }

    Icon {
        id: glyph

        anchors.centerIn: parent
        visible: !fab.busy
        name: fab.shown
        size: Theme.dp(24)
        fill: 1
        color: fab.ink
    }

    LoadingIndicator {
        anchors.centerIn: parent
        width: Theme.dp(36)
        height: Theme.dp(36)
        visible: fab.busy
        running: fab.busy && fab.visible
        color: fab.ink
    }

    SequentialAnimation {
        id: turn

        ParallelAnimation {
            NumberAnimation {
                target: glyph
                property: "scale"
                to: 0.4
                duration: Theme.durFastEffects
                easing.type: Easing.InCubic
            }

            NumberAnimation {
                target: glyph
                property: "rotation"
                to: -45
                duration: Theme.durFastEffects
                easing.type: Easing.InCubic
            }

        }

        ScriptAction {
            script: {
                fab.shown = fab.icon;
                glyph.rotation = 45;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: glyph
                property: "scale"
                to: 1
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

            NumberAnimation {
                target: glyph
                property: "rotation"
                to: 0
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

    }

    ShotTip {
        text: fab.tip
        hovered: area.containsMouse && !area.pressed
        above: fab.tipAbove
    }

    transform: Jelly {
        id: squish

        target: fab
        frequency: 6
    }

}
