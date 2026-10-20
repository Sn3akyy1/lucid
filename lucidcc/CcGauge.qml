import QtQuick
import qs
import qs.lucidui

// one gauge, in one of four looks: a ring with its reading in the middle; a
// line with a bar under it; a tile the reading fills from the bottom; or a
// small ring with the number beside it
Item {
    id: g

    property real value: 0
    property string center: ""
    property string centerIcon: ""
    property string label: ""
    property string detail: ""
    property color tone: Theme.accent
    property bool clickable: false
    // rings, bars, tiles or compact
    property string look: "rings"
    // what it measures, for the looks that show it beside the reading
    property string icon: ""

    signal clicked()

    // as big as its share of the card allows, from the old 54 up to 84
    readonly property real ring: Math.round(Math.max(Theme.dp(54), Math.min(Theme.dp(84), g.width - Theme.dp(20))))
    readonly property string reading: g.center === "" || g.center === "—" ? "—" : g.center + "%"
    readonly property string glyph: g.centerIcon !== "" ? g.centerIcon : g.icon

    implicitHeight: g.look === "bars" ? Theme.dp(44) : (g.look === "tiles" ? Theme.dp(96) : (g.look === "compact" ? Theme.dp(44) : gcol.implicitHeight))

    // a line: its icon and name, the reading at the end, over a bar
    Item {
        visible: g.look === "bars"
        anchors.fill: parent

        Icon {
            id: barIcon

            y: Theme.dp(1)
            name: g.glyph
            size: Theme.dp(18)
            fill: 1
            color: g.tone
        }

        LText {
            id: barLabel

            anchors.left: barIcon.right
            anchors.leftMargin: Theme.dp(8)
            anchors.verticalCenter: barIcon.verticalCenter
            width: Math.min(implicitWidth, barValue.x - x - Theme.dp(8))
            role: "labelLarge"
            text: g.label
            elide: Text.ElideRight
        }

        LText {
            anchors.right: barValue.left
            anchors.rightMargin: Theme.dp(8)
            anchors.verticalCenter: barIcon.verticalCenter
            width: Math.max(0, Math.min(implicitWidth, barValue.x - barLabel.x - barLabel.width - Theme.dp(16)))
            role: "labelMedium"
            color: Theme.subtext
            text: g.detail
            elide: Text.ElideRight
        }

        LText {
            id: barValue

            anchors.right: parent.right
            anchors.verticalCenter: barIcon.verticalCenter
            role: "labelLarge"
            weight: 680
            tabular: true
            text: g.reading
        }

        LinearProgress {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(4)
            width: parent.width
            value: g.value
            thickness: Theme.dp(8)
            color: g.tone
            trackColor: Theme.withBlur(Theme.surfaceHighest)
        }

    }

    // a tile the reading fills from the bottom, its number large
    Rectangle {
        visible: g.look === "tiles"
        anchors.fill: parent
        radius: Theme.shapeLg
        color: Theme.alpha(g.tone, 0.12)
        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * Math.max(0, Math.min(1, g.value))
            radius: parent.radius
            color: Theme.alpha(g.tone, 0.2)

            Behavior on height {
                NumberAnimation {
                    duration: Theme.durDefaultSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }

            }

        }

        Icon {
            x: Theme.dp(12)
            y: Theme.dp(10)
            name: g.glyph
            size: Theme.dp(20)
            fill: 1
            color: g.tone
        }

        Column {
            x: Theme.dp(12)
            width: parent.width - Theme.dp(24)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(8)
            spacing: -Theme.dp(3)

            LText {
                role: "headlineSmall"
                weight: 680
                rounded: 100
                tabular: true
                text: g.reading
            }

            LText {
                width: parent.width
                role: "labelMedium"
                color: Theme.subtext
                // a detail that only says the name again is left out
                text: g.detail !== "" && g.detail.toLowerCase() !== g.label.toLowerCase() ? g.label + " · " + g.detail : g.label
                elide: Text.ElideRight
            }

        }

    }

    // a small ring with its icon, the number and the name beside it
    Row {
        visible: g.look === "compact"
        anchors.centerIn: parent
        spacing: Theme.dp(8)

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(36)
            height: Theme.dp(36)

            CircularProgress {
                anchors.fill: parent
                value: g.value
                thickness: Theme.dp(4)
                wavy: false
                color: g.tone
                trackColor: Theme.withBlur(Theme.surfaceHighest)
            }

            Icon {
                anchors.centerIn: parent
                name: g.glyph
                size: Theme.dp(16)
                fill: 1
                color: g.tone
            }

        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -Theme.dp(3)

            LText {
                role: "titleSmall"
                weight: 680
                tabular: true
                text: g.reading
            }

            LText {
                role: "labelSmall"
                color: Theme.subtext
                text: g.label
            }

        }

    }

    StateLayer {
        visible: g.clickable && g.look !== "rings"
        anchors.fill: parent
        radius: g.look === "tiles" ? Theme.shapeLg : Theme.dp(12)
        onClicked: g.clicked()
    }

    Column {
        id: gcol

        visible: g.look !== "bars" && g.look !== "tiles" && g.look !== "compact"
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.dp(6)

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: g.ring
            height: g.ring

            CircularProgress {
                anchors.fill: parent
                value: g.value
                thickness: Math.round(g.ring * 0.1)
                // past 72 the ring would turn wavy on its own; a gauge reads better plain
                wavy: false
                color: g.tone
                trackColor: Theme.withBlur(Theme.surfaceHighest)
            }

            Row {
                anchors.centerIn: parent
                spacing: 0

                Icon {
                    visible: g.centerIcon !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    name: g.centerIcon
                    size: Math.round(g.ring * 0.24)
                    fill: 1
                    color: g.tone
                }

                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "labelLarge"
                    size: Math.round(g.ring * 0.27)
                    weight: 680
                    rounded: 100
                    text: g.center
                }

            }

            StateLayer {
                visible: g.clickable
                radius: g.ring / 2
                onClicked: g.clicked()
            }

        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "labelMedium"
                text: g.label
                width: Math.min(implicitWidth, g.width - Theme.dp(4))
                elide: Text.ElideRight
            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                role: "bodySmall"
                size: Theme.fs(11)
                color: Theme.subtext
                text: g.detail
                width: Math.min(implicitWidth, g.width - Theme.dp(4))
                elide: Text.ElideRight
            }

        }

    }

}
