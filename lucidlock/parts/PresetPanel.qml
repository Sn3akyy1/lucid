import QtQuick

// panel: a side sheet holds the sign-in, with a slot over it and one under;
// the wallpaper keeps the rest, the clock big in its bottom corner. the sheet
// is as tall as what it holds, centred, and never shorter than half the screen
Item {
    id: p

    property var stage: null
    readonly property alias authHost: auth
    readonly property real pad: p.stage.pad
    readonly property bool onLeft: p.stage.presetOpt("side") === "left"
    readonly property real sheetW: Math.round(Math.max(p.dp(360), Math.min(p.dp(470), p.width * 0.27)))
    readonly property real sheetPad: p.dp(36)
    readonly property real inner: p.sheetW - p.sheetPad * 2
    readonly property real sheetH: Math.min(p.height - p.pad * 2, Math.max(Math.round(p.height * 0.56), stack.height + p.sheetPad * 2))
    // the wallpaper's share of the screen
    readonly property real canvasW: p.width - p.sheetW - p.pad * 3
    readonly property real canvasX: p.onLeft ? p.width - p.pad - p.dp(14) : p.pad + p.dp(14)
    // picked while the lock is already up (a switch in the editor), the
    // sheet slides in on its own rather than on the arrival's clock
    property real enter: 1
    readonly property real sheetIn: p.stage.rv(0.04) * p.enter
    readonly property real sheetShift: (1 - p.sheetIn) * (p.onLeft ? -p.dp(90) : p.dp(90))
    readonly property int glideMs: p.stage.theme.ms(520)

    function dp(px) {
        return p.stage.dp(px);
    }

    Component.onCompleted: {
        if (p.stage.flipOk) {
            p.enter = 0;
            enterAnim.start();
        }
    }

    NumberAnimation {
        id: enterAnim

        target: p
        property: "enter"
        to: 1
        duration: p.stage.theme.ms(520)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: p.stage.theme.easeEmphasizedDecel
    }

    Slot {
        stage: p.stage
        slotId: "canvasTop"
        align: p.onLeft ? Qt.AlignRight : Qt.AlignLeft
        x: p.onLeft ? p.canvasX - width : p.canvasX
        y: p.pad
        maxWidth: Math.round(p.canvasW * 0.6)
        delay: 0.2
        rise: -p.dp(24)
        dim: 0.55
    }

    Slot {
        stage: p.stage
        slotId: "canvas"
        align: p.onLeft ? Qt.AlignRight : Qt.AlignLeft
        x: p.onLeft ? p.canvasX - width : p.canvasX
        y: p.height - p.pad - p.dp(6) - height
        maxWidth: p.canvasW
        gap: p.dp(14)
        delay: 0.26
        dim: 0.45
        rise: p.dp(30)
    }

    // the sheet: a solid surface, floating clear of the screen's edges
    Rectangle {
        id: sheet

        x: p.onLeft ? p.pad : p.width - p.pad - p.sheetW
        y: Math.round((p.height - p.sheetH) / 2)
        width: p.sheetW
        height: p.sheetH
        radius: p.stage.theme.shapeXlInc
        color: p.stage.theme.card
        opacity: p.sheetIn

        // a widget in or out, or the sheet sent to the other side, eases it
        // there; never on the first layout, which the arrival already covers
        Behavior on x {
            enabled: p.stage.flipOk

            NumberAnimation {
                duration: p.glideMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: p.stage.theme.curveDefaultSpatial
            }

        }

        Behavior on y {
            enabled: p.stage.flipOk

            NumberAnimation {
                duration: p.glideMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: p.stage.theme.curveDefaultSpatial
            }

        }

        Behavior on height {
            enabled: p.stage.flipOk

            NumberAnimation {
                duration: p.glideMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: p.stage.theme.curveDefaultSpatial
            }

        }

        transform: Translate {
            x: p.sheetShift
        }

    }

    // the sheet's contents, spread over its height: the top slot at the top,
    // the bottom slot at the bottom, the sign-in centred between
    Item {
        id: inside

        x: sheet.x + p.sheetPad
        y: sheet.y + p.sheetPad
        width: p.inner
        // the sheet's drawn height, so what sits on its floor rides it
        height: sheet.height - p.sheetPad * 2
        opacity: p.sheetIn

        transform: Translate {
            x: p.sheetShift
        }

        // what the sheet holds, measured as one column so the sheet can fit it
        Column {
            id: stack

            visible: false
            spacing: p.dp(28)

            Item {
                width: 1
                height: sheetTopSlot.height
            }

            Item {
                width: 1
                height: auth.height
            }

            Item {
                width: 1
                height: sheetBottomSlot.height
            }

        }

        Slot {
            id: sheetTopSlot

            stage: p.stage
            slotId: "sheetTop"
            onCard: true
            align: Qt.AlignHCenter
            x: (inside.width - width) / 2
            y: 0
            maxWidth: p.inner
            delay: 0.14
            rise: -p.dp(16)
        }

        AuthHost {
            id: auth

            readonly property real lowest: sheetTopSlot.height > 0 ? sheetTopSlot.height + p.dp(28) : 0
            readonly property real highest: sheetBottomSlot.y - (sheetBottomSlot.height > 0 ? p.dp(28) : 0) - auth.height

            stage: p.stage
            authStyle: "sheet"
            width: p.inner
            y: Math.max(auth.lowest, Math.min((inside.height - auth.height) / 2, auth.highest))
            opacity: p.stage.rv(0.18)

            transform: Translate {
                y: (1 - p.stage.rv(0.18)) * 26
            }

        }

        Slot {
            id: sheetBottomSlot

            stage: p.stage
            slotId: "sheetBottom"
            onCard: true
            align: Qt.AlignHCenter
            x: (inside.width - width) / 2
            y: inside.height - height
            maxWidth: p.inner
            maxHeight: Math.round((p.height - p.pad * 2) * 0.46)
            gap: p.dp(14)
            delay: 0.34
            dim: 0.55
            rise: p.dp(26)
        }

    }

}
