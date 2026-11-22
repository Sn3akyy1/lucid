import QtQuick

// bento: every widget on a card of its own, two columns gathered in the
// middle of the screen, the sign-in heading the right one
Item {
    id: p

    property var stage: null
    readonly property alias authHost: auth
    readonly property real pad: p.stage.pad
    readonly property real gap: p.dp(16)
    readonly property real colW: Math.round(Math.min(p.dp(470), p.width * 0.25, (p.width - p.pad * 2 - p.gap) / 2))
    readonly property real blockW: p.colW * 2 + p.gap
    readonly property real bandTop: p.pad + topRow.height + p.dp(24)
    readonly property real bandBottom: p.height - p.pad - foot.height - p.dp(24)
    readonly property real blockH: Math.max(leftCol.height, rightCol.height)

    function dp(px) {
        return p.stage.dp(px);
    }

    Slot {
        id: topRow

        stage: p.stage
        slotId: "top"
        row: true
        align: Qt.AlignHCenter
        x: (p.width - width) / 2
        y: p.pad
        maxWidth: Math.round(p.width * 0.6)
        gap: p.dp(12)
        delay: 0
        rise: -p.dp(24)
    }

    Item {
        id: block

        x: (p.width - p.blockW) / 2
        y: p.bandTop + Math.max(0, (p.bandBottom - p.bandTop - p.blockH) / 2)
        width: p.blockW
        height: p.blockH

        Slot {
            id: leftCol

            stage: p.stage
            slotId: "left"
            cards: true
            align: Qt.AlignHCenter
            maxWidth: p.colW
            maxHeight: p.bandBottom - p.bandTop
            gap: p.gap
            delay: 0.08
            dim: 0.5
            rise: p.dp(30)
        }

        Column {
            id: rightCol

            x: p.colW + p.gap
            width: p.colW
            spacing: p.gap

            AuthHost {
                id: auth

                stage: p.stage
                authStyle: "card"
                width: p.colW
                height: implicitHeight
                opacity: p.stage.rv(0.16)
                scale: 0.96 + 0.04 * p.stage.rv(0.16)

                transform: Translate {
                    y: (1 - p.stage.rv(0.16)) * 30
                }

            }

            Slot {
                stage: p.stage
                slotId: "right"
                cards: true
                align: Qt.AlignHCenter
                maxWidth: p.colW
                maxHeight: Math.max(p.dp(140), p.bandBottom - p.bandTop - auth.height - p.gap)
                gap: p.gap
                delay: 0.26
                dim: 0.5
                rise: p.dp(30)
            }

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
        gap: p.dp(16)
        delay: 0.45
        rise: p.dp(26)
    }

}
