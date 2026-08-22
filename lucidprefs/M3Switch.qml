import QtQuick
import qs

// Material 3 switch, to spec: 52x32 track, 16dp handle unselected / 24dp
// selected / 28dp while pressed, a 2dp outline that only exists in the
// unselected state, and a check glyph that appears inside the selected
// handle. The handle size change is what carries the state - the colour
// swap alone reads as ambiguous at this size.
Item {
    id: sw

    // Driven entirely by whatever `checked` is bound to - the control never
    // writes to its own state. Assigning checked here would destroy that
    // binding on the first click, after which an external change (Reset all,
    // or the same setting altered from another surface) would leave the
    // switch showing a stale position.
    property bool checked: false
    property bool enabled: true
    // disabled controls stay legible rather than vanishing - M3 puts them
    // at 38% and that is exactly enough to read as "not right now"
    readonly property real contentOpacity: sw.enabled ? 1 : 0.38

    signal toggled(bool value)

    implicitWidth: 52
    implicitHeight: 32
    opacity: sw.contentOpacity

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: Theme.easeStandard
        }

    }

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Theme.accent : Theme.bgHigh
        border.width: sw.checked ? 0 : 2
        border.color: Theme.outlineStrong

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
                easing.type: Theme.easeStandard
            }

        }

        Behavior on border.width {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

    // State layer over the track itself rather than M3's 40dp circle around
    // the thumb. That circle is taller than the 32dp track, so on a dark
    // surface it read as a pale halo bulging out of one end of the pill -
    // lopsided, and the only control in this app whose hover escapes its own
    // silhouette. Filling the track matches how M3Button and the segmented
    // control already do theirs.
    Rectangle {
        id: stateLayer

        anchors.fill: track
        radius: track.radius
        // on a filled (checked) track the feedback has to be the "on" colour
        // to register at all, the same way a filled button's does
        color: sw.checked ? Theme.onAccent : Theme.text
        opacity: !sw.enabled ? 0 : (area.pressed ? Theme.statePressed : (area.containsMouse ? Theme.stateHover : 0))

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durQuick
            }

        }

    }

    Rectangle {
        id: handle

        // 16 unselected / 24 selected / 28 pressed, per M3
        readonly property real size: area.pressed && sw.enabled ? 28 : (sw.checked ? 24 : 16)
        // travel is measured from the track's 4dp inset on either side, so
        // the 28dp pressed handle still never overhangs the track
        readonly property real restX: 4 + (24 - handle.size) / 2
        readonly property real onX: sw.width - 4 - 24 + (24 - handle.size) / 2

        width: handle.size
        height: handle.size
        radius: handle.size / 2
        x: sw.checked ? handle.onX : handle.restX
        anchors.verticalCenter: parent.verticalCenter
        color: sw.checked ? Theme.onAccent : Theme.outlineStrong

        Behavior on x {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeEmphasized
                easing.overshoot: Theme.emphasizedOvershoot
            }

        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Theme.easeStandard
            }

        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Theme.easeStandard
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

        // check glyph, drawn as two strokes so it needs no icon font
        Item {
            anchors.centerIn: parent
            width: 16
            height: 16
            opacity: sw.checked ? 1 : 0
            scale: sw.checked ? 1 : 0.4

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Theme.easeEmphasized
                    easing.overshoot: Theme.emphasizedOvershoot
                }

            }

            Rectangle {
                x: 3
                y: 8
                width: 5
                height: 2
                radius: 1
                rotation: 45
                transformOrigin: Item.Left
                color: Theme.accent
            }

            Rectangle {
                x: 5.4
                y: 10.6
                width: 8
                height: 2
                radius: 1
                rotation: -45
                transformOrigin: Item.Left
                color: Theme.accent
            }

        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        enabled: sw.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled(!sw.checked)
    }

}
