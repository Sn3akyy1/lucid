import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs
import "parts"

// one screen's worth of lock. the desktop it covers frosts over and sinks away
// on the way in, and comes back up through the frost on the way out. what sits
// on top is the shared Stage, laid out by the user's preset (LockStyle)
Item {
    id: surface

    // only the shell's own screen carries the field; the rest get the clock
    property bool primary: true
    // the desktop a moment before the lock
    property string capture: ""
    // settings' preview: drawn, never locked. no capture, no pam, and the face
    // it shows is the preview's to choose
    property bool preview: false
    property bool previewFocus: false
    // the preview of the login screen: its data and its sign-in
    property bool greeterLook: false
    property bool editing: false
    property string selected: ""
    property real chromeScale: 1
    // a layout other than the saved one, for a preview of a preset not yet picked
    property var layoutOverride: null
    readonly property var layout: surface.layoutOverride || LockStyle.layout
    readonly property bool focusedNow: surface.preview ? surface.previewFocus : Lockscreen.focused

    signal picked(string type)
    signal slotPicked(string slot)
    // the editor's drag and drop, passed straight through from the stage
    signal dropped(string type, string slot, int index)
    signal dragMoved(string type, point at)

    readonly property alias stage: stage
    property alias dropOutside: stage.dropOutside

    // a surface rebuilt mid-lock (a reload) must not show the desktop again
    readonly property bool fresh: !surface.preview && Date.now() - Lockscreen.lockedAt < 1500
    readonly property bool dive: surface.capture !== "" && surface.fresh
    readonly property bool desk: deskImage.status === Image.Ready
    // the arrival driver, linear in time so each block can ease its own slice
    property real t: 0
    property real u: 0
    // 0 glance, 1 focus. the day steps back so the field can step forward
    property real focusK: surface.focusedNow ? 1 : 0
    readonly property real e: surface.ease(surface.t)
    // the cards wait for the desktop to sink
    readonly property real lead: surface.dive ? 0.16 : 0
    readonly property real sinkT: surface.clamp01(surface.t / 0.6)
    readonly property real riseT: surface.clamp01((surface.u - 0.04) / 0.7)
    readonly property real sink: surface.bez([0.3, 0, 0.1, 1, 1, 1], surface.sinkT)
    // 1 while the lock is here, 0 once it has gone
    readonly property real out: 1 - surface.bez(Theme.easeEmphasizedAccel, surface.clamp01(surface.u / (surface.desk ? 0.32 : 0.55)))
    // 0 at the glass, 1 sunk away
    readonly property real depth: surface.u > 0 ? 1 - surface.bez(Theme.easeEmphasizedDecel, surface.riseT) : (surface.dive ? surface.sink : 1)
    readonly property real deskBlur: surface.u > 0 ? 1 - surface.bez(Theme.curveStandard, surface.clamp01((surface.u - 0.08) / 0.62)) : surface.bez([0.3, 0.5, 0.1, 1, 1, 1], surface.sinkT)
    // dissolves only once frosted, so the swap reads as colour, not a double exposure
    readonly property real deskOpacity: {
        if (!surface.desk)
            return 0;

        if (surface.u > 0)
            return surface.smooth(surface.clamp01((surface.u - 0.04) / 0.3));

        return surface.dive ? 1 - surface.smooth(surface.clamp01((surface.sinkT - 0.32) / 0.68)) : 0;
    }
    // not on the way in: its blur would build cold on the dive's second frame
    readonly property bool paperHidden: surface.u > 0 && surface.deskOpacity >= 1 && surface.depth <= 0 && surface.deskBlur <= 0
    readonly property real shade: (surface.dive ? surface.sink : surface.e) * (surface.desk && surface.u > 0 ? surface.depth : surface.out)
    // hyprland draws the live desktop underneath by then (session_lock_xray)
    readonly property real clear: Lockscreen.seeThrough ? (surface.desk ? surface.smooth(surface.clamp01((surface.u - 0.74) / 0.26)) : surface.smooth(surface.clamp01((surface.u - 0.4) / 0.6))) : 0
    // while the field has the screen, everything that steps back also stops
    // taking clicks. a click out there only buys the focus back
    readonly property bool glanceLive: !surface.focusedNow
    // the backdrop, as the layout asks: blur and dim 0..100, an accent wash
    readonly property real blurK: surface.layout.blur / 100
    readonly property real dimK: surface.layout.dim / 100

    // a long tail, so a block lands rather than stops
    function ease(x) {
        var c = Math.max(0, Math.min(1, x));
        return 1 - Math.pow(1 - c, 5);
    }

    function clamp01(x) {
        return Math.max(0, Math.min(1, x));
    }

    function smooth(x) {
        return x * x * (3 - 2 * x);
    }

    // bisection: the emphasized curves are too steep for newton
    function bez(c, x) {
        if (x <= 0)
            return 0;

        if (x >= 1)
            return 1;

        var lo = 0, hi = 1, s = x;
        for (var i = 0; i < 18; i++) {
            s = (lo + hi) / 2;
            var r = 1 - s;
            var bx = 3 * c[0] * s * r * r + 3 * c[2] * s * s * r + s * s * s;
            if (bx < x)
                lo = s;
            else
                hi = s;
        }
        var q = 1 - s;
        return 3 * c[1] * s * q * q + 3 * c[3] * s * s * q + s * s * s;
    }

    // a block's own progress: nothing until its turn, then a full ease of its own
    function rv(delay) {
        var d = surface.lead + delay * (1 - surface.lead);
        return surface.ease((surface.t - d) / Math.max(0.05, 1 - d));
    }

    function focusInput() {
        if (surface.primary && !surface.preview)
            stage.focusInput();

    }

    // the preview plays the arrival again when it comes back on screen
    function replay() {
        enterAnim.stop();
        surface.u = 0;
        surface.t = 0;
        enterAnim.start();
    }

    // flattened, or the layers show through one another
    opacity: 1 - surface.clear
    layer.enabled: surface.clear > 0

    Behavior on focusK {
        NumberAnimation {
            duration: Theme.ms(520)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    NumberAnimation {
        id: enterAnim

        target: surface
        property: "t"
        to: 1
        duration: surface.dive ? Theme.ms(1100) : Theme.ms(900)
    }

    // the exit is its own gesture, not the arrival run backwards
    ParallelAnimation {
        id: exitAnim

        NumberAnimation {
            target: surface
            property: "u"
            to: 1
            duration: surface.desk ? Theme.ms(680) : Theme.ms(560)
        }

        NumberAnimation {
            target: surface
            property: "t"
            to: 1
            duration: Theme.ms(300)
        }

        onFinished: {
            if (surface.primary && !surface.preview)
                Lockscreen.release();

        }
    }

    Connections {
        function onLeavingChanged() {
            if (Lockscreen.leaving && !surface.preview)
                exitAnim.restart();

        }

        target: Lockscreen
    }

    Component.onCompleted: {
        surface.t = 0;
        surface.u = 0;
        enterAnim.start();
        Qt.callLater(surface.focusInput);
    }

    // ── backdrop ───────────────────────────────────────────────────────────
    // the scale has to live on a child: MultiEffect renders its source without
    // the source item's own transform, so a scale on the Image itself is lost
    Item {
        id: paperBox

        anchors.fill: parent
        visible: !surface.paperHidden

        // settles out of a push-in on the way in, and falls away on the way out
        Item {
            anchors.fill: parent
            scale: 1.07 - 0.07 * (surface.dive ? surface.sink : surface.e) + surface.focusK * 0.02 + (1 - surface.out) * 0.06

            Image {
                anchors.fill: parent
                // encoded, or a wallpaper with a space in its name never loads
                source: "file://" + encodeURI(Lockscreen.wallpaper)
                fillMode: Image.PreserveAspectCrop
                // a dive uncovers it within a few frames
                asynchronous: !surface.dive
                cache: true
            }

            // a live wallpaper keeps moving behind the blur
            Loader {
                anchors.fill: parent
                active: !surface.preview && LiveWall.wanted && LiveWall.lockVideo !== ""
                source: Qt.resolvedUrl("LockLive.qml")
                onLoaded: item.source = Qt.binding(() => {
                    return LiveWall.lockVideo;
                })
            }

        }

    }

    MultiEffect {
        anchors.fill: parent
        source: paperBox
        visible: !surface.paperHidden
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: (surface.dive ? 1 : surface.e) * (surface.desk ? 1 : surface.out) * Math.min(1, surface.blurK + surface.focusK * 0.32)
    }

    // ── the desktop it grew out of ─────────────────────────────────────────
    Item {
        id: deskBox

        anchors.fill: parent
        visible: false

        ClippingRectangle {
            anchors.fill: parent
            color: "transparent"
            radius: surface.depth * Theme.shapeXlInc
            scale: 1 - surface.depth * 0.08

            Image {
                id: deskImage

                anchors.fill: parent
                source: surface.capture
                // it is the lock's first frame, so it cannot be late
                asynchronous: !surface.fresh
                cache: false
            }

        }

    }

    MultiEffect {
        anchors.fill: parent
        source: deskBox
        visible: surface.deskOpacity > 0
        opacity: surface.deskOpacity
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: surface.deskBlur
    }

    Rectangle {
        anchors.fill: parent
        // the layout's dim, 40 being the lock's old 0.34
        opacity: surface.shade * Math.min(1, surface.dimK * 0.85 + surface.focusK * 0.14)

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.alpha(Theme.cScrim, 0.75)
            }

            GradientStop {
                position: 0.45
                color: Theme.alpha(Theme.cScrim, 0.95)
            }

            GradientStop {
                position: 1
                color: Theme.cScrim
            }

        }

    }

    // material you's whole point: the wallpaper's own colour laid back over it
    Rectangle {
        anchors.fill: parent
        color: Theme.accent
        opacity: surface.layout.tint ? surface.shade * 0.07 : 0
    }

    // everything drawn on top leaves together
    Item {
        id: stageBox

        anchors.fill: parent
        opacity: surface.out
        scale: 1 + (1 - surface.out) * 0.05
        // flattened, or the cards fade through one another
        layer.enabled: surface.u > 0 && surface.out > 0

        // a click anywhere off the sign-in puts the lock back to its resting
        // face and forgets whatever was half-typed. declared first, so every
        // control above it still gets its own clicks
        MouseArea {
            anchors.fill: parent
            enabled: !surface.preview
            onClicked: {
                stage.discard();
                Lockscreen.disengage();
            }
        }

        Stage {
            id: stage

            anchors.fill: parent
            theme: tokens
            lock: surface.greeterLook ? loginData : Lockscreen
            layout: surface.layout
            greeter: surface.greeterLook
            preview: surface.preview
            editing: surface.editing
            selected: surface.selected
            chromeScale: surface.chromeScale
            primary: surface.primary
            t: surface.t
            lead: surface.lead
            focusK: surface.focusK
            glanceLive: surface.glanceLive
            auth: authC
            extra: ({
                "media": mediaC,
                "notifications": notifsC,
                "agenda": agendaC
            })
            onPicked: (type) => {
                return surface.picked(type);
            }
            onSlotPicked: (slot) => {
                return surface.slotPicked(slot);
            }
            onDropped: (type, slot, index) => {
                return surface.dropped(type, slot, index);
            }
            onDragMoved: (type, at) => {
                return surface.dragMoved(type, at);
            }
        }

    }

    // only where the field is, and never in the settings' preview
    OnScreenKeys {
        id: keys

        anchors.fill: parent
        theme: tokens
        lock: Lockscreen
        stage: stage
        open: Lockscreen.keysOpen && surface.primary && !surface.preview && !Lockscreen.granted
        keySize: Lockscreen.keysSize > 0 ? Lockscreen.keysSize : tokens.dp(46)
        keyLayer: Lockscreen.keysLayer
        opacity: surface.out
        onCloseRequested: Lockscreen.keysOpen = false
        onFocusWanted: surface.focusInput()
        // media, volume and brightness reach hyprland's locked binds, as from the desktop's
        onNamed: (key, shift) => {
            return Quickshell.execDetached(shift ? ["wtype", "-M", "shift", "-k", key, "-m", "shift"] : ["wtype", "-k", key]);
        }
    }

    LockTokens {
        id: tokens
    }

    // what the login screen knows, for the preview of it
    LockLoginData {
        id: loginData
    }

    Component {
        id: authC

        LockAuthCard {
            greeterLook: surface.greeterLook
            keyTokens: tokens
        }

    }

    Component {
        id: mediaC

        LockMedia {
        }

    }

    Component {
        id: notifsC

        LockNotifs {
        }

    }

    Component {
        id: agendaC

        LockAgenda {
        }

    }

}
