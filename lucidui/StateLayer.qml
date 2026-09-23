import QtQuick
import Quickshell.Widgets
import qs

// the interaction surface of anything clickable: hover and press tint, a ripple
// from the press point, and the pointer. fill the control with it
MouseArea {
    id: sl

    property real radius: 0
    property color tint: Theme.text
    property bool ripple: true
    property bool disabled: false
    property real hoverOpacity: Theme.stateHover
    property real pressOpacity: Theme.statePressed
    readonly property bool active: sl.containsMouse && !sl.disabled

    anchors.fill: parent
    hoverEnabled: true
    enabled: !sl.disabled
    cursorShape: sl.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
    onPressed: (mouse) => {
        if (!sl.ripple)
            return ;

        rip.cx = mouse.x;
        rip.cy = mouse.y;
        rip.restart();
    }

    Rectangle {
        anchors.fill: parent
        radius: sl.radius
        color: sl.tint
        opacity: sl.disabled ? 0 : (sl.pressed ? sl.pressOpacity : (sl.containsMouse ? sl.hoverOpacity : 0))

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durFastEffects
            }

        }

    }

    Loader {
        id: rip

        property real cx: 0
        property real cy: 0

        function restart() {
            rip.active = false;
            rip.active = true;
        }

        anchors.fill: parent
        active: false

        sourceComponent: ClippingRectangle {
            color: "transparent"
            radius: sl.radius

            Rectangle {
                id: wave

                readonly property real reach: Math.sqrt(sl.width * sl.width + sl.height * sl.height)

                x: rip.cx - width / 2
                y: rip.cy - height / 2
                width: wave.reach * 2 * wave.grow
                height: width
                radius: width / 2
                color: sl.tint
                opacity: 0.12 * wave.fade

                property real grow: 0.1
                property real fade: 1

                ParallelAnimation {
                    running: true
                    onFinished: rip.active = false

                    NumberAnimation {
                        target: wave
                        property: "grow"
                        to: 1
                        duration: Theme.ms(420)
                        easing.type: Easing.OutCubic
                    }

                    SequentialAnimation {
                        PauseAnimation {
                            duration: Theme.ms(160)
                        }

                        NumberAnimation {
                            target: wave
                            property: "fade"
                            to: 0
                            duration: Theme.ms(300)
                        }

                    }

                }

            }

        }

    }

}
