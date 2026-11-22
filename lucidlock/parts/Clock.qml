import QtQuick
import "Catalog.js" as Catalog

// the time, four ways. stacked is lucid's own lock clock, the hour over the
// minute; inline reads in one line; dial is an analog face on a cookie; shapes
// sets each digit on a shape of its own, the way material's expressive clocks do
WidgetBase {
    id: clock

    readonly property string style: clock.opts.style || "stacked"
    readonly property bool mono: clock.opts.tone === "mono"
    readonly property bool seconds: clock.opts.seconds === true
    // the digits' height. the dp cap keeps a tall screen from a giant clock
    readonly property real unit: {
        var cap = ({
            "S": 96,
            "M": 130,
            "L": 178,
            "XL": 236
        })[clock.opts.size] || 178;
        return Math.round(Math.min(clock.dp(cap), Catalog.clockUnit(clock.opts.size, clock.screenH)));
    }
    // one number scales the face and the room it takes, so whatever sits
    // under the clock rides up with it while a password is typed
    readonly property real kk: 1 - clock.focusK * (1 - clock.shrinkTo)
    readonly property color hourInk: clock.mono ? clock.theme.text : clock.theme.clockHour
    readonly property color minuteInk: clock.mono ? clock.theme.text : clock.theme.accent
    readonly property int secs: clock.lock ? clock.lock.now.getSeconds() : 0
    readonly property int mins: clock.lock ? clock.lock.now.getMinutes() : 0
    readonly property int hrs: clock.lock ? clock.lock.now.getHours() : 0

    implicitWidth: Math.ceil(face.width * clock.kk)
    implicitHeight: Math.ceil(face.height * clock.kk)

    Loader {
        id: face

        x: clock.xFor(face.width * clock.kk, clock.width)
        transformOrigin: Item.TopLeft
        scale: clock.kk
        sourceComponent: {
            switch (clock.style) {
            case "inline":
                return inlineFace;
            case "dial":
                return dialFace;
            case "shapes":
                return shapesFace;
            }
            return stackedFace;
        }
    }

    // ── stacked: the hour over the minute ───────────────────────────────────
    Component {
        id: stackedFace

        Item {
            id: st

            readonly property real lineH: Math.round(clock.unit * 0.82)
            // a trailing negative letter spacing narrows the box, so the ink
            // drifts right of centre unless it is padded back
            readonly property real tail: Math.round(clock.unit * 0.03)
            readonly property real digitsW: Math.max(hour.implicitWidth, minute.implicitWidth)
            // the meridiem hangs off the minute; only a left-leaning clock
            // makes room for it, a centred one keeps its digits centred
            readonly property bool hang: clock.align !== Qt.AlignLeft

            width: st.digitsW + (ampm.visible && !st.hang ? ampm.implicitWidth + clock.dp(12) : 0)
            height: st.lineH * 2

            Text {
                id: hour

                width: st.digitsW
                height: st.lineH
                horizontalAlignment: clock.hAlign
                verticalAlignment: Text.AlignVCenter
                rightPadding: st.tail
                text: clock.lock ? clock.lock.hourText : ""
                color: clock.hourInk
                font.family: clock.theme.fontFamily
                font.pixelSize: Math.round(clock.unit)
                font.variableAxes: clock.theme.axes(Math.round(clock.unit), 560, 100)
                font.weight: Font.DemiBold
                font.letterSpacing: -st.tail
            }

            Text {
                id: minute

                y: st.lineH
                width: st.digitsW
                height: st.lineH
                horizontalAlignment: clock.hAlign
                verticalAlignment: Text.AlignVCenter
                rightPadding: st.tail
                text: clock.lock ? clock.lock.minuteText : ""
                color: clock.minuteInk
                font.family: clock.theme.fontFamily
                font.pixelSize: Math.round(clock.unit)
                font.variableAxes: clock.theme.axes(Math.round(clock.unit), 560, 100)
                font.weight: Font.DemiBold
                font.letterSpacing: -st.tail
            }

            Text {
                id: ampm

                // after the minute's ink, wherever the minute line leans
                x: (clock.align === Qt.AlignRight ? st.digitsW : (clock.align === Qt.AlignHCenter ? (st.digitsW + minute.contentWidth) / 2 : minute.contentWidth)) + clock.dp(12)
                y: st.lineH * 2 - Math.round(clock.unit * 0.16) - implicitHeight
                text: clock.lock ? clock.lock.meridiem : ""
                visible: text !== "" && clock.align !== Qt.AlignRight
                color: clock.theme.alpha(clock.mono ? clock.theme.subtext : clock.theme.accentMuted, 0.7)
                font.family: clock.theme.fontFamily
                font.pixelSize: Math.round(clock.unit * 0.16)
                font.variableAxes: clock.theme.axes(Math.round(clock.unit * 0.16), 520, 0)
                font.weight: Font.Medium
            }

        }

    }

    // ── inline: one line, colon in the accent ───────────────────────────────
    Component {
        id: inlineFace

        Row {
            id: il

            readonly property int px: Math.round(clock.unit * 0.92)

            spacing: 0

            Text {
                anchors.baseline: mm.baseline
                text: clock.lock ? clock.lock.hourText : ""
                color: clock.hourInk
                font.family: clock.theme.fontFamily
                font.pixelSize: il.px
                font.variableAxes: clock.theme.axes(il.px, 520, 100)
                font.weight: Font.Medium
                font.letterSpacing: -Math.round(il.px * 0.02)
            }

            // the colon breathes once a second, the one thing on the lock that ticks
            Text {
                anchors.baseline: mm.baseline
                leftPadding: Math.round(il.px * 0.02)
                rightPadding: Math.round(il.px * 0.04)
                text: ":"
                color: clock.mono ? clock.theme.subtext : clock.theme.accentMuted
                opacity: clock.secs % 2 === 0 ? 1 : 0.55
                font.family: clock.theme.fontFamily
                font.pixelSize: il.px
                font.variableAxes: clock.theme.axes(il.px, 520, 100)
                font.weight: Font.Medium

                Behavior on opacity {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.InOutSine
                    }

                }

            }

            Text {
                id: mm

                text: clock.lock ? clock.lock.minuteText : ""
                color: clock.minuteInk
                font.family: clock.theme.fontFamily
                font.pixelSize: il.px
                font.variableAxes: clock.theme.axes(il.px, 520, 100)
                font.weight: Font.Medium
                font.letterSpacing: -Math.round(il.px * 0.02)
            }

            Column {
                anchors.bottom: mm.baseline
                leftPadding: clock.dp(10)
                spacing: Math.round(il.px * 0.02)

                Text {
                    text: (clock.secs < 10 ? "0" : "") + clock.secs
                    visible: clock.seconds
                    color: clock.mono ? clock.theme.subtext : clock.theme.accentMuted
                    font.family: clock.theme.fontFamily
                    font.pixelSize: Math.round(il.px * 0.3)
                    font.variableAxes: clock.theme.axes(Math.round(il.px * 0.3), 520, 60)
                    font.weight: Font.Medium
                    font.features: ({
                        "tnum": 1
                    })
                }

                Text {
                    text: clock.lock ? clock.lock.meridiem : ""
                    visible: text !== ""
                    color: clock.theme.alpha(clock.mono ? clock.theme.subtext : clock.theme.accentMuted, 0.75)
                    font.family: clock.theme.fontFamily
                    font.pixelSize: Math.round(il.px * 0.17)
                    font.variableAxes: clock.theme.axes(Math.round(il.px * 0.17), 560, 0)
                    font.weight: Font.Medium
                }

            }

        }

    }

    // ── dial: hands on a cookie ─────────────────────────────────────────────
    Component {
        id: dialFace

        Item {
            id: dial

            readonly property real d: Math.round(clock.unit * 1.9)
            readonly property real r: dial.d / 2
            readonly property color faceInk: clock.mono ? clock.theme.cardHigh : clock.theme.accentContainer
            readonly property color handInk: clock.mono ? clock.theme.text : clock.theme.fgAccentContainer
            // counted up, never wrapped, so a hand passing twelve keeps turning forward
            property real secAngle: 0
            property int lastSec: -1

            function tickSeconds() {
                var s = clock.secs;
                if (dial.lastSec < 0)
                    dial.secAngle = s * 6;
                else
                    dial.secAngle += ((s - dial.lastSec + 60) % 60) * 6;
                dial.lastSec = s;
            }

            width: dial.d
            height: dial.d
            Component.onCompleted: dial.tickSeconds()

            Connections {
                function onSecsChanged() {
                    dial.tickSeconds();
                }

                target: clock
            }

            Blob {
                anchors.fill: parent
                shape: "cookie12"
                color: dial.faceInk
                // a twelfth of a turn an hour, so the scallops drift with the day
                spin: (clock.hrs % 12) * 2.5 + clock.mins * 2.5 / 60
            }

            // twelve, three, six and nine as pips; nothing else on the face
            Repeater {
                model: 4

                Rectangle {
                    required property int index
                    readonly property real a: index * Math.PI / 2

                    width: Math.round(clock.unit * 0.07)
                    height: width
                    radius: width / 2
                    x: dial.r + Math.sin(a) * dial.r * 0.74 - width / 2
                    y: dial.r - Math.cos(a) * dial.r * 0.74 - height / 2
                    color: clock.theme.alpha(dial.handInk, 0.45)
                }

            }

            // the minute hand, long, in the accent
            Rectangle {
                readonly property real len: dial.r * 0.7

                x: dial.r - width / 2
                y: dial.r - len
                width: Math.round(clock.unit * 0.075)
                height: len + width / 2
                radius: width / 2
                color: clock.mono ? clock.theme.subtext : clock.theme.accent
                transformOrigin: Item.Bottom
                rotation: (clock.mins + clock.secs / 60) * 6

                Behavior on rotation {
                    RotationAnimation {
                        direction: RotationAnimation.Clockwise
                        duration: 300
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // the hour hand, short and heavy, over it
            Rectangle {
                readonly property real len: dial.r * 0.46

                x: dial.r - width / 2
                y: dial.r - len
                width: Math.round(clock.unit * 0.11)
                height: len + width / 2
                radius: width / 2
                color: dial.handInk
                transformOrigin: Item.Bottom
                rotation: (clock.hrs % 12 + clock.mins / 60) * 30

                Behavior on rotation {
                    RotationAnimation {
                        direction: RotationAnimation.Clockwise
                        duration: 300
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Rectangle {
                width: Math.round(clock.unit * 0.13)
                height: width
                radius: width / 2
                anchors.centerIn: parent
                color: dial.handInk
            }

            // the seconds, as a dot running round the rim
            Item {
                anchors.fill: parent
                visible: clock.seconds
                rotation: dial.secAngle

                Behavior on rotation {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }

                }

                Rectangle {
                    width: Math.round(clock.unit * 0.09)
                    height: width
                    radius: width / 2
                    x: dial.r - width / 2
                    y: dial.r * 0.12 - height / 2
                    color: clock.theme.altAccent
                }

            }

        }

    }

    // ── shapes: a digit on each shape ───────────────────────────────────────
    Component {
        id: shapesFace

        Column {
            id: sh

            readonly property real tile: Math.round(clock.unit * 0.92)
            readonly property real gap: Math.round(clock.unit * 0.07)
            readonly property var shapes: ["cookie9", "clover4", "sunny", "cookie6"]

            spacing: sh.gap

            component Tile: Item {
                id: tile

                property string digit: "0"
                property string shape: "cookie9"
                property color fill: "grey"
                property color ink: "white"
                // a turn for every change, kept counting so it never runs back
                property real turns: 0

                width: sh.tile
                height: sh.tile
                onDigitChanged: tile.turns += 1

                Blob {
                    anchors.fill: parent
                    shape: tile.shape
                    color: tile.fill
                    spin: tile.turns * 40

                    Behavior on spin {
                        NumberAnimation {
                            duration: 650
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.4
                        }

                    }

                }

                Text {
                    anchors.centerIn: parent
                    text: tile.digit
                    color: tile.ink
                    font.family: clock.theme.fontFamily
                    font.pixelSize: Math.round(sh.tile * 0.62)
                    font.variableAxes: clock.theme.axes(Math.round(sh.tile * 0.62), 640, 100)
                    font.weight: Font.DemiBold
                }

            }

            Row {
                id: hourRow

                x: clock.xFor(hourRow.width, sh.width)
                spacing: sh.gap

                Repeater {
                    model: clock.lock ? clock.lock.hourText.split("") : []

                    Tile {
                        required property string modelData
                        required property int index

                        digit: modelData
                        shape: sh.shapes[index]
                        fill: clock.mono ? clock.theme.cardHigh : clock.theme.accentContainer
                        ink: clock.mono ? clock.theme.text : clock.theme.fgAccentContainer
                    }

                }

            }

            Row {
                id: minuteRow

                x: clock.xFor(minuteRow.width, sh.width)
                spacing: sh.gap

                Repeater {
                    model: clock.lock ? clock.lock.minuteText.split("") : []

                    Tile {
                        required property string modelData
                        required property int index

                        digit: modelData
                        shape: sh.shapes[2 + index]
                        fill: clock.mono ? clock.theme.card : clock.theme.altContainer
                        ink: clock.mono ? clock.theme.text : clock.theme.fgAltContainer
                    }

                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(sh.tile * 0.08)
                    text: clock.lock ? clock.lock.meridiem : ""
                    visible: text !== ""
                    color: clock.theme.alpha(clock.mono ? clock.theme.subtext : clock.theme.accentMuted, 0.8)
                    font.family: clock.theme.fontFamily
                    font.pixelSize: Math.round(clock.unit * 0.17)
                    font.variableAxes: clock.theme.axes(Math.round(clock.unit * 0.17), 560, 0)
                    font.weight: Font.Medium
                }

            }

        }

    }

}
