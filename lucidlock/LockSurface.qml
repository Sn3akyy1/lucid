import QtQuick
import QtQuick.Effects
import qs

// one screen's worth of lock. arriving is a staggered wave read off a single
// number; leaving is the whole stage falling forward at once
Item {
    id: surface

    // only the shell's own screen carries the field; the rest get the clock
    property bool primary: true
    // the arrival driver, linear in time so each block can ease its own slice
    property real t: 0
    // 1 while the lock is here, 0 once it has gone
    property real out: 1
    // 0 glance, 1 focus. the day steps back so the field can step forward
    property real focusK: Lockscreen.focused ? 1 : 0
    readonly property real e: surface.ease(surface.t)
    readonly property int pad: Math.round(Math.max(36, Math.min(76, surface.height * 0.062)))
    readonly property int rightWidth: Math.round(Math.max(340, Math.min(440, surface.width * 0.25)))

    // a long tail, so a block lands rather than stops
    function ease(x) {
        var c = Math.max(0, Math.min(1, x));
        return 1 - Math.pow(1 - c, 5);
    }

    // a block's own progress: nothing until its turn, then a full ease of its own
    function rv(delay) {
        return surface.ease((surface.t - delay) / Math.max(0.05, 1 - delay));
    }

    function focusInput() {
        if (surface.primary)
            auth.focusInput();

    }

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
        duration: Theme.ms(900)
    }

    // the exit is one gesture, not the arrival run backwards: the stage leans
    // forward and dissolves while the wallpaper comes back into focus
    ParallelAnimation {
        id: exitAnim

        NumberAnimation {
            target: surface
            property: "out"
            to: 0
            duration: Theme.ms(300)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedAccel
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
        surface.out = 1;
        enterAnim.start();
        Qt.callLater(surface.focusInput);
    }

    // ── backdrop ───────────────────────────────────────────────────────────
    // the scale has to live on a child: MultiEffect renders its source without
    // the source item's own transform, so a scale on the Image itself is lost
    Item {
        id: paperBox

        anchors.fill: parent

        Image {
            anchors.fill: parent
            // encoded, or a wallpaper with a space in its name never loads
            source: "file://" + encodeURI(Lockscreen.wallpaper)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            // settles out of a push-in on the way in, and falls away on the way out
            scale: 1.07 - 0.07 * surface.e + surface.focusK * 0.02 + (1 - surface.out) * 0.06
        }

    }

    MultiEffect {
        anchors.fill: parent
        source: paperBox
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: surface.e * surface.out * (0.5 + surface.focusK * 0.32)
    }

    Rectangle {
        anchors.fill: parent
        opacity: surface.e * surface.out * (0.34 + surface.focusK * 0.14)

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
        opacity: surface.e * surface.out * 0.07
    }

    // everything drawn on top leaves together
    Item {
        id: stage

        anchors.fill: parent
        opacity: surface.out
        scale: 1 + (1 - surface.out) * 0.05

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
            anchors.leftMargin: surface.pad + 14
            anchors.top: parent.top
            anchors.topMargin: surface.pad
            visible: surface.primary
            opacity: surface.rv(0) * (1 - surface.focusK * 0.6)

            transform: Translate {
                y: (1 - surface.rv(0)) * -24
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

            transform: Translate {
                y: (1 - surface.rv(0.06)) * -24
            }

        }

        // ── the clock, left ────────────────────────────────────────────────
        LockClock {
            anchors.left: parent.left
            anchors.leftMargin: surface.pad + 14
            anchors.verticalCenter: parent.verticalCenter
            unit: surface.primary ? Math.round(Math.min(178, surface.height * 0.155)) : Math.round(Math.min(220, surface.height * 0.19))
            visible: surface.primary
            opacity: surface.rv(0.1)

            transform: Translate {
                x: (1 - surface.rv(0.1)) * -30
                y: (1 - surface.rv(0.1)) * 22
            }

        }

        // ── the column that asks, right ────────────────────────────────────
        Item {
            id: rightCol

            anchors.right: parent.right
            anchors.rightMargin: surface.pad
            anchors.top: chips.bottom
            anchors.topMargin: 26
            anchors.bottom: parent.bottom
            anchors.bottomMargin: surface.pad + 64
            width: surface.rightWidth
            visible: surface.primary

            Column {
                id: cards

                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18

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
                    transformOrigin: Item.Right
                    scale: 0.96 + 0.04 * surface.rv(0.32)

                    transform: Translate {
                        x: (1 - surface.rv(0.32)) * 44
                    }

                }

                LockNotifs {
                    width: parent.width
                    maxHeight: Math.max(120, rightCol.height - auth.height - (player.visible ? player.height + cards.spacing : 0) - cards.spacing)
                    opacity: surface.rv(0.42) * (1 - surface.focusK * 0.5)
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
            anchors.leftMargin: surface.pad + 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: surface.pad
            visible: surface.primary
            opacity: surface.rv(0.5) * (1 - surface.focusK * 0.6)

            transform: Translate {
                y: (1 - surface.rv(0.5)) * 30
            }

        }

        // ── every other screen: the time, and nothing to type into ─────────
        Column {
            anchors.centerIn: parent
            spacing: 10
            visible: !surface.primary
            opacity: surface.rv(0.08)

            transform: Translate {
                y: (1 - surface.rv(0.08)) * 24
            }

            LockClock {
                anchors.horizontalCenter: parent.horizontalCenter
                unit: Math.round(Math.min(200, surface.height * 0.17))
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                topPadding: 18

                LockGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "lock"
                    size: 17
                    color: Theme.subtextDim
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Locked"
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                }

            }

        }

    }

}
