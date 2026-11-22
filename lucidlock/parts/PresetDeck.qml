import QtQuick

// deck: whatever is playing, up big on the left, the time on the right, the
// day's marks along the bottom and the sign-in as one line in its corner.
// with nothing in the deck (nothing playing, and always on the login screen,
// which has no player) the time glides to the middle and keeps it
Item {
    id: p

    property var stage: null
    readonly property alias authHost: auth
    readonly property real pad: p.stage.pad
    readonly property real fk: p.stage.focusK
    // the band between the top and the bottom row, that the deck and the time centre in
    readonly property real bandTop: p.pad + p.dp(24)
    readonly property real bandBottom: Math.min(foot.y, corner.y, auth.y) - p.dp(24)
    readonly property real heroRightX: p.width - p.pad - p.dp(40) - hero.width
    readonly property real heroMidX: (p.width - hero.width) / 2
    // 1 while the deck is empty
    property real soloK: deck.empty ? 1 : 0
    // the bottom row's line: the middle of the sign-in's face and field. what
    // the sign-in grows under it (a verdict, the login screen's session) hangs
    // below, and the row rises with it
    readonly property real lineY: auth.y + p.dp(28)

    function dp(px) {
        return p.stage.dp(px);
    }

    function midY(h) {
        return Math.round(p.bandTop + Math.max(0, (p.bandBottom - p.bandTop - h) / 2));
    }

    Behavior on soloK {
        enabled: p.stage.flipOk

        NumberAnimation {
            duration: p.stage.theme.ms(620)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: p.stage.theme.curveDefaultSpatial
        }

    }

    Slot {
        id: deck

        stage: p.stage
        slotId: "deck"
        align: Qt.AlignLeft
        x: p.pad + p.dp(40)
        y: p.midY(height)
        maxWidth: Math.round(p.width * 0.56)
        maxHeight: p.bandBottom - p.bandTop
        delay: 0.12
        dim: 0.35
        rise: 0
        riseX: -p.dp(48)
    }

    Slot {
        id: hero

        stage: p.stage
        slotId: "hero"
        align: Qt.AlignHCenter
        x: Math.round(p.heroRightX + (p.heroMidX - p.heroRightX) * p.soloK)
        y: p.midY(height)
        maxWidth: Math.round(p.width * (0.34 + 0.2 * p.soloK))
        gap: p.dp(12)
        delay: 0.04
        dim: 0
        shrinkTo: 0.78
        rise: p.dp(22)
    }

    Slot {
        id: foot

        stage: p.stage
        slotId: "foot"
        row: true
        align: Qt.AlignLeft
        x: p.pad + p.dp(14)
        y: Math.round(Math.min(p.height - p.pad - height, p.lineY - height / 2))
        maxWidth: Math.max(p.dp(200), auth.x - p.pad - p.dp(14) - corner.width - p.dp(48))
        gap: p.dp(26)
        delay: 0.4
        rise: p.dp(26)
    }

    // the sign-in's corner: the power buttons, then the face and the field
    Slot {
        id: corner

        stage: p.stage
        slotId: "corner"
        row: true
        align: Qt.AlignRight
        x: auth.x - p.dp(32) - width
        y: Math.round(Math.min(p.height - p.pad - height, p.lineY - height / 2))
        maxWidth: Math.round(p.width * 0.28)
        gap: p.dp(14)
        delay: 0.46
        rise: p.dp(26)
    }

    AuthHost {
        id: auth

        stage: p.stage
        authStyle: "row"
        width: Math.round(Math.min(p.dp(380), p.width * 0.26))
        x: p.width - p.pad - p.dp(14) - width
        y: p.height - p.pad - height
        opacity: p.stage.rv(0.3)

        transform: Translate {
            y: (1 - p.stage.rv(0.3)) * 26
        }

    }

}
