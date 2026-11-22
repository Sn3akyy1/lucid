import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// the lock screen's style editor, over everything on the main display, the way
// edit mode lays itself over the desktop. it frosts in, and out again before the
// draft is dropped or kept
PanelWindow {
    id: win

    // 0 gone .. 1 up
    property real k: 0
    // LucidShot's capture overlay is up (from shell.qml)
    property bool shotUp: false
    // a moment's exclusive grab, to take the keyboard back
    property bool regrab: false

    screen: Monitors.mainScreen || null
    visible: LockStyle.editorOpen || win.k > 0.001
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lucid-lockstyle"
    // the keys are the editor's while it is up: arrows step the styles, escape
    // leaves. on demand, not exclusive: hyprland gives an exclusive layer every
    // click and key on the screen, and LucidShot's overlay, its cards, a polkit
    // prompt would all be drawn over the editor and dead to the pointer
    WlrLayershell.keyboardFocus: !LockStyle.editorOpen ? WlrKeyboardFocus.None : (win.regrab ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand)
    onVisibleChanged: {
        LockStyle.editorScreen = win.screen ? win.screen.name : "";
        LockStyle.editorShown = win.visible;
    }
    // a capture over the editor done, the keys come back to it. hyprland only
    // focuses an on-demand layer as it maps or when clicked, so it takes them
    // with a brief exclusive grab and keeps them as it lets go (also after the
    // self-timer, which hands them to the window under the editor)
    onShotUpChanged: {
        if (!win.shotUp && LockStyle.editorOpen) {
            win.regrab = true;
            regrabTimer.restart();
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    NumberAnimation {
        id: opening

        target: win
        property: "k"
        to: 1
        duration: Theme.ms(560)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeEmphasizedDecel
    }

    NumberAnimation {
        id: closing

        target: win
        property: "k"
        to: 0
        duration: Theme.ms(340)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeEmphasizedAccel
        onFinished: LockStyle.endDraft()
    }

    Timer {
        id: regrabTimer

        interval: 60
        onTriggered: win.regrab = false
    }

    Connections {
        function onEditorOpenChanged() {
            if (LockStyle.editorOpen) {
                closing.stop();
                opening.start();
            } else {
                opening.stop();
                closing.start();
            }
        }

        target: LockStyle
    }

    Loader {
        anchors.fill: parent
        active: win.visible
        sourceComponent: LockStyleEditor {
            k: win.k
        }
    }

}
