import QtQuick

// split, lucid's first lock: the day on the left, the sign-in on the right
// with whatever is happening under it, the corners for the rest
Item {
    id: p

    property var stage: null
    readonly property alias authHost: auth
    readonly property real pad: p.stage.pad
    readonly property real rightW: Math.round(Math.max(p.dp(340), Math.min(p.dp(440), p.width * 0.25)))
    readonly property real colTop: p.pad + p.dp(66)
    readonly property real colBottom: p.height - p.pad - p.dp(64)

    function dp(px) {
        return p.stage.dp(px);
    }

    Slot {
        stage: p.stage
        slotId: "topLeft"
        align: Qt.AlignLeft
        x: p.pad + p.dp(14)
        y: p.pad
        maxWidth: Math.round(p.width * 0.4)
        delay: 0
        rise: -p.dp(24)
    }

    Slot {
        stage: p.stage
        slotId: "topRight"
        align: Qt.AlignRight
        x: p.width - p.pad - width
        y: p.pad
        maxWidth: Math.round(p.width * 0.4)
        delay: 0.06
        rise: -p.dp(24)
    }

    Slot {
        id: hero

        stage: p.stage
        slotId: "hero"
        align: Qt.AlignLeft
        x: p.pad + p.dp(14)
        y: (p.height - height) / 2
        maxWidth: p.width - p.rightW - p.pad * 3
        gap: p.dp(16)
        delay: 0.1
        dim: 0
        shrinkTo: 0.52
        rise: 22
    }

    Column {
        id: column

        x: p.width - p.pad - p.rightW
        y: p.colTop + Math.max(0, (p.colBottom - p.colTop - height) / 2)
        width: p.rightW
        spacing: p.dp(18)

        AuthHost {
            id: auth

            stage: p.stage
            authStyle: "card"
            width: p.rightW
            height: implicitHeight
            opacity: p.stage.rv(0.16)
            transformOrigin: Item.Right
            scale: 0.96 + 0.04 * p.stage.rv(0.16)

            transform: Translate {
                x: (1 - p.stage.rv(0.16)) * 44
            }

        }

        Slot {
            stage: p.stage
            slotId: "side"
            align: Qt.AlignLeft
            maxWidth: p.rightW
            maxHeight: Math.max(p.dp(140), p.colBottom - p.colTop - auth.height - column.spacing)
            gap: p.dp(18)
            delay: 0.32
            dim: 0.5
            rise: 0
            riseX: 44
        }

    }

    Slot {
        stage: p.stage
        slotId: "bottomLeft"
        align: Qt.AlignLeft
        x: p.pad + p.dp(14)
        y: p.height - p.pad - height
        maxWidth: Math.round(p.width * 0.5)
        delay: 0.5
        rise: 30
    }

}
