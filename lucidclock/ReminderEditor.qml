import QtQuick
import qs
import qs.lucidui
import "ClockMath.js" as CM

// a reminder, new or changed, in a dialog over the window: what it says, the
// day, the time (on the dial) and how often. a one-off set in the past would
// never ring, so it is refused, as the bar's old form did
Item {
    id: ed

    property var app: null
    property var win: null
    property bool shown: false
    // the reminder being changed, or null for a new one
    property var item: null
    property int year: 2026
    property int month: 0
    property int day: 1
    property int hour: 9
    property int minute: 0
    property string repeat: ""
    property bool calendarOpen: false
    readonly property var when: new Date(ed.year, ed.month, ed.day, ed.hour, ed.minute)
    readonly property bool past: ed.repeat === "" && ed.when.getTime() < (ed.app ? ed.app.nowMs() : Date.now()) - 30000
    readonly property bool canSave: nameField.text.trim() !== "" && !ed.past

    function ask(item, day) {
        ed.item = item;
        const n = ed.app.now();
        if (item) {
            ed.year = item.year;
            ed.month = item.month;
            ed.day = item.day;
            ed.hour = item.hour;
            ed.minute = item.minute;
            ed.repeat = item.repeat || "";
            nameField.text = item.name;
        } else {
            const d = day || {
                "year": n.getFullYear(),
                "month": n.getMonth(),
                "day": n.getDate()
            };
            ed.year = d.year;
            ed.month = d.month;
            ed.day = d.day;
            ed.repeat = "";
            nameField.text = "";
            // nine, or on today once nine has gone, the next whole hour
            const today = d.year === n.getFullYear() && d.month === n.getMonth() && d.day === n.getDate();
            ed.hour = today && n.getHours() >= 9 ? Math.min(23, n.getHours() + 1) : 9;
            ed.minute = 0;
        }
        ed.calendarOpen = false;
        cal.show(ed.year, ed.month);
        ed.shown = true;
        nameField.input.forceActiveFocus();
    }

    function close() {
        ed.shown = false;
        nameField.input.focus = false;
    }

    function stepDay(by) {
        const d = new Date(ed.year, ed.month, ed.day + by);
        ed.year = d.getFullYear();
        ed.month = d.getMonth();
        ed.day = d.getDate();
    }

    function save() {
        if (!ed.canSave)
            return ;

        const f = {
            "year": ed.year,
            "month": ed.month,
            "day": ed.day,
            "hour": ed.hour,
            "minute": ed.minute,
            "name": nameField.text.trim(),
            "repeat": ed.repeat
        };
        if (ed.item)
            ed.app.send("rem.update", {
            "id": ed.item.id,
            "fields": f
        });
        else
            ed.app.send("rem.add", f);
        ed.win.toast(ed.item ? "Reminder changed" : "Reminder set for " + CM.dayWord(ed.when.getTime(), ed.app.nowMs()).replace("Today", "today").replace("Tomorrow", "tomorrow") + ", " + ed.app.time(ed.hour, ed.minute));
        ed.close();
    }

    visible: ed.shown || card.opacity > 0
    Keys.onEscapePressed: ed.close()

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: ed.shown ? 0.4 : 0

        MouseArea {
            anchors.fill: parent
            enabled: ed.shown
            onClicked: ed.close()
            onWheel: (w) => {
                return w.accepted = true;
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.dp(48), Theme.dp(460))
        height: body.implicitHeight + Theme.dp(48)
        radius: Theme.shapeXl
        color: Theme.surfaceHigh
        opacity: ed.shown ? 1 : 0
        scale: ed.shown ? 1 : 0.94

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: body

            x: Theme.dp(24)
            y: Theme.dp(24)
            width: parent.width - Theme.dp(48)
            spacing: Theme.dp(16)

            LText {
                role: "headlineSmall"
                text: ed.item ? "Change reminder" : "New reminder"
            }

            TextField {
                id: nameField

                width: parent.width
                label: "Reminder"
                placeholder: "What should it say?"
                supporting: ed.past ? (ed.when.toDateString() === ed.app.now().toDateString() ? ed.app.time(ed.hour, ed.minute) + " has already gone by today" : "That day has already gone by") : ""
                error: ed.past && nameField.text.trim() !== ""
                onAccepted: ed.save()
                onEscaped: ed.close()
            }

            // the day: a step either way, or the month to pick from
            Item {
                width: parent.width
                height: Theme.dp(48)

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(10)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "event"
                        size: Theme.dp(22)
                        color: Theme.subtext
                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "bodyLarge"
                        text: {
                            const w = ed.app ? CM.dayWord(new Date(ed.year, ed.month, ed.day).getTime(), ed.app.nowMs()) : "";
                            const full = new Date(ed.year, ed.month, ed.day).toLocaleDateString(Qt.locale(), "ddd d MMMM yyyy");
                            return w === "Today" || w === "Tomorrow" ? w + ", " + new Date(ed.year, ed.month, ed.day).toLocaleDateString(Qt.locale(), "d MMMM") : full;
                        }
                    }

                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    IconButton {
                        icon: "chevron_left"
                        size: "xs"
                        tooltip: "The day before"
                        onClicked: ed.stepDay(-1)
                    }

                    IconButton {
                        icon: "chevron_right"
                        size: "xs"
                        tooltip: "The day after"
                        onClicked: ed.stepDay(1)
                    }

                    IconButton {
                        icon: "calendar_month"
                        size: "xs"
                        checkable: true
                        checked: ed.calendarOpen
                        tooltip: "Pick on the calendar"
                        onClicked: ed.calendarOpen = !ed.calendarOpen
                    }

                }

            }

            Item {
                width: parent.width
                height: ed.calendarOpen ? cal.implicitHeight : 0
                clip: true
                visible: height > 0

                MonthGrid {
                    id: cal

                    anchors.horizontalCenter: parent.horizontalCenter
                    cell: Theme.dp(40)
                    today: ed.app ? ed.app.now() : new Date()
                    mondayFirst: ed.app ? ed.app.mondayFirst : true
                    selected: ({
                        "year": ed.year,
                        "month": ed.month,
                        "day": ed.day
                    })
                    onPicked: (y, m, d) => {
                        ed.year = y;
                        ed.month = m;
                        ed.day = d;
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

            // the time, set on the dial
            Item {
                width: parent.width
                height: Theme.dp(48)

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(10)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "schedule"
                        size: Theme.dp(22)
                        color: Theme.subtext
                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "bodyLarge"
                        text: ed.app ? ed.app.time(ed.hour, ed.minute) : ""
                    }

                }

                Button {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "tonal"
                    size: "s"
                    text: "Change time"
                    onClicked: ed.win.pickTime(ed.hour, ed.minute, "Reminder time", (h, m) => {
                        ed.hour = h;
                        ed.minute = m;
                    })
                }

            }

            ButtonGroup {
                width: parent.width
                size: "s"
                options: [{
                    "key": "",
                    "label": "Once"
                }, {
                    "key": "daily",
                    "label": "Daily"
                }, {
                    "key": "weekdays",
                    "label": "Weekdays"
                }, {
                    "key": "weekly",
                    "label": "Weekly"
                }]
                current: ed.repeat
                onPicked: (k) => {
                    return ed.repeat = k;
                }
            }

            Item {
                width: parent.width
                height: Theme.dp(44)

                Button {
                    visible: ed.item !== null
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "text"
                    icon: "delete"
                    text: "Delete"
                    onClicked: {
                        const r = ed.item;
                        ed.close();
                        ed.app.send("rem.remove", {
                            "id": r.id
                        });
                        ed.win.toast("Reminder deleted", "Undo", {
                            "undo": () => {
                                return ed.app.send("rem.add", r);
                            }
                        });
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(8)

                    Button {
                        variant: "text"
                        text: "Cancel"
                        onClicked: ed.close()
                    }

                    Button {
                        variant: "filled"
                        text: ed.item ? "Save" : "Add"
                        disabled: !ed.canSave
                        onClicked: ed.save()
                    }

                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

    }

}
