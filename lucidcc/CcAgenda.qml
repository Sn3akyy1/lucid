import QtQuick
import qs
import qs.lucidui

// what comes next: a timer or the pomodoro while one runs, then the
// reminders set in the clock, soonest first. its looks: a few in a list
// (list); the very next one, large (next). a tap opens the clock's today
// page, where reminders are added
Item {
    id: ac

    // list or next
    property string look: "list"

    signal opened()

    readonly property bool single: ac.look === "next"
    readonly property int most: ac.single ? 1 : 3
    // a running timer, the pomodoro or the stopwatch, as the bar shows it
    readonly property var running: Chrono.headline
    readonly property var rows: {
        Agenda.tick;
        Agenda.minuteKey;
        const out = [];
        const h = ac.running;
        if (h)
            out.push({
            "icon": h.kind === "stopwatch" ? "timer" : (h.kind === "pomodoro" ? "schedule" : "hourglass_top"),
            "name": h.label || (h.kind === "stopwatch" ? "Stopwatch" : "Timer"),
            "when": h.kind === "stopwatch" ? Chrono.clock(h.left, false) : Chrono.countdown(h.left),
            "sub": h.running ? (h.kind === "stopwatch" ? "running" : "left") : "paused",
            "live": true
        });
        for (const u of Agenda.upcoming(ac.most)) {
            if (out.length >= ac.most)
                break;

            out.push({
                "icon": "alarm",
                "name": u.item.name || "Reminder",
                "when": Agenda.timeText(u.item),
                "sub": Agenda.untilText(u.at),
                "live": false
            });
        }
        return out;
    }
    readonly property real rowH: ac.single ? Theme.dp(56) : Theme.dp(40)
    readonly property real head: Theme.dp(24)

    implicitHeight: ac.head + Math.max(1, ac.rows.length) * ac.rowH + Math.max(0, ac.rows.length - 1) * Theme.dp(4)

    StateLayer {
        anchors.fill: parent
        anchors.margins: -Theme.dp(6)
        radius: Theme.shapeLg
        onClicked: ac.opened()
    }

    LText {
        role: "labelLarge"
        color: Theme.subtext
        text: "Up next"
    }

    Column {
        y: ac.head
        width: parent.width
        spacing: Theme.dp(4)

        Repeater {
            model: ac.rows

            Item {
                id: row

                required property var modelData

                width: parent.width
                height: ac.rowH

                Rectangle {
                    id: badge

                    anchors.verticalCenter: parent.verticalCenter
                    width: ac.single ? Theme.dp(44) : Theme.dp(32)
                    height: width
                    radius: row.modelData.live ? Theme.shapeMd : width / 2
                    color: row.modelData.live ? Theme.withBlur(Theme.tertiaryContainer) : Theme.withBlur(Theme.secondaryContainer)

                    Icon {
                        anchors.centerIn: parent
                        name: row.modelData.icon
                        size: ac.single ? Theme.dp(22) : Theme.dp(18)
                        fill: 1
                        color: row.modelData.live ? Theme.fgTertiaryContainer : Theme.fgSecondaryContainer
                    }

                }

                Column {
                    x: badge.width + Theme.dp(12)
                    width: Math.max(0, whenText.x - x - Theme.dp(8))
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: -Theme.dp(1)

                    LText {
                        width: parent.width
                        role: ac.single ? "titleMedium" : "labelLarge"
                        weight: ac.single ? 600 : 500
                        elide: Text.ElideRight
                        text: row.modelData.name
                    }

                    LText {
                        width: parent.width
                        role: "bodySmall"
                        color: Theme.subtext
                        elide: Text.ElideRight
                        text: row.modelData.sub
                    }

                }

                LText {
                    id: whenText

                    x: parent.width - width
                    anchors.verticalCenter: parent.verticalCenter
                    role: ac.single ? "titleLarge" : "titleSmall"
                    weight: 620
                    rounded: 100
                    tabular: true
                    color: row.modelData.live ? Theme.tertiary : Theme.text
                    text: row.modelData.when
                }

            }

        }

        // nothing set: says where reminders come from
        Item {
            visible: ac.rows.length === 0
            width: parent.width
            height: ac.rowH

            Rectangle {
                id: emptyBadge

                anchors.verticalCenter: parent.verticalCenter
                width: ac.single ? Theme.dp(44) : Theme.dp(32)
                height: width
                radius: width / 2
                color: Theme.alpha(Theme.text, 0.08)

                Icon {
                    anchors.centerIn: parent
                    name: "event_available"
                    size: ac.single ? Theme.dp(22) : Theme.dp(18)
                    color: Theme.subtext
                }

            }

            Column {
                x: emptyBadge.width + Theme.dp(12)
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                spacing: -Theme.dp(1)

                LText {
                    width: parent.width
                    role: "labelLarge"
                    elide: Text.ElideRight
                    text: "Nothing coming up"
                }

                LText {
                    width: parent.width
                    role: "bodySmall"
                    color: Theme.subtext
                    elide: Text.ElideRight
                    text: "Reminders set in the clock show here"
                }

            }

        }

    }

}
