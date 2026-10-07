import QtQuick
import qs
import qs.lucidui

WidgetBody {
    id: w

    readonly property bool mondayFirst: Prefs.weekStartMonday
    property date now: Loc.now()
    readonly property var week: {
        Agenda.checkedDay;
        const lead = (w.now.getDay() + (w.mondayFirst ? 6 : 0)) % 7;
        const out = [];
        for (let i = 0; i < 7; i++) {
            const d = new Date(w.now.getFullYear(), w.now.getMonth(), w.now.getDate() - lead + i);
            out.push({
                "d": d,
                "today": i === lead,
                "marked": Agenda.hasOn(d.getFullYear(), d.getMonth(), d.getDate())
            });
        }
        return out;
    }
    readonly property var coming: {
        Agenda.minuteKey;
        return Agenda.upcoming(8);
    }
    readonly property int todayCount: {
        Agenda.checkedDay;
        return Agenda.forDay(w.now.getFullYear(), w.now.getMonth(), w.now.getDate()).length;
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: w.now = Loc.now()
    }

    // month: a date picker's grid, today in lucid's pentagon
    MonthView {
        visible: w.variant === "month"
        anchors.centerIn: parent
        cell: Math.floor((w.width - Theme.dp(28)) / 7)
        mondayFirst: w.mondayFirst
        showHeader: w.opt("showMonthName") !== false
        showNav: w.hovered
        ink: w.ink
        inkDim: w.inkDim
        accent: w.inkAccent
        fgAccent: w.fgInkAccent
        pickFill: Theme.alpha(w.ink, 0.1)
        pickInk: w.ink
        markColor: w.inkAccent
    }

    // week: seven days, today lifted into a pill
    Item {
        visible: w.variant === "week"
        anchors.fill: parent
        anchors.margins: Theme.dp(16)

        LText {
            role: "titleSmall"
            color: w.inkAccent
            text: w.now.toLocaleDateString(Qt.locale(), "MMMM yyyy")
        }

        Row {
            anchors.bottom: parent.bottom
            width: parent.width

            Repeater {
                model: w.week

                Item {
                    required property var modelData

                    width: parent.width / 7
                    height: Theme.dp(72)

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Theme.dp(2)
                        radius: width / 2
                        color: modelData.today ? w.inkAccent : "transparent"
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.dp(2)

                        LText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            role: "labelSmall"
                            color: modelData.today ? Theme.alpha(w.fgInkAccent, 0.8) : w.inkDim
                            text: modelData.d.toLocaleDateString(Qt.locale(), "ddd").slice(0, 2)
                        }

                        LText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            role: "titleLarge"
                            weight: modelData.today ? 680 : 500
                            rounded: 100
                            color: modelData.today ? w.fgInkAccent : w.ink
                            text: modelData.d.getDate()
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Theme.dp(5)
                            height: Theme.dp(5)
                            radius: 2.5
                            color: modelData.today ? w.fgInkAccent : w.inkAccent
                            opacity: modelData.marked ? 1 : 0
                        }

                    }

                }

            }

        }

    }

    // today: the date as a big number, and how full the day is
    Item {
        visible: w.variant === "today"
        anchors.fill: parent

        LText {
            x: Theme.dp(20)
            y: Theme.dp(16)
            role: "titleMedium"
            weight: 600
            color: w.inkAccent
            text: w.now.toLocaleDateString(Qt.locale(), "dddd")
        }

        LText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: Theme.dp(4)
            size: Theme.dp(96)
            weight: 620
            rounded: 100
            color: w.ink
            text: w.now.getDate()
        }

        Row {
            x: Theme.dp(20)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(16)
            spacing: Theme.dp(6)

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "labelLarge"
                color: w.inkDim
                text: w.now.toLocaleDateString(Qt.locale(), "MMMM")
            }

            Repeater {
                model: Math.min(3, w.todayCount)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(6)
                    height: Theme.dp(6)
                    radius: Theme.dp(3)
                    color: w.inkAccent
                }

            }

        }

    }

    // agenda: what is coming up
    Item {
        visible: w.variant === "agenda"
        anchors.fill: parent
        anchors.margins: Theme.dp(16)

        Row {
            id: agHead

            spacing: Theme.dp(8)

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "titleMedium"
                weight: 600
                color: w.inkAccent
                text: "Coming up"
            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "labelMedium"
                color: w.inkDim
                text: w.now.toLocaleDateString(Qt.locale(), "ddd d MMM")
            }

        }

        Column {
            id: agList

            // only as many rows as the card has room for
            readonly property var shown: w.coming.slice(0, Math.max(1, Math.floor((parent.height - agHead.height - 10 + 3) / 43)))

            anchors.top: agHead.bottom
            anchors.topMargin: Theme.dp(10)
            width: parent.width
            spacing: Theme.dp(3)

            Repeater {
                model: agList.shown

                Rectangle {
                    id: ev

                    required property var modelData
                    required property int index

                    width: parent.width
                    height: Theme.dp(40)
                    topLeftRadius: ev.index === 0 ? Theme.rad(16) : Theme.dp(5)
                    topRightRadius: ev.index === 0 ? Theme.rad(16) : Theme.dp(5)
                    bottomLeftRadius: ev.index === agList.shown.length - 1 ? Theme.rad(16) : Theme.dp(5)
                    bottomRightRadius: ev.index === agList.shown.length - 1 ? Theme.rad(16) : Theme.dp(5)
                    readonly property bool soon: ev.modelData.at - w.now < 6 * 86400000
                    color: Theme.alpha(w.ink, 0.07)

                    Column {
                        x: Theme.dp(12)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(44)
                        spacing: -Theme.dp(2)

                        LText {
                            role: "labelSmall"
                            color: w.inkAccent
                            text: ev.modelData.at.toLocaleDateString(Qt.locale(), ev.soon ? "ddd" : "MMM").toUpperCase()
                        }

                        LText {
                            role: "titleSmall"
                            weight: 660
                            rounded: 100
                            color: w.ink
                            text: ev.modelData.at.getDate()
                        }

                    }

                    LText {
                        x: Theme.dp(60)
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.dp(60) - timeTag.width - Theme.dp(20)
                        role: "bodyMedium"
                        weight: 520
                        color: w.ink
                        text: ev.modelData.item.name
                        elide: Text.ElideRight
                    }

                    LText {
                        id: timeTag

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.dp(12)
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelMedium"
                        color: w.inkDim
                        text: Agenda.timeText(ev.modelData.item)
                    }

                }

            }

            Column {
                visible: w.coming.length === 0
                width: parent.width
                topPadding: Theme.dp(18)
                spacing: Theme.dp(6)

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "event_available"
                    size: Theme.dp(30)
                    color: w.inkFaint
                }

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "bodyMedium"
                    color: w.inkDim
                    text: "Nothing coming up"
                }

            }

        }

    }

}
