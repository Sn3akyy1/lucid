import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// the surface the polkit dialog lives on. it takes the keyboard for as long as
// a password is being typed, so it is bound hard to there being a live request
PanelWindow {
    id: authWindow

    color: "transparent"
    visible: Polkit.open && Monitors.surfacesUp
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (Polkit.open && !Polkit.granted) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "lucidpolkit"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onVisibleChanged: {
        if (authWindow.visible)
            Qt.callLater(card.focusInput);

    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.cShadow, 0.55)
        opacity: Polkit.open ? 1 : 0

        // dismissing by clicking away is a cancel like any other
        MouseArea {
            anchors.fill: parent
            onClicked: Polkit.cancel()
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

    // escape still cancels while the field is busy and cannot hold focus
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Polkit.cancel()

        AuthCard {
            id: card

            anchors.centerIn: parent
            shown: Polkit.open

            // clicks on the card must not reach the dimmer
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                z: -1
            }

        }

    }

    BackgroundEffect.blurRegion: (Theme.blurAmount > 0 && Polkit.open) ? cardBlurRegion : null

    Region {
        id: cardBlurRegion

        x: Math.ceil(card.x - 0.002)
        y: Math.ceil(card.y - 0.002)
        width: Math.max(0, Math.floor(card.x + card.width + 0.002) - Math.ceil(card.x - 0.002))
        height: Math.max(0, Math.floor(card.y + card.height + 0.002) - Math.ceil(card.y - 0.002))
        radius: Theme.shapeXl
    }

}
