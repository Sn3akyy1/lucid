import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs

// one screen's worth of lock. the desktop it covers frosts over and sinks away
// on the way in, and comes back up through the frost on the way out
Item {
    id: surface

    // only the shell's own screen carries the field; the rest get the clock
    property bool primary: true
    // the desktop a moment before the lock
    property string capture: ""
    // a surface rebuilt mid-lock (a reload) must not show the desktop again
    readonly property bool fresh: Date.now() - Lockscreen.lockedAt < 1500
    readonly property bool dive: surface.capture !== "" && surface.fresh
    readonly property bool desk: deskImage.status === Image.Ready
    // the arrival driver, linear in time so each block can ease its own slice
    property real t: 0
    property real u: 0
    // 0 glance, 1 focus. the day steps back so the field can step forward
    property real focusK: Lockscreen.focused ? 1 : 0
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
    readonly property bool glanceLive: !Lockscreen.focused
    readonly property int pad: Math.round(Math.max(Theme.dp(36), Math.min(Theme.dp(76), surface.height * 0.062)))
    readonly property int rightWidth: Math.round(Math.max(Theme.dp(340), Math.min(Theme.dp(440), surface.width * 0.25)))

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
        if (surface.primary)
            auth.focusInput();

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
            if (surface.primary)
                Lockscreen.release();

        }
    }

    Connections {
        function onLeavingChanged() {
            if (Lockscreen.leaving)
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

        Image {
            anchors.fill: parent
            // encoded, or a wallpaper with a space in its name never loads
            source: "file://" + encodeURI(Lockscreen.wallpaper)
            fillMode: Image.PreserveAspectCrop
            // a dive uncovers it within a few frames
            asynchronous: !surface.dive
            cache: true
            // settles out of a push-in on the way in, and falls away on the way out
            scale: 1.07 - 0.07 * (surface.dive ? surface.sink : surface.e) + surface.focusK * 0.02 + (1 - surface.out) * 0.06
        }

    }

    MultiEffect {
        anchors.fill: parent
        source: paperBox
        visible: !surface.paperHidden
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: (surface.dive ? 1 : surface.e) * (surface.desk ? 1 : surface.out) * (0.5 + surface.focusK * 0.32)
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
        opacity: surface.shade * (0.34 + surface.focusK * 0.14)

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
        opacity: surface.shade * 0.07
    }

    // everything drawn on top leaves together
    Item {
        id: stage

        anchors.fill: parent
        opacity: surface.out
        scale: 1 + (1 - surface.out) * 0.05
        // flattened, or the cards fade through one another
        layer.enabled: surface.u > 0 && surface.out > 0

        // a click anywhere off the card puts the lock back to its resting face
        // and forgets whatever was half-typed. declared first, so every control
        // above it still gets its own clicks
        MouseArea {
            anchors.fill: parent
            onClicked: {
                auth.discard();
                Lockscreen.disengage();
            }
        }

        // ── the day, top left ──────────────────────────────────────────────
        LockWeather {
            anchors.left: parent.left
            anchors.leftMargin: surface.pad + Theme.dp(14)
            anchors.top: parent.top
            anchors.topMargin: surface.pad
            visible: surface.primary
            opacity: surface.rv(0) * (1 - surface.focusK * 0.6)
            enabled: surface.glanceLive

            transform: Translate {
                y: (1 - surface.rv(0)) * -Theme.dp(24)
            }

        }

        // ── glance chips, top right ────────────────────────────────────────
        LockStatusChips {
            id: chips

            anchors.right: parent.right
            anchors.rightMargin: surface.pad
            anchors.top: parent.top
            anchors.topMargin: surface.pad
            visible: surface.primary
            opacity: surface.rv(0.06) * (1 - surface.focusK * 0.6)
            enabled: surface.glanceLive

            transform: Translate {
                y: (1 - surface.rv(0.06)) * -Theme.dp(24)
            }

        }

        // ── the clock, left ────────────────────────────────────────────────
        LockClock {
            anchors.left: parent.left
            anchors.leftMargin: surface.pad + Theme.dp(14)
            anchors.verticalCenter: parent.verticalCenter
            unit: surface.primary ? Math.round(Math.min(Theme.dp(178), surface.height * 0.155)) : Math.round(Math.min(Theme.dp(220), surface.height * 0.19))
            visible: surface.primary
            opacity: surface.rv(0.1)

            transform: Translate {
                x: (1 - surface.rv(0.1)) * -Theme.dp(30)
                y: (1 - surface.rv(0.1)) * 22
            }

        }

        // ── the column that asks, right ────────────────────────────────────
        Item {
            id: rightCol

            anchors.right: parent.right
            anchors.rightMargin: surface.pad
            anchors.top: chips.bottom
            anchors.topMargin: Theme.dp(26)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: surface.pad + Theme.dp(64)
            width: surface.rightWidth
            visible: surface.primary

            Column {
                id: cards

                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(18)

                LockAuthCard {
                    id: auth

                    width: parent.width
                    opacity: surface.rv(0.16)
                    transformOrigin: Item.Right
                    scale: 0.96 + 0.04 * surface.rv(0.16)

                    transform: Translate {
                        x: (1 - surface.rv(0.16)) * 44
                    }

                }

                LockMedia {
                    id: player

                    width: parent.width
                    opacity: surface.rv(0.32) * (1 - surface.focusK * 0.5)
                    enabled: surface.glanceLive
                    transformOrigin: Item.Right
                    scale: 0.96 + 0.04 * surface.rv(0.32)

                    transform: Translate {
                        x: (1 - surface.rv(0.32)) * 44
                    }

                }

                LockNotifs {
                    width: parent.width
                    maxHeight: Math.max(Theme.dp(120), rightCol.height - auth.height - (player.visible ? player.height + cards.spacing : 0) - cards.spacing)
                    opacity: surface.rv(0.42) * (1 - surface.focusK * 0.5)
                    enabled: surface.glanceLive
                    transformOrigin: Item.Right
                    scale: 0.96 + 0.04 * surface.rv(0.42)

                    transform: Translate {
                        x: (1 - surface.rv(0.42)) * 44
                    }

                }

            }

        }

        // ── the ways out, bottom left ──────────────────────────────────────
        LockPower {
            anchors.left: parent.left
            anchors.leftMargin: surface.pad + Theme.dp(14)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: surface.pad
            visible: surface.primary
            opacity: surface.rv(0.5) * (1 - surface.focusK * 0.6)
            enabled: surface.glanceLive

            transform: Translate {
                y: (1 - surface.rv(0.5)) * 30
            }

        }

        // ── every other screen: the time, and nothing to type into ─────────
        Column {
            anchors.centerIn: parent
            spacing: Theme.dp(10)
            visible: !surface.primary
            opacity: surface.rv(0.08)

            transform: Translate {
                y: (1 - surface.rv(0.08)) * 24
            }

            LockClock {
                anchors.horizontalCenter: parent.horizontalCenter
                unit: Math.round(Math.min(Theme.dp(200), surface.height * 0.17))
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.dp(8)
                topPadding: Theme.dp(18)

                LockGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "lock"
                    size: Theme.dp(17)
                    color: Theme.subtextDim
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Locked"
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    font.variableAxes: Theme.axes(Theme.fontBodyMd, 420, 0)
                }

            }

        }

    }

}
