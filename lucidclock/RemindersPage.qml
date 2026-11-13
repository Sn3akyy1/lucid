import QtQuick
import qs
import qs.lucidlumen
import qs.lucidui
import "ClockMath.js" as CM

// reminders, which the bar's clock rings for: a big month with a dot on each
// day that has one, and beside it the picked day's and the coming week's as
// grouped lists. the bar's calendar only shows them; they are made here
Item {
    id: page

    property var app: null
    property var win: null
    property bool shown: false
    property real nowMs: Date.now()
    readonly property var today: new Date(page.nowMs + (page.app ? page.app.shift : 0))
    property var selected: ({
        "year": new Date().getFullYear(),
        "month": new Date().getMonth(),
        "day": new Date().getDate()
    })
    readonly property var items: page.app ? page.app.reminders : []
    readonly property var dayItems: CM.forDay(page.items, page.selected.year, page.selected.month, page.selected.day)
    readonly property var coming: {
        const week = new Date(page.today.getFullYear(), page.today.getMonth(), page.today.getDate() + 7);
        return CM.reminderUpcoming(page.items, page.today, 12).filter((u) => {
            return u.at < week;
        });
    }
    readonly property bool wide: page.width >= Theme.dp(900)
    readonly property int edge: Theme.dp(32)
    readonly property real bodyH: page.height - head.height - Theme.dp(24)
    readonly property real calZoneW: page.wide ? Math.min(page.width * 0.5, Theme.dp(640)) : page.width - page.edge * 2
    // the month as big as the room it has, within reason
    readonly property int cell: Math.round(Math.max(Theme.dp(40), Math.min(Theme.dp(76), (page.calZoneW - Theme.dp(40)) / 7, page.wide ? (page.bodyH - Theme.dp(110)) / 6.5 : Theme.dp(52))))
    readonly property string primaryIcon: "add"
    readonly property string primaryLabel: "New reminder"

    function primaryAction() {
        page.win.editReminder(null, page.selected);
    }

    function handleKey(e) {
        if (e.key === Qt.Key_N && !(e.modifiers & Qt.ControlModifier)) {
            page.primaryAction();
            return true;
        }
        if (e.key === Qt.Key_T && !(e.modifiers & Qt.ControlModifier)) {
            page.pickDay(page.today.getFullYear(), page.today.getMonth(), page.today.getDate());
            return true;
        }
        return false;
    }

    function pickDay(y, m, d) {
        page.selected = {
            "year": y,
            "month": m,
            "day": d
        };
        grid.show(y, m);
    }

    function remove(r) {
        const copy = Object.assign({
        }, r);
        page.app.send("rem.remove", {
            "id": r.id
        });
        page.win.toast("Reminder deleted", "Undo", {
            "undo": () => {
                return page.app.send("rem.add", copy);
            }
        });
    }

    function dayTitle() {
        const d = new Date(page.selected.year, page.selected.month, page.selected.day);
        const w = CM.dayWord(d.getTime(), page.today.getTime());
        return w === "Today" || w === "Tomorrow" ? w : d.toLocaleDateString(Qt.locale(), "dddd");
    }

    Timer {
        interval: 30000
        repeat: true
        running: page.shown
        triggeredOnStart: true
        onTriggered: page.nowMs = Date.now()
    }

    PageHead {
        id: head

        x: page.edge
        width: parent.width - page.edge * 2
        title: "Reminders"
        subtitle: page.coming.length === 0 ? "Nothing coming up this week" : page.coming.length + " coming up this week"
    }

    // ---- the month
    Rectangle {
        id: calCard

        x: page.edge
        y: head.height
        width: page.wide ? grid.implicitWidth + Theme.dp(40) : page.width - page.edge * 2
        height: grid.implicitHeight + Theme.dp(34)
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.bgTile)

        MonthGrid {
            id: grid

            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.dp(16)
            cell: page.cell
            today: page.today
            mondayFirst: page.app ? page.app.mondayFirst : true
            selected: page.selected
            rev: page.items.length + (page.app && page.app.st ? page.app.st.rev : 0)
            marked: (y, m, d) => {
                return CM.hasOn(page.items, y, m, d);
            }
            onPicked: (y, m, d) => {
                return page.pickDay(y, m, d);
            }
        }

    }

    // ---- the picked day, and the week ahead
    Scroller {
        id: scroller

        x: page.wide ? calCard.x + calCard.width + Theme.dp(28) : 0
        y: page.wide ? head.height : calCard.y + calCard.height + Theme.dp(18)
        width: page.wide ? page.width - x : page.width
        height: page.height - y
        contentHeight: listCol.implicitHeight + Theme.dp(28)

        Column {
            id: listCol

            x: page.wide ? 0 : page.edge
            width: scroller.width - page.edge - (page.wide ? 0 : page.edge)
            spacing: Theme.dp(3)

            Item {
                width: parent.width
                height: Theme.dp(60)

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    LText {
                        role: "headlineSmall"
                        text: page.dayTitle()
                    }

                    LText {
                        role: "bodyMedium"
                        color: Theme.subtext
                        text: new Date(page.selected.year, page.selected.month, page.selected.day).toLocaleDateString(Qt.locale(), "d MMMM yyyy") + (page.dayItems.length ? "  ·  " + page.dayItems.length + (page.dayItems.length === 1 ? " reminder" : " reminders") : "")
                    }

                }

                Button {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "tonal"
                    icon: "add"
                    text: "Add"
                    onClicked: page.primaryAction()
                }

            }

            Item {
                width: 1
                height: Theme.dp(6)
            }

            Repeater {
                model: page.dayItems

                GroupRow {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool ringing: page.app && page.app.remindersRinging.indexOf(row.modelData.id) >= 0

                    width: listCol.width
                    height: Theme.dp(76)
                    first: row.index === 0
                    last: row.index === page.dayItems.length - 1
                    color: Theme.withBlur(row.ringing ? Theme.tertiaryContainer : Theme.bgTile)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.win.editReminder(row.modelData, null)
                    }

                    Rectangle {
                        id: badge

                        x: Theme.dp(18)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(44)
                        height: Theme.dp(44)
                        radius: width / 2
                        color: Theme.secondaryContainer

                        Icon {
                            anchors.centerIn: parent
                            name: row.modelData.repeat ? "repeat" : "notifications"
                            size: Theme.dp(22)
                            fill: 1
                            color: Theme.fgSecondaryContainer
                        }

                    }

                    Column {
                        anchors.left: badge.right
                        anchors.leftMargin: Theme.dp(16)
                        anchors.right: tools.left
                        anchors.rightMargin: Theme.dp(10)
                        anchors.verticalCenter: parent.verticalCenter

                        LText {
                            width: parent.width
                            role: "titleMedium"
                            elide: Text.ElideRight
                            text: row.modelData.name
                        }

                        LText {
                            width: parent.width
                            role: "bodyMedium"
                            color: row.ringing ? Theme.fgTertiaryContainer : Theme.subtext
                            elide: Text.ElideRight
                            text: page.app.time(row.modelData.hour, row.modelData.minute) + (row.modelData.repeat ? "  ·  " + CM.repeatText(row.modelData) : "") + (row.ringing ? "  ·  ringing now" : "")
                        }

                    }

                    Row {
                        id: tools

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.dp(12)
                        anchors.verticalCenter: parent.verticalCenter

                        IconButton {
                            icon: "edit"
                            tooltip: "Change"
                            onClicked: page.win.editReminder(row.modelData, null)
                        }

                        IconButton {
                            icon: "delete"
                            tooltip: "Delete"
                            onClicked: page.remove(row.modelData)
                        }

                    }

                }

            }

            GroupRow {
                visible: page.dayItems.length === 0
                width: listCol.width
                height: Theme.dp(76)

                Row {
                    x: Theme.dp(18)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(16)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(44)
                        height: Theme.dp(44)
                        radius: width / 2
                        color: Theme.withBlur(Theme.bgHigh)

                        Icon {
                            anchors.centerIn: parent
                            name: "event_available"
                            size: Theme.dp(22)
                            color: Theme.subtext
                        }

                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        LText {
                            role: "titleMedium"
                            text: "A free day"
                        }

                        LText {
                            role: "bodyMedium"
                            color: Theme.subtext
                            text: "Nothing to be reminded of"
                        }

                    }

                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.primaryAction()
                }

            }

            LText {
                topPadding: Theme.dp(22)
                bottomPadding: Theme.dp(8)
                leftPadding: Theme.dp(4)
                role: "titleSmall"
                color: Theme.primary
                text: "Coming up"
            }

            Repeater {
                model: page.coming

                GroupRow {
                    id: up

                    required property var modelData
                    required property int index

                    width: listCol.width
                    height: Theme.dp(58)
                    first: up.index === 0
                    last: up.index === page.coming.length - 1

                    LText {
                        x: Theme.dp(22)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(170)
                        role: "labelLarge"
                        color: Theme.primary
                        text: CM.dayWord(up.modelData.at.getTime(), page.today.getTime()) + ", " + page.app.time(up.modelData.at.getHours(), up.modelData.at.getMinutes())
                    }

                    LText {
                        x: Theme.dp(200)
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - Theme.dp(44)
                        role: "bodyLarge"
                        elide: Text.ElideRight
                        text: up.modelData.item.name
                    }

                    Icon {
                        visible: !!up.modelData.item.repeat
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.dp(20)
                        anchors.verticalCenter: parent.verticalCenter
                        name: "repeat"
                        size: Theme.dp(16)
                        color: Theme.subtext
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.pickDay(up.modelData.at.getFullYear(), up.modelData.at.getMonth(), up.modelData.at.getDate())
                    }

                }

            }

            GroupRow {
                visible: page.coming.length === 0
                width: listCol.width
                height: Theme.dp(58)
                hoverable: false

                LText {
                    x: Theme.dp(22)
                    anchors.verticalCenter: parent.verticalCenter
                    role: "bodyMedium"
                    color: Theme.subtext
                    text: "Nothing in the next seven days"
                }

            }

        }

    }

}
