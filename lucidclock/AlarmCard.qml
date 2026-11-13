import QtQuick
import qs
import qs.lucidlumen
import qs.lucidui
import "ClockMath.js" as CM

// one alarm, a row of a grouped list: the time, what it is for and when, and
// its switch. opened up (raised a step), the days it keeps, its name, its
// sound, skipping the next one, and away
GroupRow {
    id: card

    property var app: null
    property var win: null
    property var alarm: null
    property bool expanded: false
    // the page's clock, a beat a few seconds long, for the words that drift
    property int tick: 0
    readonly property var a: card.alarm || ({
        "id": "",
        "hour": 0,
        "minute": 0,
        "label": "",
        "days": [],
        "on": false,
        "sound": ""
    })
    readonly property bool on: card.a.on === true
    readonly property bool once: !card.a.days || card.a.days.length === 0
    readonly property real snoozedTo: card.app && card.app.snoozed[card.a.id] ? card.app.snoozed[card.a.id] : 0
    readonly property bool ringingNow: card.app ? card.app.ringing.some((r) => {
        return r.id === card.a.id;
    }) : false
    readonly property real nextAt: {
        card.tick;
        return card.app ? card.app.alarmNext(card.a) : 0;
    }
    readonly property string when: {
        card.tick;
        if (!card.once)
            return CM.daysText(card.a.days, card.app ? card.app.mondayFirst : true);

        if (!card.on || !card.nextAt)
            return "Not scheduled";

        return CM.dayWord(card.nextAt, card.app.nowMs());
    }
    // the one thing worth saying in a chip: ringing, snoozed, a skip
    readonly property string status: {
        card.tick;
        if (card.ringingNow)
            return "Ringing";

        if (card.snoozedTo > 0)
            return "Snoozed until " + CM.time(new Date(card.snoozedTo).getHours(), new Date(card.snoozedTo).getMinutes(), card.app.h24);

        if (card.on && card.a.skip && card.a.skip > card.app.nowMs()) {
            const w = CM.dayWord(card.a.skip, card.app.nowMs());
            return "Skipping " + (w === "Today" || w === "Tomorrow" ? w.toLowerCase() : w);
        }
        return "";
    }

    signal expandRequested()
    signal removeRequested()

    function send(op, args) {
        card.app.send(op, Object.assign({
            "id": card.a.id
        }, args || {
        }));
    }

    function setDays(days) {
        card.send("alarm.update", {
            "fields": {
                "days": days
            }
        });
    }

    function toggleDay(d) {
        const days = (card.a.days || []).slice();
        const i = days.indexOf(d);
        if (i >= 0)
            days.splice(i, 1);
        else
            days.push(d);
        card.setDays(days);
    }

    function commitLabel() {
        const t = labelField.text.trim();
        if (t !== card.a.label)
            card.send("alarm.update", {
            "fields": {
                "label": t
            }
        });

    }

    function soundMenu(anchor) {
        const sounds = card.app.alarmState.sounds || [];
        const mine = card.a.sound || "";
        const items = [{
            "heading": "Rings with"
        }, {
            "id": "",
            "label": "Default (" + card.app.soundLabel(card.app.alarmState.sound) + ")",
            "radio": true,
            "checked": mine === ""
        }, {
            "sep": true
        }];
        for (const s of sounds) items.push({
            "id": s.key,
            "label": s.label,
            "icon": "music_note",
            "radio": true,
            "checked": mine === s.key
        })
        const p = anchor.mapToItem(card.win.contentItem, 0, anchor.height + Theme.dp(4));
        card.win.openMenu(items, p.x, p.y, (id) => {
            card.send("alarm.update", {
                "fields": {
                    "sound": id
                }
            });
            card.app.send("alarm.preview", {
                "sound": id === "" ? card.app.alarmState.sound : id
            });
        });
    }

    width: parent ? parent.width : Theme.dp(600)
    height: col.implicitHeight + Theme.dp(30)
    raised: card.expanded

    // a click anywhere the controls are not opens or closes it
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: card.expandRequested()
    }

    Column {
        id: col

        x: Theme.dp(24)
        y: Theme.dp(15)
        width: parent.width - Theme.dp(44)
        spacing: Theme.dp(2)

        Item {
            width: parent.width
            height: timeRow.height

            Row {
                id: timeRow

                spacing: Theme.dp(6)

                LText {
                    id: big

                    size: Theme.fs(42)
                    weight: card.on ? 460 : 380
                    rounded: 60
                    tabular: true
                    color: card.on ? Theme.text : Theme.subtext
                    text: CM.hourText(card.a.hour, card.app ? card.app.h24 : false) + ":" + CM.pad(card.a.minute)

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

                LText {
                    visible: card.app && !card.app.h24
                    anchors.baseline: big.baseline
                    role: "titleMedium"
                    weight: 560
                    color: card.on ? Theme.text : Theme.subtext
                    text: card.a.hour < 12 ? "AM" : "PM"
                }

            }

            // the time itself sets a new one
            MouseArea {
                width: timeRow.width
                height: timeRow.height
                cursorShape: Qt.PointingHandCursor
                onClicked: card.win.pickTime(card.a.hour, card.a.minute, "Change alarm", (h, m) => {
                    card.send("alarm.update", {
                        "fields": {
                            "hour": h,
                            "minute": m,
                            "on": true
                        }
                    });
                })
            }

            Switch {
                objectName: "alarmSwitch"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: card.on
                onToggled: (v) => {
                    card.send("alarm.on", {
                        "on": v
                    });
                }
            }

        }

        Item {
            width: parent.width
            height: Math.max(Theme.dp(32), sub.implicitHeight)

            Row {
                id: sub

                anchors.left: parent.left
                anchors.right: chevron.left
                anchors.rightMargin: Theme.dp(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(8)

                LText {
                    visible: card.a.label !== ""
                    width: Math.min(implicitWidth, sub.width * 0.55)
                    anchors.verticalCenter: parent.verticalCenter
                    role: "bodyLarge"
                    weight: 600
                    color: card.on ? Theme.text : Theme.subtext
                    elide: Text.ElideRight
                    text: card.a.label
                }

                LText {
                    visible: card.a.label !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    role: "bodyLarge"
                    color: Theme.subtextDim
                    text: "·"
                }

                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "bodyLarge"
                    color: Theme.subtext
                    text: card.when
                }

                Rectangle {
                    visible: card.status !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: statusText.implicitWidth + Theme.dp(16)
                    height: Theme.dp(24)
                    radius: height / 2
                    color: card.ringingNow ? Theme.errorContainer : Theme.tertiaryContainer

                    LText {
                        id: statusText

                        anchors.centerIn: parent
                        role: "labelMedium"
                        color: card.ringingNow ? Theme.fgErrorContainer : Theme.fgTertiaryContainer
                        text: card.status
                    }

                }

            }

            IconButton {
                id: chevron

                anchors.right: parent.right
                anchors.rightMargin: Theme.dp(6)
                anchors.verticalCenter: parent.verticalCenter
                size: "xs"
                icon: "expand_more"
                rotation: card.expanded ? 180 : 0
                tooltip: card.expanded ? "Fewer options" : "More options"
                onClicked: card.expandRequested()

                Behavior on rotation {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveFastSpatial
                    }

                }

            }

        }

        // ---- opened up
        Item {
            id: more

            width: parent.width
            height: card.expanded ? moreCol.implicitHeight + Theme.dp(10) : 0
            clip: true
            visible: height > 0

            Column {
                id: moreCol

                y: Theme.dp(10)
                width: parent.width
                spacing: Theme.dp(14)

                // the week, a disc a day
                Row {
                    spacing: Theme.dp(8)

                    Repeater {
                        model: CM.weekOrder(card.app ? card.app.mondayFirst : true)

                        Rectangle {
                            required property int modelData
                            readonly property bool picked: (card.a.days || []).indexOf(modelData) >= 0

                            width: Theme.dp(40)
                            height: Theme.dp(40)
                            radius: width / 2
                            color: picked ? Theme.accent : Theme.withBlur(Theme.bgTile)
                            border.width: picked ? 0 : 1
                            border.color: Theme.alpha(Theme.text, 0.12)

                            LText {
                                anchors.centerIn: parent
                                role: "labelLarge"
                                weight: 650
                                color: parent.picked ? Theme.fgAccent : Theme.subtext
                                text: CM.dayName(parent.modelData, "ddd").charAt(0)
                            }

                            StateLayer {
                                radius: parent.radius
                                tint: parent.picked ? Theme.fgAccent : Theme.text
                                onClicked: card.toggleDay(parent.modelData)
                            }

                            Tip {
                                text: CM.dayName(parent.modelData, "dddd")
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durShort
                                }

                            }

                        }

                    }

                }

                // shortcuts to the usual weeks
                Flow {
                    width: parent.width
                    spacing: Theme.dp(8)

                    Chip {
                        kind: "filter"
                        text: "Once"
                        selected: card.once
                        onClicked: card.setDays([])
                    }

                    Chip {
                        kind: "filter"
                        text: "Weekdays"
                        selected: CM.sameDays(card.a.days, CM.WEEKDAYS)
                        onClicked: card.setDays(CM.WEEKDAYS)
                    }

                    Chip {
                        kind: "filter"
                        text: "Weekends"
                        selected: CM.sameDays(card.a.days, CM.WEEKEND)
                        onClicked: card.setDays(CM.WEEKEND)
                    }

                    Chip {
                        kind: "filter"
                        text: "Every day"
                        selected: CM.sameDays(card.a.days, CM.EVERY_DAY)
                        onClicked: card.setDays(CM.EVERY_DAY)
                    }

                }

                TextField {
                    id: labelField

                    width: Math.min(parent.width, Theme.dp(420))
                    label: "Name"
                    placeholder: "Wake up, gym, the bus…"
                    icon: "label"
                    containerColor: Theme.withBlur(Theme.bgTile)
                    text: card.a.label
                    onAccepted: {
                        card.commitLabel();
                        labelField.input.focus = false;
                    }
                    onEscaped: {
                        labelField.text = card.a.label;
                        labelField.input.focus = false;
                    }

                    Connections {
                        function onActiveFocusChanged() {
                            if (!labelField.input.activeFocus)
                                card.commitLabel();

                        }

                        target: labelField.input
                    }

                }

                Item {
                    width: parent.width
                    height: Theme.dp(40)

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.dp(8)

                        Chip {
                            id: soundChip

                            kind: "assist"
                            icon: "music_note"
                            text: card.app ? card.app.soundLabel(card.a.sound || card.app.alarmState.sound) : ""
                            onClicked: card.soundMenu(soundChip)
                        }

                        Chip {
                            visible: !card.once && card.on
                            kind: "filter"
                            icon: card.a.skip ? "" : "skip_next"
                            text: "Skip next"
                            selected: !!card.a.skip && card.a.skip > card.app.nowMs()
                            onClicked: card.send("alarm.skip", {
                                "yes": !selected
                            })
                        }

                    }

                    Button {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        variant: "text"
                        icon: "delete"
                        text: "Delete"
                        onClicked: card.removeRequested()
                    }

                }

            }

            Behavior on height {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

            }

        }

    }

}
