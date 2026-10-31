import QtQuick
import qs

// the hover and press tint for a control whose pointer is taken by a MouseArea
// of its own: a StateLayer under that area never sees the pointer to light up
Rectangle {
    id: layer

    property var area: null
    property color tint: Theme.text

    anchors.fill: parent
    radius: layer.parent && layer.parent.radius !== undefined ? layer.parent.radius : 0
    color: layer.tint
    opacity: !layer.area || !layer.area.enabled ? 0 : layer.area.pressed ? Theme.statePressed : layer.area.containsMouse ? Theme.stateHover : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durFastEffects
        }

    }

}
