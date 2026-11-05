import "../lucidwidgets" as LW
import QtQuick
import qs
import qs.lucidui

// one gauge, in one of six looks: a ring with its reading in the middle; a
// line with a bar under it; a tile the reading fills from the bottom; a
// small ring with the number beside it; its last readings as a curve (or a
// bar, for what keeps no history); or a dial, open at the foot
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
    // its last readings, 0 to 1, oldest first, where it keeps them
    property var history: []

    signal clicked()

    // as big as its share of the card allows, from the old 54 up to 84
    readonly property real ring: Math.round(Math.max(Theme.dp(54), Math.min(Theme.dp(84), g.width - Theme.dp(20))))
    readonly property string reading: g.center === "" || g.center === "—" ? "—" : g.center + "%"
    readonly property string glyph: g.centerIcon !== "" ? g.centerIcon : g.icon
    // the detail, unless it only says the name again
    readonly property string extra: g.detail.toLowerCase() === g.label.toLowerCase() ? "" : g.detail

    implicitHeight: ({
        "bars": Theme.dp(44),
        "tiles": Theme.dp(96),
        "compact": Theme.dp(44),
        "graph": Theme.dp(88),
        "dial": g.ring + (g.extra !== "" ? Theme.dp(22) : 0)
    })[g.look] || gcol.implicitHeight

    // a card with the name and the reading over its last readings drawn as a
    // curve; what keeps none gets a bar
    Rectangle {
        visible: g.look === "graph"
        anchors.fill: parent
        radius: Theme.shapeLg
        color: Theme.alpha(g.tone, 0.08)
        clip: true

        Icon {
            id: graphIcon

            x: Theme.dp(12)
            y: Theme.dp(12)
            name: g.glyph
            size: Theme.dp(16)
            fill: 1
            color: g.tone
        }

        LText {
            anchors.left: graphIcon.right
            anchors.leftMargin: Theme.dp(6)
            anchors.right: graphValue.left
            anchors.rightMargin: Theme.dp(6)
            anchors.verticalCenter: graphIcon.verticalCenter
            role: "labelMedium"
            color: Theme.subtext
            text: g.label
            elide: Text.ElideRight
        }

        LText {
            id: graphValue

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(12)
            anchors.verticalCenter: graphIcon.verticalCenter
            role: "titleSmall"
            weight: 680
            tabular: true
            text: g.reading
        }

        LW.Spark {
            visible: g.history.length > 1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.top: graphIcon.bottom
            anchors.topMargin: Theme.dp(8)
            samples: g.history
            lineColor: g.tone
            lineWidth: Theme.dp(2)
        }

        Column {
            visible: g.history.length < 2
            x: Theme.dp(12)
            width: parent.width - Theme.dp(24)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(14)
            spacing: Theme.dp(8)

            LText {
                width: parent.width
                visible: text !== ""
                role: "bodySmall"
                color: Theme.subtext
                text: g.extra
                elide: Text.ElideRight
            }

            LinearProgress {
                width: parent.width
                value: g.value
                thickness: Theme.dp(6)
                color: g.tone
                trackColor: Theme.withBlur(Theme.surfaceHighest)
            }

        }

    }

    // a dial: an arc open at the foot, the reading in its middle and the name in the gap
    Item {
        visible: g.look === "dial"
        anchors.horizontalCenter: parent.horizontalCenter
        width: g.ring
        height: parent.height

        LW.Gauge {
            id: dial

            width: g.ring
            height: g.ring
            value: g.value
            thickness: Math.round(g.ring * 0.1)
            startAngle: 135
            sweep: 270
            fillColor: g.tone
            trackColor: Theme.withBlur(Theme.surfaceHighest)
        }

        Row {
            anchors.centerIn: dial
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

        LText {
            anchors.horizontalCenter: dial.horizontalCenter
            anchors.bottom: dial.bottom
            width: Math.min(implicitWidth, g.ring * 0.62)
            role: "labelSmall"
            text: g.label
            elide: Text.ElideRight
        }

        LText {
            visible: text !== ""
            anchors.horizontalCenter: dial.horizontalCenter
            anchors.top: dial.bottom
            anchors.topMargin: Theme.dp(4)
            width: Math.min(implicitWidth, g.width - Theme.dp(4))
            role: "bodySmall"
            size: Theme.fs(11)
            color: Theme.subtext
            text: g.extra
            elide: Text.ElideRight
        }

        StateLayer {
            visible: g.clickable
            width: g.ring
            height: g.ring
            radius: g.ring / 2
            onClicked: g.clicked()
        }

    }

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
            text: g.extra
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
                text: g.extra !== "" ? g.label + " · " + g.extra : g.label
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
        visible: g.clickable && g.look !== "rings" && g.look !== "dial"
        anchors.fill: parent
        radius: g.look === "tiles" || g.look === "graph" ? Theme.shapeLg : Theme.dp(12)
        onClicked: g.clicked()
    }

    Column {
        id: gcol

        visible: ["bars", "tiles", "compact", "graph", "dial"].indexOf(g.look) === -1
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
                text: g.extra
                width: Math.min(implicitWidth, g.width - Theme.dp(4))
                elide: Text.ElideRight
            }

        }

    }

}
