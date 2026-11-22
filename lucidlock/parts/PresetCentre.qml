import QtQuick

// centre: the clock in the middle of the screen with whatever sits under it,
// the sign-in low in the middle, four corners for the rest. while typing the
// clock shrinks and rises, and the sign-in opens its field
Item {
    id: p

    property var stage: null
    readonly property alias authHost: auth
    readonly property real pad: p.stage.pad
    readonly property real fk: p.stage.focusK
    readonly property real cornerW: Math.round(p.width * 0.3)
    readonly property real colW: Math.round(Math.min(p.stage.dp(500), p.width * 0.4))
    // the band the middle column centres in, above the sign-in at rest
    readonly property real bandTop: p.pad + p.stage.dp(64)
    readonly property real bandBottom: auth.y - p.stage.dp(28)
    readonly property real restY: p.bandTop + Math.max(0, (p.bandBottom - p.bandTop - mid.height) / 2)
    readonly property real typingY: p.pad + p.stage.dp(36)

    function dp(px) {
        return p.stage.dp(px);
    }

    Slot {
        stage: p.stage
        slotId: "topLeft"
        align: Qt.AlignLeft
        x: p.pad + p.dp(8)
        y: p.pad
        maxWidth: p.cornerW
        delay: 0
        rise: -p.dp(24)
    }

    Slot {
        stage: p.stage
        slotId: "topRight"
        align: Qt.AlignRight
        x: p.width - p.pad - width
        y: p.pad
        maxWidth: p.cornerW
        delay: 0.06
        rise: -p.dp(24)
    }

    Column {
        id: mid

        width: p.width
        y: p.restY + (p.typingY - p.restY) * p.fk
        spacing: p.dp(30)

        Slot {
            id: hero

            stage: p.stage
            slotId: "hero"
            align: Qt.AlignHCenter
            x: (mid.width - width) / 2
            maxWidth: Math.round(p.width * 0.6)
            gap: p.dp(14)
            delay: 0.1
            dim: 0
            shrinkTo: 0.56
        }

        Slot {
            stage: p.stage
            slotId: "below"
            align: Qt.AlignHCenter
            x: (mid.width - width) / 2
            maxWidth: p.colW
            maxHeight: Math.max(p.dp(120), p.bandBottom - p.restY - hero.height - mid.spacing)
            delay: 0.3
            dim: 0.7
        }

    }

    AuthHost {
        id: auth

        stage: p.stage
        authStyle: "bare"
        collapse: 1 - p.fk
        width: Math.round(Math.min(p.dp(380), p.width * 0.32))
        x: (p.width - width) / 2
        // grows upward from where the hint sits
        y: p.height - p.pad - p.dp(18) - height
        opacity: p.stage.rv(0.2)

        transform: Translate {
            y: (1 - p.stage.rv(0.2)) * 36
        }

    }

    Slot {
        stage: p.stage
        slotId: "bottomLeft"
        align: Qt.AlignLeft
        x: p.pad + p.dp(8)
        y: p.height - p.pad - height
        maxWidth: p.cornerW
        delay: 0.5
        rise: p.dp(30)
    }

    Slot {
        stage: p.stage
        slotId: "bottomRight"
        align: Qt.AlignRight
        x: p.width - p.pad - width
        y: p.height - p.pad - height
        maxWidth: p.cornerW
        delay: 0.55
        rise: p.dp(30)
    }

}
