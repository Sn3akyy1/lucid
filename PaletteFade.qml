import QtQuick
import qs

// drop into a window's root to crossfade it across palette swaps: captures the
// window just before Theme swaps colours, then fades that picture out over it.
// a ShaderEffectSource, because grabToImage refuses a window's content item
ShaderEffectSource {
    id: fade

    // false while the window is not on screen, so it neither captures nor holds
    property bool active: true
    property bool _capturing: false
    property bool _shown: false

    // parked just past the window's edge while capturing, so the capture never
    // contains itself; no source at rest, so no texture is held between swaps
    x: fade._shown ? 0 : (parent ? parent.width + 1 : 0)
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    z: 1e+06
    sourceItem: null
    live: false
    recursive: true
    hideSource: false
    visible: fade._capturing || fade._shown
    opacity: 1
    onScheduledUpdateCompleted: {
        if (!fade._capturing)
            return;

        if (!Theme.recolourPending) {
            fade._reset();
            return;
        }
        fade._capturing = false;
        fade._shown = true;
        Theme.releaseRecolour();
    }

    function _reset() {
        fadeOut.stop();
        if (fade._capturing)
            Theme.releaseRecolour();

        fade._capturing = false;
        fade._shown = false;
        fade.sourceItem = null;
        fade.opacity = 1;
    }

    NumberAnimation {
        id: fadeOut

        target: fade
        property: "opacity"
        from: 1
        to: 0
        duration: Theme.recolourMs
        // awww's own fade curve, so the colours move with the wallpaper
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.54, 0, 0.34, 0.99, 1, 1]
        onFinished: fade._reset()
    }

    Connections {
        function onRecolourRequested() {
            fade._reset();
            const host = fade.parent;
            if (!fade.active || !host || host.width < 1 || host.height < 1)
                return;

            Theme.holdRecolour();
            fade._capturing = true;
            fade.sourceItem = host;
            fade.scheduleUpdate();
        }

        function onRecoloured() {
            // Theme gave up waiting on this capture, so it would hold new colours
            if (fade._capturing)
                fade._reset();
            else if (fade._shown)
                fadeOut.start();
        }

        target: Theme
    }

}
