import QtQuick
import qs

// drop into a window's root so its pointer takes a new cursor theme at once:
// Hyprland keeps drawing the image it has until the shape a window asks for
// changes, so on a poke this asks for no pointer and straight away for the
// one beneath again. both go out together, and nothing ever blinks
MouseArea {
    id: poke

    anchors.fill: parent
    z: 1e+06
    acceptedButtons: Qt.NoButton

    Connections {
        function onPoked() {
            poke.cursorShape = Qt.BlankCursor;
            poke.cursorShape = undefined;
        }

        target: Pointer
    }

}
