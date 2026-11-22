import QtQuick
import qs
import "parts"

// up next: the nearest reminder and the next alarm, so a glance at the lock
// says what the day still holds. a line, or a card with both
WidgetBase {
    id: up

    readonly property string style: up.opts.style || "line"
    readonly property bool boxed: up.style === "card" && !up.carded
    readonly property var reminder: Agenda.next
    // only a reminder within the week is worth a line on the lock
    readonly property bool hasReminder: !!up.reminder && Agenda.soon
    readonly property var alarm: Alarms.next
    readonly property bool hasAlarm: !!up.alarm
    readonly property var entries: {
        var out = [];
        if (up.hasReminder)
            out.push({
                "glyph": "event",
                "title": up.reminder.item.name || I18n.tr("Reminder"),
                "when": Agenda.timeText(up.reminder.item) + " · " + Agenda.untilText(up.reminder.at)
            });

        if (up.hasAlarm && (up.style === "card" || out.length === 0))
            out.push({
                "glyph": "alarm",
                "title": up.alarm.alarm.name || I18n.tr("Alarm"),
                "when": Alarms.timeText(up.alarm.alarm) + " · " + Agenda.untilText(new Date(up.alarm.at))
            });

        if (out.length === 0 && up.editing)
            out.push({
                "glyph": "event",
                "title": I18n.tr("Nothing coming up"),
                "when": I18n.tr("Reminders and alarms show here")
            });

        return out;
    }

    hasContent: up.entries.length > 0
    implicitWidth: box.width
    implicitHeight: box.height

    Rectangle {
        id: box

        readonly property real pad: up.boxed ? Theme.dp(18) : 0

        x: up.xFor(width, up.width)
        width: up.boxed || up.carded ? Math.min(up.avail, Theme.dp(380)) : Math.min(up.avail, list.implicitWidth)
        height: list.implicitHeight + box.pad * 2
        radius: Theme.shapeXl
        color: up.boxed ? (up.onCard ? Lockscreen.cardHigh : Lockscreen.card) : "transparent"

        Column {
            id: list

            x: box.pad
            y: box.pad
            width: box.width - box.pad * 2
            spacing: Theme.dp(12)

            Repeater {
                model: up.entries

                Row {
                    id: entry

                    required property var modelData

                    spacing: Theme.dp(12)
                    layoutDirection: up.align === Qt.AlignRight && !up.boxed ? Qt.RightToLeft : Qt.LeftToRight

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(36)
                        height: width
                        radius: Theme.shapeMd
                        color: up.tonal ? Theme.alpha(Theme.fgAccentContainer, 0.14) : Theme.accentContainer

                        Glyph {
                            anchors.centerIn: parent
                            name: entry.modelData.glyph
                            size: Theme.dp(19)
                            color: Theme.fgAccentContainer
                        }

                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.dp(1)

                        Text {
                            width: Math.min(implicitWidth, Math.max(Theme.dp(120), list.width - Theme.dp(48)))
                            elide: Text.ElideRight
                            text: entry.modelData.title
                            color: up.tonal ? Theme.fgAccentContainer : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTitleSm
                            font.variableAxes: Theme.axes(Theme.fontTitleSm, 540, 0)
                            font.weight: Font.Medium
                        }

                        Text {
                            text: entry.modelData.when
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelMd
                            font.variableAxes: Theme.axes(Theme.fontLabelMd, 450, 0)
                        }

                    }

                }

            }

        }

    }

}
