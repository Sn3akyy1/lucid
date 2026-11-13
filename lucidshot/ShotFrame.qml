import QtQuick
import qs
import qs.lucidui

// the selection's frame: an outline just outside it, so every chosen pixel
// stays in view, viewfinder brackets at the corners, and handles to reshape it
// with while it can still change. sizes and names hang off the bottom edge
Item {
    id: fr

    // the stage, for handle drags
    property var stage: null
    property bool handles: false
    property string sizeText: ""
    property string caption: ""
    property color ink: Theme.primary
    // a window's own corners, so its outline follows them
    property real radius: 0
    // room the chip has below the frame, or it goes above
    property real roomBelow: 100
    readonly property int bracket: Theme.dp(26)
    readonly property int thick: Theme.dp(4)

    Rectangle {
        x: -2
        y: -2
        width: fr.width + 4
        height: fr.height + 4
        color: "transparent"
        border.width: 2
        border.color: fr.ink
        radius: fr.radius > 0 ? fr.radius + 2 : 2
    }

    Repeater {
        model: 4

        Item {
            id: corner

            required property int index
            readonly property bool isRight: corner.index % 2 === 1
            readonly property bool isBottom: corner.index > 1

            x: corner.isRight ? fr.width + 2 - fr.bracket + fr.thick : -2 - fr.thick
            y: corner.isBottom ? fr.height + 2 - fr.bracket + fr.thick : -2 - fr.thick
            width: fr.bracket
            height: fr.bracket
            visible: fr.radius === 0 && fr.width > fr.bracket * 2 && fr.height > fr.bracket * 2

            Rectangle {
                x: 0
                y: corner.isBottom ? corner.height - fr.thick : 0
                width: corner.width
                height: fr.thick
                radius: fr.thick / 2
                color: fr.ink
            }

            Rectangle {
                x: corner.isRight ? corner.width - fr.thick : 0
                y: 0
                width: fr.thick
                height: corner.height
                radius: fr.thick / 2
                color: fr.ink
            }

        }

    }

    // l, t, r, b by twos: corners first, then the middles of the edges
    Repeater {
        model: fr.handles ? ["tl", "tr", "bl", "br", "t", "b", "l", "r"] : []

        Item {
            id: h

            required property string modelData
            readonly property bool isCorner: h.modelData.length === 2
            readonly property real hx: h.modelData.indexOf("l") !== -1 ? 0 : (h.modelData.indexOf("r") !== -1 ? fr.width : fr.width / 2)
            readonly property real hy: h.modelData.indexOf("t") !== -1 ? 0 : (h.modelData.indexOf("b") !== -1 ? fr.height : fr.height / 2)
            readonly property bool sideways: h.modelData === "l" || h.modelData === "r"

            x: Math.round(h.hx - width / 2)
            y: Math.round(h.hy - height / 2)
            width: Theme.dp(28)
            height: Theme.dp(28)
            // a frame too small for edge handles keeps its corners
            visible: h.isCorner || (h.sideways ? fr.height > Theme.dp(72) : fr.width > Theme.dp(72))

            Rectangle {
                anchors.centerIn: parent
                width: h.isCorner ? Theme.dp(14) : (h.sideways ? Theme.dp(6) : Theme.dp(26))
                height: h.isCorner ? Theme.dp(14) : (h.sideways ? Theme.dp(26) : Theme.dp(6))
                radius: Math.min(width, height) / 2
                color: fr.ink
                border.width: Theme.dp(2)
                border.color: Theme.surfaceContainer
                scale: grab.pressed ? 1.25 : (grab.containsMouse ? 1.12 : 1)

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveFastSpatial
                    }

                }

            }

            MouseArea {
                id: grab

                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: {
                    switch (h.modelData) {
                    case "tl":
                    case "br":
                        return Qt.SizeFDiagCursor;
                    case "tr":
                    case "bl":
                        return Qt.SizeBDiagCursor;
                    case "l":
                    case "r":
                        return Qt.SizeHorCursor;
                    }
                    return Qt.SizeVerCursor;
                }
                onPressed: (mouse) => {
                    const p = grab.mapToItem(fr.stage, mouse.x, mouse.y);
                    fr.stage.reshapeStart(h.modelData, p.x, p.y);
                }
                onPositionChanged: (mouse) => {
                    if (!grab.pressed)
                        return ;

                    const p = grab.mapToItem(fr.stage, mouse.x, mouse.y);
                    fr.stage.reshapeMove(p.x, p.y, mouse.modifiers);
                }
                onReleased: fr.stage.reshapeEnd()

                HeldPointer {
                    held: grab.pressed
                    cursor: grab.cursorShape
                }

            }

        }

    }

    Row {
        id: chips

        readonly property bool below: fr.roomBelow > chips.height + Theme.dp(20)

        x: Math.round((fr.width - chips.width) / 2)
        y: chips.below ? fr.height + Theme.dp(12) : -chips.height - Theme.dp(12)
        spacing: Theme.dp(6)
        visible: fr.sizeText !== "" && fr.width > 0

        ShotChip {
            visible: fr.caption !== ""
            text: fr.caption
            tabular: false
        }

        ShotChip {
            text: fr.sizeText
            strong: true
        }

    }

}
