import QtQuick
import qs

// the launcher's button: two rows of two rounded squares, drawn as outlines in
// the wallpaper's own colour, a few tones down. lit (hovered, or the launcher
// open) the lines brighten and the squares round into circles, one after another
Item {
    id: grid

    property bool lit: false
    readonly property color ink: Theme.atTone(Theme.cPrimary, grid.lit ? (Theme.isLight ? 25 : 85) : (Theme.isLight ? 40 : 70))
    // whole pixels throughout, so the outlines stay crisp
    readonly property int cell: Math.max(4, Math.round(Math.min(grid.width, grid.height) * 0.21))
    readonly property int gap: Math.max(2, Math.round(grid.cell * 0.38))
    readonly property int line: Math.max(1, Math.round(grid.cell * 0.16))
    readonly property int span: 2 * grid.cell + grid.gap

    Repeater {
        model: 4

        delegate: Rectangle {
            required property int index
            readonly property int col: index % 2
            readonly property int row: Math.floor(index / 2)

            x: Math.round((grid.width - grid.span) / 2) + col * (grid.cell + grid.gap)
            y: Math.round((grid.height - grid.span) / 2) + row * (grid.cell + grid.gap)
            width: grid.cell
            height: grid.cell
            radius: grid.lit ? grid.cell / 2 : Math.round(grid.cell * 0.3)
            color: "transparent"
            border.width: grid.line
            border.color: grid.ink

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

            Behavior on radius {
                SequentialAnimation {
                    PauseAnimation {
                        duration: Math.round((col + row) * 45 * Theme.motionScale)
                    }

                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

    }

}
