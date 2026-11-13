import QtQuick
import qs
import qs.lucidlumen
import qs.lucidui
import "ClockMath.js" as CM

// the alarms: the next one on a tonal card, its time on a dial (the bar
// clock's language), and every alarm as a row of one grouped list, in the
// order of the day
Item {
    id: page

    property var app: null
    property var win: null
    property bool shown: false
    property string expandedId: ""
    // a beat for the words that drift with the time: "in 3 h", "Tomorrow"
    property int tick: 0
    readonly property string primaryIcon: "add"
    readonly property string primaryLabel: "New alarm"
    readonly property var nextUp: {
        page.tick;
        return page.app ? page.app.nextAlarm() : null;
    }
    readonly property bool wide: page.width >= Theme.dp(900)
    readonly property int edge: Theme.dp(32)
    // the card's colours, as the bar clock's dial card has them
    readonly property color card: Theme.withBlur(Theme.primaryContainer)
    readonly property color face: Theme.atTone(Theme.primaryContainer, Theme.toneOf(Theme.primaryContainer) + (Theme.isLight ? -7 : 7))
    readonly property color ink: Theme.fgPrimaryContainer
    readonly property color dotInk: Theme.atTone(Theme.tertiary, Theme.isLight ? 58 : 78)

    function primaryAction() {
        const n = page.app.now();
        const h = (n.getHours() + 1) % 24;
        page.win.pickTime(h, 0, "New alarm", (hour, minute) => {
            page.app.send("alarm.add", {
                "hour": hour,
                "minute": minute
            }, (r) => {
                if (r.ok && r.data) {
                    page.expandedId = r.data;
                    page.say(hour, minute);
                }
            });
        });
    }

    function handleKey(e) {
        if (e.key === Qt.Key_N && !(e.modifiers & Qt.ControlModifier)) {
            page.primaryAction();
            return true;
        }
        return false;
    }

    // how long until it rings, said once, the way a phone does
    function say(hour, minute) {
        const at = CM.nextRing({
            "hour": hour,
            "minute": minute,
            "days": []
        }, page.app.nowMs());
        page.win.toast("Alarm set for " + CM.untilText(at - page.app.nowMs()).replace(/^in /, "") + " from now");
    }

    function byId(id) {
        return page.app ? (page.app.alarms.find((a) => {
            return a.id === id;
        }) || null) : null;
    }

    // keeps the list in step without rebuilding the rows, so an open one stays
    // open and a change animates
    function sync() {
        if (!page.app)
            return ;

        const want = page.app.alarms.slice().sort((x, y) => {
            return (x.hour * 60 + x.minute) - (y.hour * 60 + y.minute) || (x.label < y.label ? -1 : 1);
        }).map((a) => {
            return a.id;
        });
        for (let i = rows.count - 1; i >= 0; i--) {
            if (want.indexOf(rows.get(i).aid) < 0)
                rows.remove(i);

        }
        for (let i = 0; i < want.length; i++) {
            let at = -1;
            for (let j = i; j < rows.count; j++) {
                if (rows.get(j).aid === want[i]) {
                    at = j;
                    break;
                }
            }
            if (at < 0)
                rows.insert(i, {
                "aid": want[i]
            });
            else if (at !== i)
                rows.move(at, i, 1);
        }
    }

    function remove(a) {
        if (!a)
            return ;

        const copy = {
            "hour": a.hour,
            "minute": a.minute,
            "label": a.label,
            "days": a.days,
            "sound": a.sound,
            "on": a.on
        };
        page.app.send("alarm.remove", {
            "id": a.id
        });
        page.win.toast("Alarm deleted", "Undo", {
            "undo": () => {
                return page.app.send("alarm.add", copy);
            }
        });
    }

    function quick(minutes) {
        const at = new Date(page.app.nowMs() + minutes * 60000);
        page.app.send("alarm.add", {
            "hour": at.getHours(),
            "minute": at.getMinutes(),
            "label": minutes < 60 ? minutes + " min nap" : "Nap"
        });
        page.win.toast("Alarm set for " + CM.time(at.getHours(), at.getMinutes(), page.app.h24));
    }

    function napMenu(anchor) {
        const p = anchor.mapToItem(page.win.contentItem, 0, anchor.height + Theme.dp(4));
        page.win.openMenu([{
            "heading": "Ring once, in"
        }, {
            "id": 10,
            "label": "10 minutes"
        }, {
            "id": 20,
            "label": "20 minutes"
        }, {
            "id": 30,
            "label": "30 minutes"
        }, {
            "id": 60,
            "label": "An hour"
        }, {
            "id": 90,
            "label": "An hour and a half"
        }], p.x - Theme.dp(150), p.y, (id) => {
            return page.quick(id);
        });
    }

    Component.onCompleted: page.sync()
    onAppChanged: page.sync()

    Connections {
        function onAlarmsChanged() {
            page.sync();
        }

        target: page.app
    }

    Timer {
        interval: 5000
        repeat: true
        running: page.shown
        triggeredOnStart: true
        onTriggered: page.tick++
    }

    ListModel {
        id: rows
    }

    PageHead {
        id: head

        x: page.edge
        width: parent.width - page.edge * 2
        title: "Alarm"
        subtitle: {
            const n = page.app ? page.app.alarms.length : 0;
            const on = page.app ? page.app.alarms.filter((a) => {
                return a.on;
            }).length : 0;
            return n === 0 ? "Alarms ring with this window closed" : (on + " of " + n + " on");
        }

        IconButton {
            id: napBtn

            icon: "more_time"
            tooltip: "Quick alarm"
            onClicked: page.napMenu(napBtn)
        }

    }

    // ---- the next alarm
    Rectangle {
        id: hero

        x: page.edge
        y: head.height
        width: page.wide ? Theme.dp(330) : page.width - page.edge * 2
        height: page.wide ? page.height - head.height - Theme.dp(24) : Theme.dp(148)
        radius: Theme.shapeXl
        color: page.card

        AnalogClock {
            id: heroDial

            readonly property real d: page.wide ? Math.min(hero.width - Theme.dp(64), heroText.y - Theme.dp(84)) : hero.height - Theme.dp(32)

            // centred in the room between the label and the words at the foot
            x: page.wide ? (hero.width - width) / 2 : Theme.dp(16)
            y: page.wide ? Theme.dp(50) + Math.max(0, (heroText.y - Theme.dp(50) - height) / 2) : (hero.height - height) / 2
            width: Math.max(Theme.dp(80), heroDial.d)
            height: width
            // the next alarm's own time on the hands; with none, the time now
            time: page.nextUp ? new Date(page.nextUp.at) : page.app ? page.app.now() : new Date()
            seconds: false
            marks: true
            shape: "cookie12"
            dial: page.face
            ink: page.ink
            accent: Theme.atTone(Theme.primary, Theme.isLight ? 48 : 72)
        }

        LText {
            visible: page.wide
            x: Theme.dp(24)
            y: Theme.dp(20)
            role: "labelLarge"
            weight: 600
            color: Theme.alpha(page.ink, 0.75)
            text: page.nextUp ? "Next alarm" : "No alarm is on"
        }

        Column {
            id: heroText

            x: page.wide ? Theme.dp(24) : heroDial.x + heroDial.width + Theme.dp(20)
            y: page.wide ? hero.height - height - Theme.dp(26) : (hero.height - height) / 2
            width: page.wide ? hero.width - Theme.dp(48) : hero.width - x - Theme.dp(20)
            spacing: Theme.dp(2)

            LText {
                visible: !page.wide
                role: "labelLarge"
                weight: 600
                color: Theme.alpha(page.ink, 0.75)
                text: page.nextUp ? "Next alarm" : "No alarm is on"
            }

            Row {
                visible: page.nextUp !== null
                spacing: Theme.dp(6)

                LText {
                    id: heroTime

                    size: Theme.fs(page.wide ? 46 : 38)
                    weight: 560
                    rounded: 100
                    tabular: true
                    color: page.ink
                    text: page.nextUp ? CM.hourText(new Date(page.nextUp.at).getHours(), page.app.h24) + ":" + CM.pad(new Date(page.nextUp.at).getMinutes()) : ""
                }

                LText {
                    visible: page.app && !page.app.h24
                    anchors.baseline: heroTime.baseline
                    role: "titleMedium"
                    weight: 600
                    color: Theme.alpha(page.ink, 0.7)
                    text: page.nextUp && new Date(page.nextUp.at).getHours() < 12 ? "AM" : "PM"
                }

            }

            LText {
                visible: page.nextUp !== null
                width: parent.width
                role: "bodyLarge"
                color: Theme.alpha(page.ink, 0.85)
                elide: Text.ElideRight
                text: {
                    page.tick;
                    if (!page.nextUp)
                        return "";

                    const w = CM.dayWord(page.nextUp.at, page.app.nowMs());
                    return w + (page.nextUp.alarm.label !== "" ? "  ·  " + page.nextUp.alarm.label : "");
                }
            }

            LText {
                visible: page.nextUp !== null
                role: "titleSmall"
                weight: 650
                color: page.dotInk
                text: {
                    page.tick;
                    return page.nextUp ? CM.untilText(page.nextUp.at - page.app.nowMs()) : "";
                }
            }

            Button {
                visible: page.nextUp === null
                variant: "filled"
                icon: "add"
                text: "New alarm"
                onClicked: page.primaryAction()
            }

        }

    }

    // ---- every alarm
    Scroller {
        id: scroller

        x: page.wide ? hero.x + hero.width + Theme.dp(24) : 0
        y: page.wide ? head.height : hero.y + hero.height + Theme.dp(16)
        width: page.wide ? page.width - x : page.width
        height: page.height - y
        contentHeight: list.implicitHeight + Theme.dp(28)

        Column {
            id: list

            x: page.wide ? 0 : page.edge
            width: scroller.width - page.edge - (page.wide ? 0 : page.edge)
            spacing: Theme.dp(3)

            Repeater {
                model: rows

                delegate: AlarmCard {
                    id: card

                    required property string aid
                    required property int index

                    width: list.width
                    first: card.index === 0
                    last: card.index === rows.count - 1
                    app: page.app
                    win: page.win
                    alarm: page.byId(card.aid)
                    tick: page.tick
                    expanded: page.expandedId === card.aid
                    onExpandRequested: {
                        page.expandedId = card.expanded ? "" : card.aid;
                        if (!card.expanded)
                            revealLater.restart();

                    }
                    onRemoveRequested: page.remove(card.alarm)
                    Component.onCompleted: {
                        if (page.expandedId === card.aid)
                            revealLater.restart();

                    }

                    Timer {
                        id: revealLater

                        interval: Theme.durMedium + 40
                        onTriggered: scroller.reveal(card)
                    }

                }

            }

            move: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: Theme.durMedium
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

            }

        }

        // nothing set yet: say what goes here, where the list would be
        GroupRow {
            visible: page.app && page.app.alarms.length === 0
            x: list.x
            width: list.width
            height: Theme.dp(96)
            hoverable: false

            Row {
                x: Theme.dp(24)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(16)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "alarm"
                    size: Theme.dp(28)
                    color: Theme.subtext
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    LText {
                        role: "titleMedium"
                        text: "No alarms yet"
                    }

                    LText {
                        role: "bodyMedium"
                        color: Theme.subtext
                        text: "New alarm, up the side, or press N"
                    }

                }

            }

        }

    }

}
