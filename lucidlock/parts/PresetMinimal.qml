import QtQuick

// minimal: the time and nothing else at rest. typing lifts the clock and
// brings the sign-in up under it; a row along the bottom keeps the rest
Item {
    id: p

    property var stage: null
    readonly property alias authHost: auth
    readonly property real pad: p.stage.pad
    readonly property real fk: p.stage.focusK
    readonly property real restY: (p.height - hero.height) / 2 - p.dp(20)
    readonly property real typingY: Math.round(p.height * 0.13)

    function dp(px) {
        return p.stage.dp(px);
    }

    Slot {
        id: hero

        stage: p.stage
        slotId: "hero"
        align: Qt.AlignHCenter
        x: (p.width - width) / 2
        y: p.restY + (p.typingY - p.restY) * p.fk
        maxWidth: Math.round(p.width * 0.7)
        gap: p.dp(12)
        delay: 0.08
        dim: 0
        shrinkTo: 0.66
    }

    AuthHost {
        id: auth

        stage: p.stage
        authStyle: "bare"
        // at rest only the hint shows, low on the screen; typing opens it
        collapse: 1 - p.fk
        quiet: true
        width: Math.round(Math.min(p.dp(380), p.width * 0.32))
        x: (p.width - width) / 2
        y: p.height - p.pad - foot.height - p.dp(48) - height
        opacity: p.stage.rv(0.3) * (0.7 + 0.3 * p.fk)

        transform: Translate {
            y: (1 - p.stage.rv(0.3)) * 30
        }

    }

    Slot {
        id: foot

        stage: p.stage
        slotId: "foot"
        row: true
        align: Qt.AlignHCenter
        x: (p.width - width) / 2
        y: p.height - p.pad - height
        maxWidth: Math.round(p.width * 0.6)
        gap: p.dp(20)
        delay: 0.45
        rise: p.dp(26)
    }

}
