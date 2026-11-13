import QtQuick
import qs
import qs.lucidlumen
import qs.lucidui

// how the clock rings and reads, as Lucid Settings lays a page out: sections of
// grouped rows. the time format and the week are the shell's own settings
Item {
    id: page

    property var app: null
    property var win: null
    property bool shown: false
    readonly property var al: page.app ? page.app.alarmState : ({})
    readonly property var sp: page.app ? page.app.shellPrefs : ({})
    readonly property int edge: Theme.dp(32)
    readonly property string primaryIcon: ""
    readonly property string primaryLabel: ""

    function setAlarm(key, value) {
        page.app.send("alarm.set", {
            "key": key,
            "value": value
        });
    }

    function setPref(key, value) {
        page.app.send("pref.set", {
            "key": key,
            "value": value
        });
    }

    PageHead {
        id: head

        x: page.edge
        width: parent.width - page.edge * 2
        title: "Settings"
        subtitle: "The time format and the week are shared with Lucid's settings"
    }

    Scroller {
        y: head.height
        width: page.width
        height: page.height - head.height
        contentHeight: col.implicitHeight + Theme.dp(32)

        Column {
            id: col

            x: Math.max(page.edge, (page.width - width) / 2)
            width: Math.min(page.width - page.edge * 2, Theme.dp(820))
            spacing: Theme.dp(3)

            Section {
                text: "Alarms"
            }

            SetRow {
                first: true
                title: "Sound"
                note: "Every alarm rings with this unless it has its own"
                stacked: true

                Flow {
                    width: col.width - Theme.dp(44)
                    spacing: Theme.dp(8)

                    Repeater {
                        model: page.al.sounds || []

                        Chip {
                            required property var modelData

                            kind: "filter"
                            text: modelData.label
                            selected: page.al.sound === modelData.key
                            onClicked: {
                                page.setAlarm("sound", modelData.key);
                                page.app.send("alarm.preview", {
                                    "sound": modelData.key
                                });
                            }
                        }

                    }

                }

            }

            SetRow {
                title: "Volume"
                note: "Alarms ring through do not disturb"
                stacked: true

                Row {
                    spacing: Theme.dp(8)

                    Slider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: col.width - Theme.dp(44) - previewBtn.width - Theme.dp(8)
                        from: 0
                        to: 1
                        value: page.al.volume === undefined ? 0.8 : page.al.volume
                        icon: "volume_up"
                        valueText: (v) => {
                            return Math.round(v * 100) + "%";
                        }
                        onReleased: (v) => {
                            page.setAlarm("volume", v);
                            page.app.send("alarm.preview", {
                                "sound": page.al.sound
                            });
                        }
                    }

                    IconButton {
                        id: previewBtn

                        anchors.verticalCenter: parent.verticalCenter
                        variant: "tonal"
                        icon: "play_arrow"
                        tooltip: "Hear it"
                        onClicked: page.app.send("alarm.preview", {
                            "sound": page.al.sound
                        })
                    }

                }

            }

            SetRow {
                title: "Swell in"
                note: "Start quiet and grow to full volume over a minute"

                Switch {
                    checked: page.al.gradual === true
                    onToggled: (v) => {
                        return page.setAlarm("gradual", v);
                    }
                }

            }

            SetRow {
                title: "Snooze for"
                stacked: true

                Flow {
                    width: col.width - Theme.dp(44)
                    spacing: Theme.dp(8)

                    Repeater {
                        model: [5, 10, 15, 20, 30]

                        Chip {
                            required property int modelData

                            kind: "filter"
                            text: modelData + " min"
                            selected: page.al.snoozeMinutes === modelData
                            onClicked: page.setAlarm("snoozeMinutes", modelData)
                        }

                    }

                }

            }

            SetRow {
                last: true
                title: "Stop ringing after"
                note: "An alarm nobody answers goes quiet and leaves a notification"
                stacked: true

                Flow {
                    width: col.width - Theme.dp(44)
                    spacing: Theme.dp(8)

                    Repeater {
                        model: [1, 5, 10, 15, 20, 30]

                        Chip {
                            required property int modelData

                            kind: "filter"
                            text: modelData + " min"
                            selected: page.al.silenceMinutes === modelData
                            onClicked: page.setAlarm("silenceMinutes", modelData)
                        }

                    }

                }

            }

            Section {
                text: "Timers and reminders"
            }

            SetRow {
                first: true
                title: "Sound when a timer ends"
                note: "And at the end of each focus session and break"

                Switch {
                    checked: page.sp.timerSound === true
                    onToggled: (v) => {
                        return page.setPref("timerSound", v);
                    }
                }

            }

            SetRow {
                last: true
                title: "Chime for reminders"
                note: "As a reminder comes due on the bar's clock"

                Switch {
                    checked: page.sp.reminderSound === true
                    onToggled: (v) => {
                        return page.setPref("reminderSound", v);
                    }
                }

            }

            Section {
                text: "Time"
            }

            SetRow {
                first: true
                title: "24-hour clock"
                note: "For the bar, the lock screen and the widgets too"

                Switch {
                    checked: page.sp.clock24h === true
                    onToggled: (v) => {
                        return page.setPref("clock24h", v);
                    }
                }

            }

            SetRow {
                last: true
                title: "Weeks start on Monday"

                Switch {
                    checked: page.sp.weekStartMonday !== false
                    onToggled: (v) => {
                        return page.setPref("weekStartMonday", v);
                    }
                }

            }

            Section {
                text: "About"
            }

            SetRow {
                first: true
                last: true
                title: "Clock keeps time in the shell"
                note: "Alarms, timers, the stopwatch and reminders all run in Lucid itself, so they ring with this window closed, and the bar's clock shows them too."
                stacked: true

                Grid {
                    columns: 2
                    columnSpacing: Theme.dp(20)
                    rowSpacing: Theme.dp(6)

                    Repeater {
                        model: ["Ctrl 1 – 7", "Go to a page", "N", "Something new on the page", "Space", "Start or pause", "L", "Lap", "Ctrl W", "Close the window"]

                        LText {
                            required property string modelData
                            required property int index

                            role: index % 2 === 0 ? "labelLarge" : "bodyMedium"
                            color: index % 2 === 0 ? Theme.text : Theme.subtext
                            text: modelData
                        }

                    }

                }

            }

        }

    }

    component Section: LText {
        topPadding: Theme.dp(18)
        bottomPadding: Theme.dp(8)
        leftPadding: Theme.dp(4)
        role: "titleSmall"
        color: Theme.primary
    }

    // a row's words on the left and its control on the right, or, stacked, the
    // control under the words, as SettingRow puts a wide one
    component SetRow: GroupRow {
        id: r

        property string title: ""
        property string note: ""
        property bool stacked: false
        default property alias control: slot.data

        width: col.width
        height: r.stacked ? words.implicitHeight + slot.childrenRect.height + Theme.dp(46) : Math.max(Theme.dp(64), words.implicitHeight + Theme.dp(32))
        first: false
        last: false
        hoverable: !r.stacked

        Column {
            id: words

            x: Theme.dp(22)
            y: r.stacked ? Theme.dp(16) : (r.height - height) / 2
            width: r.width - Theme.dp(44) - (r.stacked ? 0 : slot.width + Theme.dp(16))
            spacing: Theme.dp(2)

            LText {
                width: parent.width
                role: "bodyLarge"
                text: r.title
            }

            LText {
                visible: r.note !== ""
                width: parent.width
                wrapMode: Text.WordWrap
                role: "bodySmall"
                color: Theme.subtext
                text: r.note
            }

        }

        Item {
            id: slot

            x: r.stacked ? Theme.dp(22) : r.width - width - Theme.dp(20)
            y: r.stacked ? words.y + words.height + Theme.dp(14) : (r.height - height) / 2
            width: childrenRect.width
            height: childrenRect.height
        }

    }

}
