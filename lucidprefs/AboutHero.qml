import QtQuick
import QtQuick.Shapes
import Quickshell
import qs
import qs.lucidui

// the mark inside slowly turning broken orbits, the wordmark, and where this
// copy stands against the latest release
Rectangle {
    id: hero

    // true while the page is on screen; the ambient motion runs only then
    property bool live: false
    // 0..1 through the entrance
    property real intro: 1
    readonly property bool moving: hero.live && hero.visible && Theme.motionScale > 0
    // the orbit art shrinks with the card so the words keep their room
    readonly property real s: Math.max(0.72, Math.min(1, hero.width / 820))
    // art and words centred as one group; the art's visible reach is ~120px
    readonly property real wordsW: Math.max(wordmark.implicitWidth, taglineMetrics.advanceWidth, chips.implicitWidth)
    readonly property real cx: Math.round(Math.max(130 * hero.s, (hero.width - 120 * hero.s - 196 * hero.s - hero.wordsW) / 2 + 120 * hero.s))
    readonly property real cy: hero.height / 2
    // pointer offset from the centre, -1..1; still when motion is off
    readonly property bool follow: hov.hovered && Theme.motionScale > 0
    property real px: hero.follow ? Math.max(-1, Math.min(1, (hov.point.position.x - hero.width / 2) / (hero.width / 2))) : 0
    property real py: hero.follow ? Math.max(-1, Math.min(1, (hov.point.position.y - hero.height / 2) / (hero.height / 2))) : 0
    property bool copied: false
    // radius, stroke, alpha, turn direction, ms per turn, companion radius, colour
    readonly property var orbits: [{
        "r": 74,
        "w": 2.2,
        "sweep": 292,
        "a": 0.42,
        "dir": 1,
        "period": 48000,
        "dot": 3,
        "tone": 0,
        "start": 24
    }, {
        "r": 114,
        "w": 1.6,
        "sweep": 250,
        "a": 0.26,
        "dir": -1,
        "period": 74000,
        "dot": 2.6,
        "tone": 1,
        "start": 205
    }, {
        "r": 162,
        "w": 1.2,
        "sweep": 212,
        "a": 0.16,
        "dir": 1,
        "period": 112000,
        "dot": 2.2,
        "tone": 2,
        "start": 118
    }]
    // seeded, so the sky is the same every time
    readonly property var stars: {
        let seed = 11;
        const rnd = () => {
            seed = (seed * 16807) % 2147483647;
            return (seed - 1) / 2147483646;
        };
        const out = [];
        for (let i = 0; i < 34; i++) out.push({
            "x": 0.03 + rnd() * 0.94,
            "y": 0.08 + rnd() * 0.84,
            "size": 1.4 + rnd() * 1.8,
            "lo": 0.1 + rnd() * 0.15,
            "hi": 0.35 + rnd() * 0.45,
            "period": 1400 + rnd() * 2600,
            "delay": rnd() * 3000,
            "sparkle": i % 7 === 3
        })
        return out;
    }
    readonly property string statusText: {
        if (Updates.current === "")
            return "";

        if (Updates.busy)
            return "Checking…";

        if (Updates.available)
            return "v" + Updates.latest + " is out";

        if (Updates.problem !== "")
            return "Couldn't check";

        if (Updates.checkedAt > 0 && Updates.latest === "")
            return "";

        return Updates.checkedAt > 0 ? "Up to date" : "Check for updates";
    }
    readonly property string statusIcon: Updates.busy ? "sync" : Updates.available ? "download" : (Updates.problem === "" && Updates.checkedAt > 0 ? "check_circle" : "update")

    function enter() {
        hero.intro = 0;
        entrance.restart();
        mark.play();
    }

    function burst() {
        mark.play();
        ripple.restart();
    }

    // progress through one slice of the entrance
    function phase(a, len) {
        return Math.max(0, Math.min(1, (hero.intro - a) / len));
    }

    function outCubic(p) {
        return 1 - Math.pow(1 - p, 3);
    }

    function outBack(p) {
        return 1 + 2.5 * Math.pow(p - 1, 3) + 1.5 * Math.pow(p - 1, 2);
    }

    function tone(i) {
        return i === 0 ? Theme.accent : (i === 1 ? Theme.tertiary : Theme.text);
    }

    implicitHeight: 280
    radius: Theme.radiusXl
    color: Theme.bgTile
    clip: true

    Behavior on px {
        NumberAnimation {
            duration: Theme.ms(700)
            easing.type: Easing.OutCubic
        }

    }

    Behavior on py {
        NumberAnimation {
            duration: Theme.ms(700)
            easing.type: Easing.OutCubic
        }

    }

    HoverHandler {
        id: hov
    }

    NumberAnimation {
        id: entrance

        target: hero
        property: "intro"
        from: 0
        to: 1
        duration: Theme.ms(1500)
    }

    Timer {
        id: copiedTimer

        interval: 1600
        onTriggered: hero.copied = false
    }

    // everything decorative stays clear of the corners: the clip is square
    Item {
        id: glowLayer

        anchors.fill: parent
        opacity: hero.outCubic(hero.phase(0, 0.4))

        Shape {
            id: glowA

            x: hero.cx - 170
            y: hero.cy - 170
            width: 340
            height: 340
            preferredRendererType: Shape.CurveRenderer

            SequentialAnimation {
                running: hero.moving
                loops: Animation.Infinite

                ScaleAnimator {
                    target: glowA
                    from: 0.92
                    to: 1.06
                    duration: Theme.ms(4200)
                    easing.type: Easing.InOutSine
                }

                ScaleAnimator {
                    target: glowA
                    from: 1.06
                    to: 0.92
                    duration: Theme.ms(4200)
                    easing.type: Easing.InOutSine
                }

            }

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"

                fillGradient: RadialGradient {
                    centerX: 170
                    centerY: 170
                    centerRadius: 170
                    focalX: 170
                    focalY: 170

                    GradientStop {
                        position: 0
                        color: Theme.alpha(Theme.accent, 0.24)
                    }

                    GradientStop {
                        position: 0.5
                        color: Theme.alpha(Theme.accent, 0.08)
                    }

                    GradientStop {
                        position: 1
                        color: Theme.alpha(Theme.accent, 0)
                    }

                }

                PathAngleArc {
                    centerX: 170
                    centerY: 170
                    radiusX: 170
                    radiusY: 170
                    startAngle: 0
                    sweepAngle: 360
                }

            }

        }

        Shape {
            id: glowB

            x: words.x + hero.wordsW / 2 - 190
            y: hero.cy - 190
            width: 380
            height: 380
            preferredRendererType: Shape.CurveRenderer

            SequentialAnimation {
                running: hero.moving
                loops: Animation.Infinite

                ScaleAnimator {
                    target: glowB
                    from: 1.05
                    to: 0.9
                    duration: Theme.ms(5600)
                    easing.type: Easing.InOutSine
                }

                ScaleAnimator {
                    target: glowB
                    from: 0.9
                    to: 1.05
                    duration: Theme.ms(5600)
                    easing.type: Easing.InOutSine
                }

            }

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"

                fillGradient: RadialGradient {
                    centerX: 190
                    centerY: 190
                    centerRadius: 190
                    focalX: 190
                    focalY: 190

                    GradientStop {
                        position: 0
                        color: Theme.alpha(Theme.tertiary, 0.1)
                    }

                    GradientStop {
                        position: 1
                        color: Theme.alpha(Theme.tertiary, 0)
                    }

                }

                PathAngleArc {
                    centerX: 190
                    centerY: 190
                    radiusX: 190
                    radiusY: 190
                    startAngle: 0
                    sweepAngle: 360
                }

            }

        }

        transform: Translate {
            x: hero.px * 18
            y: hero.py * 14
        }

    }

    Item {
        anchors.fill: parent

        Repeater {
            model: hero.stars

            Item {
                id: star

                required property var modelData
                required property int index

                x: Math.round(star.modelData.x * hero.width)
                y: Math.round(star.modelData.y * hero.height)
                opacity: hero.outCubic(hero.phase(0.12 + star.modelData.delay / 3000 * 0.4, 0.3))

                Rectangle {
                    id: twinkle

                    readonly property real d: star.modelData.sparkle ? 16 : star.modelData.size

                    x: -twinkle.d / 2
                    y: -twinkle.d / 2
                    width: twinkle.d
                    height: twinkle.d
                    radius: twinkle.d / 2
                    color: star.modelData.sparkle ? "transparent" : Theme.text
                    opacity: star.modelData.sparkle ? star.modelData.hi : star.modelData.lo

                    LucidaMark {
                        visible: star.modelData.sparkle
                        anchors.fill: parent
                        ringT: 0
                        dotT: 0
                        starColor: Theme.accent
                    }

                    SequentialAnimation {
                        running: hero.moving
                        loops: Animation.Infinite

                        PauseAnimation {
                            duration: Theme.ms(star.modelData.delay)
                        }

                        OpacityAnimator {
                            target: twinkle
                            from: star.modelData.lo
                            to: star.modelData.hi
                            duration: Theme.ms(star.modelData.period)
                            easing.type: Easing.InOutSine
                        }

                        OpacityAnimator {
                            target: twinkle
                            from: star.modelData.hi
                            to: star.modelData.lo
                            duration: Theme.ms(star.modelData.period)
                            easing.type: Easing.InOutSine
                        }

                    }

                }

            }

        }

        transform: Translate {
            x: hero.px * -7
            y: hero.py * -5
        }

    }

    Item {
        id: orbitLayer

        anchors.fill: parent

        Repeater {
            model: hero.orbits

            Item {
                id: orbit

                required property var modelData
                required property int index
                readonly property real k: hero.phase(0.04 + orbit.index * 0.08, 0.5)
                readonly property real half: orbit.modelData.r + 8
                // the companion rides the middle of the gap
                readonly property real gapMid: (orbit.modelData.sweep + (360 - orbit.modelData.sweep) / 2) * Math.PI / 180

                x: hero.cx - orbit.half
                y: hero.cy - orbit.half
                width: orbit.half * 2
                height: orbit.half * 2
                opacity: hero.outCubic(orbit.k)
                scale: 0.6 + 0.4 * hero.outBack(orbit.k)

                Item {
                    id: spinner

                    anchors.fill: parent
                    rotation: orbit.modelData.start

                    RotationAnimator {
                        target: spinner
                        from: orbit.modelData.start
                        to: orbit.modelData.start + 360 * orbit.modelData.dir
                        duration: Theme.ms(orbit.modelData.period)
                        loops: Animation.Infinite
                        running: hero.moving
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: Theme.alpha(hero.tone(orbit.modelData.tone), orbit.modelData.a)
                            strokeWidth: orbit.modelData.w
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathAngleArc {
                                centerX: orbit.half
                                centerY: orbit.half
                                radiusX: orbit.modelData.r
                                radiusY: orbit.modelData.r
                                startAngle: 0
                                sweepAngle: orbit.modelData.sweep
                            }

                        }

                    }

                    Rectangle {
                        readonly property real d: orbit.modelData.dot * 2

                        x: orbit.half + orbit.modelData.r * Math.cos(orbit.gapMid) - width / 2
                        y: orbit.half + orbit.modelData.r * Math.sin(orbit.gapMid) - height / 2
                        width: d
                        height: d
                        radius: d / 2
                        color: hero.tone(orbit.modelData.tone)
                        opacity: Math.min(1, orbit.modelData.a * 2.4)
                    }

                }

            }

        }

        Rectangle {
            id: rippleRing

            property real rr: 0

            x: hero.cx - rippleRing.rr
            y: hero.cy - rippleRing.rr
            width: rippleRing.rr * 2
            height: rippleRing.rr * 2
            radius: rippleRing.rr
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
            opacity: 0

            ParallelAnimation {
                id: ripple

                NumberAnimation {
                    target: rippleRing
                    property: "rr"
                    from: 40
                    to: 170
                    duration: Theme.ms(900)
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: rippleRing
                    property: "opacity"
                    from: 0.6
                    to: 0
                    duration: Theme.ms(900)
                    easing.type: Easing.OutQuad
                }

            }

        }

        Item {
            id: markBox

            x: hero.cx - 48
            y: hero.cy - 48
            width: 96
            height: 96
            scale: markArea.pressed ? 0.94 : (markArea.containsMouse ? 1.06 : 1)

            LucidaMark {
                id: mark

                anchors.fill: parent
                strokeWidth: 2.6
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durFastSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveFastSpatial
                }

            }

        }

        MouseArea {
            id: markArea

            anchors.centerIn: markBox
            width: 128
            height: 128
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hero.burst()
        }

        transform: [
            Scale {
                origin.x: hero.cx
                origin.y: hero.cy
                xScale: hero.s
                yScale: hero.s
            },
            Translate {
                x: hero.px * 9
                y: hero.py * 7
            }
        ]

    }

    TextMetrics {
        id: taglineMetrics

        font: tagline.font
        text: tagline.text
    }

    Column {
        id: words

        x: Math.round(hero.cx + 196 * hero.s)
        width: Math.min(Math.ceil(hero.wordsW), hero.width - words.x - 28)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Row {
            id: wordmark

            Repeater {
                model: ["L", "u", "c", "i", "d"]

                LText {
                    id: letter

                    required property string modelData
                    required property int index
                    readonly property real k: hero.phase(0.14 + letter.index * 0.05, 0.42)

                    role: "displayLarge"
                    weight: 680
                    text: letter.modelData
                    opacity: hero.outCubic(letter.k)

                    transform: Translate {
                        y: 22 * (1 - hero.outBack(letter.k))
                    }

                }

            }

        }

        LText {
            id: tagline

            readonly property real k: hero.phase(0.4, 0.4)

            width: parent.width
            topPadding: 2
            role: "bodyLarge"
            color: Theme.subtext
            wrapMode: Text.WordWrap
            text: "The brightest thing in your setup."
            opacity: hero.outCubic(tagline.k)

            transform: Translate {
                y: 12 * (1 - hero.outCubic(tagline.k))
            }

        }

        Item {
            width: 1
            height: 18
        }

        Row {
            id: chips

            spacing: 8

            Chip {
                id: versionChip

                readonly property real k: hero.phase(0.5, 0.4)

                kind: "assist"
                icon: hero.copied ? "check" : "deployed_code"
                text: hero.copied ? "Copied" : Updates.currentLabel
                opacity: hero.outCubic(versionChip.k)
                onClicked: {
                    Quickshell.execDetached(["wl-copy", "Lucid " + Updates.currentLabel]);
                    hero.copied = true;
                    copiedTimer.restart();
                }

                transform: Translate {
                    y: 10 * (1 - hero.outBack(versionChip.k))
                }

            }

            Chip {
                id: statusChip

                readonly property real k: hero.phase(0.57, 0.4)

                visible: hero.statusText !== ""
                kind: "assist"
                selected: Updates.available
                icon: hero.statusIcon
                text: hero.statusText
                opacity: hero.outCubic(statusChip.k)
                onClicked: {
                    if (Updates.available)
                        Updates.openLatest();
                    else
                        Updates.check();
                }

                transform: Translate {
                    y: 10 * (1 - hero.outBack(statusChip.k))
                }

            }

        }

    }

}
