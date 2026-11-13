import QtQuick
import qs
import qs.lucidlumen
import qs.lucidui
import "ClockMath.js" as CM

// countdowns. a keypad sets one up (typed digits fill from the right, as on a
// microwave: 1 5 0 0 is fifteen minutes), and the running ones share the pane
// as a grid of cards, each as big as the room lets it be: one timer is one
// big ring, several sit side by side
Item {
    id: page

    property var app: null
    property var win: null
    property bool shown: false
    // a new timer's digits as typed, hhmmss filled from the right
    property string digits: ""
    property bool composing: false
    property real nowMs: Date.now()
    readonly property var timers: page.app ? (page.app.chrono.timers || []) : []
    readonly property bool listing: page.timers.length > 0 && !page.composing
    readonly property int setupSec: {
        const d = ("000000" + page.digits).slice(-6);
        return parseInt(d.slice(0, 2), 10) * 3600 + parseInt(d.slice(2, 4), 10) * 60 + parseInt(d.slice(4, 6), 10);
    }
    readonly property string primaryIcon: page.listing ? "add" : ""
    readonly property string primaryLabel: "New timer"
    readonly property var presets: [60, 180, 300, 600, 900, 1800, 3600]
    readonly property bool anyRunning: page.timers.some((t) => {
        return t.running;
    })
    readonly property int edge: Theme.dp(32)
    readonly property int gap: Theme.dp(14)
    readonly property real bodyW: page.width - page.edge * 2
    readonly property real bodyH: page.height - head.height - Theme.dp(24)
    // the grid: as many columns as fit and are worth having, then rows to suit
    readonly property int cols: Math.max(1, Math.min(page.timers.length <= 1 ? 1 : (page.timers.length <= 4 ? 2 : 3), Math.floor((page.bodyW + page.gap) / (Theme.dp(300) + page.gap))))
    readonly property int rowsN: Math.max(1, Math.ceil(page.timers.length / page.cols))
    readonly property real cellW: (page.bodyW - (page.cols - 1) * page.gap) / page.cols
    readonly property real cellH: Math.max(Theme.dp(330), (page.bodyH - (page.rowsN - 1) * page.gap) / page.rowsN)
    // the keypad, sized to the pane's height
    readonly property real keyH: Math.max(Theme.dp(52), Math.min(Theme.dp(84), (page.bodyH - Theme.dp(300)) / 4.4))

    function primaryAction() {
        page.digits = "";
        nameField.text = "";
        page.composing = true;
    }

    function press(k) {
        if (k === "back")
            page.digits = page.digits.slice(0, -1);
        else if (page.digits.length + k.length <= 6 && !(page.digits === "" && /^0+$/.test(k)))
            page.digits += k;
    }

    function start(sec) {
        const s = sec || page.setupSec;
        if (s <= 0)
            return ;

        // an unnamed one is called by its length, to the second: "2:30 timer"
        page.app.send("timer.add", {
            "sec": s,
            "name": nameField.text.trim() !== "" ? nameField.text.trim() : page.lengthText(s) + " timer"
        });
        // the last few lengths, for one tap next time
        const recent = [s].concat((page.app.prefs.recentTimers || []).filter((x) => {
            return x !== s;
        })).filter((x) => {
            return page.presets.indexOf(x) < 0;
        }).slice(0, 4);
        page.app.prefs.recentTimers = recent;
        page.digits = "";
        nameField.text = "";
        page.composing = false;
    }

    function handleKey(e) {
        if (nameField.input.activeFocus)
            return false;

        if (!page.listing) {
            if (e.text >= "0" && e.text <= "9" && e.text.length === 1) {
                page.press(e.text);
                return true;
            }
            if (e.key === Qt.Key_Backspace) {
                page.press("back");
                return true;
            }
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                page.start();
                return true;
            }
            if (e.key === Qt.Key_Escape && page.timers.length > 0) {
                page.composing = false;
                return true;
            }
        } else if (e.key === Qt.Key_N && !(e.modifiers & Qt.ControlModifier)) {
            page.primaryAction();
            return true;
        } else if (e.key === Qt.Key_Space && page.timers.length === 1) {
            page.app.send("timer.toggle", {
                "id": page.timers[0].id
            });
            return true;
        }
        return false;
    }

    function lengthText(sec) {
        if (sec % 3600 === 0)
            return sec / 3600 + " h";

        if (sec >= 3600)
            return Math.floor(sec / 3600) + " h " + Math.round((sec % 3600) / 60) + " min";

        if (sec % 60 === 0)
            return sec / 60 + " min";

        return CM.clock(sec * 1000, false);
    }

    // the timers run in the shell; this only needs to redraw while one counts
    Timer {
        interval: 100
        repeat: true
        running: page.shown && (page.anyRunning || page.timers.some((t) => {
            return !t.running && t.left <= 0;
        }))
        triggeredOnStart: true
        onTriggered: page.nowMs = Date.now()
    }

    PageHead {
        id: head

        x: page.edge
        width: parent.width - page.edge * 2
        title: "Timer"
        subtitle: {
            if (!page.listing)
                return page.timers.length ? "A new timer, beside the " + page.timers.length + " you have" : "Type a length, or pick one";

            const run = page.timers.filter((t) => {
                return t.running;
            }).length;
            return page.timers.length + (page.timers.length === 1 ? " timer" : " timers") + (run ? ", " + run + " running" : "");
        }

        Button {
            visible: page.listing && page.timers.some((t) => {
                return !t.running && t.left <= 0;
            })
            variant: "text"
            icon: "done_all"
            text: "Clear finished"
            onClicked: page.app.send("timer.clear")
        }

        Button {
            visible: !page.listing && page.timers.length > 0
            variant: "text"
            text: "Cancel"
            onClicked: page.composing = false
        }

    }

    // ---- the running ones
    Scroller {
        id: listView

        visible: page.listing
        y: head.height
        width: page.width
        height: page.height - head.height
        contentHeight: grid.implicitHeight + Theme.dp(24)

        Grid {
            id: grid

            x: page.edge
            columns: page.cols
            spacing: page.gap

            Repeater {
                model: page.timers

                TimerCard {
                    required property var modelData

                    width: page.cellW
                    height: page.cellH
                    t: modelData
                }

            }

        }

    }

    // ---- a new one, in the middle of the pane
    Item {
        id: composer

        visible: !page.listing
        y: head.height
        width: page.width
        height: page.height - head.height

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(0, (parent.height - implicitHeight) / 2 - Theme.dp(20))
            spacing: Theme.dp(20)

            // 00h 05m 00s, the typed part bright
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.dp(12)

                Repeater {
                    model: [{
                        "at": 0,
                        "unit": "h"
                    }, {
                        "at": 2,
                        "unit": "m"
                    }, {
                        "at": 4,
                        "unit": "s"
                    }]

                    Row {
                        required property var modelData
                        readonly property string pair: ("000000" + page.digits).slice(-6).substr(modelData.at, 2)
                        // the typed digits reach this pair
                        readonly property bool lit: page.digits.length > 4 - modelData.at

                        spacing: Theme.dp(2)

                        LText {
                            id: pairText

                            size: Math.round(page.keyH * 1.05)
                            weight: 480
                            rounded: 100
                            tabular: true
                            color: parent.lit ? Theme.text : Theme.alpha(Theme.text, 0.25)
                            text: parent.pair
                        }

                        LText {
                            anchors.baseline: pairText.baseline
                            size: Math.round(page.keyH * 0.34)
                            weight: 600
                            color: parent.lit ? Theme.primary : Theme.alpha(Theme.text, 0.25)
                            text: modelData.unit
                        }

                    }

                }

            }

            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 3
                columnSpacing: Theme.dp(14)
                rowSpacing: Theme.dp(10)

                Repeater {
                    model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "00", "0", "back"]

                    Rectangle {
                        required property string modelData

                        width: Math.round(page.keyH * 1.4)
                        height: Math.round(page.keyH)
                        radius: height / 2
                        color: modelData === "back" ? Theme.secondaryContainer : Theme.withBlur(Theme.bgTile)
                        opacity: modelData === "back" && page.digits === "" ? 0.4 : 1

                        LText {
                            visible: parent.modelData !== "back"
                            anchors.centerIn: parent
                            size: Math.round(page.keyH * 0.4)
                            weight: 520
                            text: parent.modelData
                        }

                        Icon {
                            visible: parent.modelData === "back"
                            anchors.centerIn: parent
                            name: "chevron_left"
                            size: Math.round(page.keyH * 0.42)
                            color: Theme.fgSecondaryContainer
                        }

                        StateLayer {
                            radius: parent.radius
                            onClicked: page.press(parent.modelData)
                        }

                    }

                }

            }

            // the usual lengths, and the last few used
            Flow {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(composer.width - page.edge * 2, Theme.dp(560))
                spacing: Theme.dp(8)

                Repeater {
                    model: page.presets.concat(page.app ? (page.app.prefs.recentTimers || []) : [])

                    Chip {
                        required property int modelData
                        required property int index

                        kind: "assist"
                        icon: index >= page.presets.length ? "history" : ""
                        text: page.lengthText(modelData)
                        onClicked: page.start(modelData)
                    }

                }

            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.dp(12)

                TextField {
                    id: nameField

                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(280)
                    label: "Name"
                    placeholder: "Tea, the oven…"
                    icon: "label"
                    containerColor: Theme.withBlur(Theme.bgTile)
                    onAccepted: page.start()
                }

                // the one big control, as a clock app's start button is
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(104)
                    height: Theme.dp(64)
                    radius: Theme.dp(20)
                    color: page.setupSec > 0 ? Theme.primary : Theme.alpha(Theme.text, Theme.disabledContainer)

                    Icon {
                        anchors.centerIn: parent
                        name: "play_arrow"
                        size: Theme.dp(30)
                        fill: 1
                        color: page.setupSec > 0 ? Theme.fgPrimary : Theme.disabledContent
                    }

                    StateLayer {
                        objectName: "timerStart"
                        radius: parent.radius
                        tint: Theme.fgPrimary
                        disabled: page.setupSec <= 0
                        onClicked: page.start()
                    }

                }

            }

        }

    }

    component TimerCard: Rectangle {
        id: card

        property var t: ({
        })
        readonly property real rem: card.t.running ? Math.max(0, card.t.endsAt - page.nowMs) : card.t.left
        readonly property bool done: !card.t.running && card.t.left <= 0
        readonly property bool paused: !card.t.running && card.t.left > 0 && card.t.left < card.t.total
        readonly property real frac: card.t.total > 0 ? card.rem / card.t.total : 0
        // the ring, as big as the card lets it be between the name and the controls
        readonly property real ringD: Math.max(Theme.dp(150), Math.min(card.width - Theme.dp(56), card.height - Theme.dp(178)))

        radius: Theme.shapeXl
        color: Theme.withBlur(card.done ? Theme.errorContainer : Theme.bgTile)

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

        // the name, which a click turns into a field
        Item {
            x: Theme.dp(22)
            y: Theme.dp(16)
            width: parent.width - Theme.dp(44) - closeBtn.width
            height: Theme.dp(36)

            TextInput {
                id: nameInput

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                clip: true
                color: card.done ? Theme.fgErrorContainer : Theme.text
                selectionColor: Theme.alpha(Theme.primary, 0.35)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeSize("titleMedium")
                font.weight: 600
                text: card.t.label || ""
                onAccepted: nameInput.focus = false
                onActiveFocusChanged: {
                    if (!activeFocus && nameInput.text.trim() !== (card.t.label || ""))
                        page.app.send("timer.rename", {
                        "id": card.t.id,
                        "name": nameInput.text.trim()
                    });

                }
                Keys.onEscapePressed: {
                    nameInput.text = card.t.label || "";
                    nameInput.focus = false;
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: nameInput.contentWidth
                height: 1
                color: Theme.primary
                visible: nameInput.activeFocus
            }

        }

        IconButton {
            id: closeBtn

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(10)
            y: Theme.dp(12)
            icon: "close"
            tooltip: "Remove"
            onClicked: page.app.send("timer.remove", {
                "id": card.t.id
            })
        }

        Item {
            id: ringBox

            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.dp(62) + Math.max(0, (card.height - Theme.dp(62) - Theme.dp(100) - card.ringD) / 2)
            width: card.ringD
            height: card.ringD

            CircularProgress {
                anchors.fill: parent
                thickness: Math.max(Theme.dp(10), Math.round(card.ringD * 0.045))
                value: card.done ? 1 : card.frac
                color: card.done ? Theme.error : (card.paused ? Theme.subtext : Theme.primary)
                trackColor: card.done ? Theme.alpha(Theme.error, 0.25) : Theme.secondaryContainer
                wavy: card.t.running === true
            }

            Column {
                anchors.centerIn: parent
                spacing: 0

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: Math.round(card.ringD * (card.done ? 0.14 : (card.rem >= 3600000 ? 0.16 : 0.22)))
                    weight: 500
                    rounded: 100
                    tabular: true
                    color: card.done ? Theme.fgErrorContainer : Theme.text
                    text: card.done ? "Time's up" : CM.countdown(card.rem)

                    SequentialAnimation on opacity {
                        running: card.done && page.shown
                        loops: Animation.Infinite
                        alwaysRunToEnd: true

                        NumberAnimation {
                            to: 0.45
                            duration: 600
                        }

                        NumberAnimation {
                            to: 1
                            duration: 600
                        }

                    }

                }

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: card.ringD > Theme.dp(300) ? "titleMedium" : "bodyMedium"
                    color: card.done ? Theme.fgErrorContainer : Theme.subtext
                    text: card.done ? CM.clock(Math.max(0, page.nowMs - card.t.endsAt), false) + " ago" : (card.paused ? "Paused · " : "") + "of " + CM.countdown(card.t.total)
                }

            }

        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(22)
            spacing: Theme.dp(12)

            Button {
                anchors.verticalCenter: parent.verticalCenter
                visible: !card.done
                variant: "tonal"
                text: "+1:00"
                onClicked: page.app.send("timer.extend", {
                    "id": card.t.id,
                    "sec": 60
                })
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(84)
                height: Theme.dp(56)
                radius: card.t.running ? Theme.dp(18) : height / 2
                color: card.done ? Theme.error : Theme.primary

                Icon {
                    anchors.centerIn: parent
                    name: card.done ? "replay" : (card.t.running ? "pause" : "play_arrow")
                    size: Theme.dp(28)
                    fill: 1
                    color: card.done ? Theme.fgError : Theme.fgPrimary
                }

                StateLayer {
                    radius: parent.radius
                    tint: Theme.fgPrimary
                    onClicked: page.app.send(card.done ? "timer.restart" : "timer.toggle", {
                        "id": card.t.id
                    })
                }

                Behavior on radius {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                    }

                }

            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: !card.done
                variant: "tonal"
                icon: "replay"
                tooltip: "Reset"
                disabled: card.t.running || card.t.left === card.t.total
                onClicked: page.app.send("timer.reset", {
                    "id": card.t.id
                })
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                visible: card.done
                variant: "tonal"
                text: "Done"
                onClicked: page.app.send("timer.remove", {
                    "id": card.t.id
                })
            }

        }

    }

}
