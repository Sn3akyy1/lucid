import QtQuick
import qs
import qs.lucidui

// the month on the left, the picked day's reminders and a way to add one on the right
Item {
    id: page

    property var host: null
    property var selected: {
        const n = Loc.now();
        return { "year": n.getFullYear(), "month": n.getMonth(), "day": n.getDate() };
    }
    readonly property date selectedDate: new Date(page.selected.year, page.selected.month, page.selected.day)
    readonly property var dayItems: {
        Agenda.tick;
        return Agenda.forDay(page.selected.year, page.selected.month, page.selected.day);
    }
    property int newHour: 9
    property int newMinute: 0
    property string newRepeat: ""

    function selectToday() {
        const n = Loc.now();
        page.selected = { "year": n.getFullYear(), "month": n.getMonth(), "day": n.getDate() };
        month.goToday();
    }

    function focusName() {
        nameField.input.forceActiveFocus();
    }

    function submit() {
        const name = nameField.text.trim();
        if (name === "")
            return ;

        Agenda.add(page.selected.year, page.selected.month, page.selected.day, page.newHour, page.newMinute, name, page.newRepeat);
        nameField.text = "";
        page.newRepeat = "";
    }

    function step(minutes) {
        let t = (page.newHour * 60 + page.newMinute + minutes + 1440) % 1440;
        page.newHour = Math.floor(t / 60);
        page.newMinute = t % 60;
    }

    implicitHeight: 404

    Rectangle {
        id: monthCard

        width: 312
        height: parent.height
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.surfaceHigh)

        MonthView {
            id: month

            anchors.centerIn: parent
            cell: 40
            selected: page.selected
            onPicked: (y, m, d) => {
                page.selected = { "year": y, "month": m, "day": d };
                if (m !== month.monthIndex)
                    month.page(y * 12 + m > month.year * 12 + month.monthIndex ? 1 : -1);

            }
        }

    }

    Rectangle {
        anchors.left: monthCard.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        height: parent.height
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.surfaceHigh)

        Item {
            anchors.fill: parent
            anchors.margins: 18

            Column {
                id: dayHead

                width: parent.width
                spacing: 0

                LText {
                    role: "titleLarge"
                    weight: 560
                    text: page.selectedDate.toLocaleDateString(Qt.locale(), "dddd")
                }

                LText {
                    role: "bodyMedium"
                    color: Theme.subtext
                    text: page.selectedDate.toLocaleDateString(Qt.locale(), "d MMMM yyyy") + (page.dayItems.length ? "  ·  " + page.dayItems.length + (page.dayItems.length === 1 ? " reminder" : " reminders") : "")
                }

            }

            Flickable {
                id: list

                anchors.top: dayHead.bottom
                anchors.topMargin: 12
                anchors.bottom: form.top
                anchors.bottomMargin: 12
                width: parent.width
                contentHeight: items.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: items

                    width: list.width
                    spacing: 2

                    Repeater {
                        model: page.dayItems

                        ListItem {
                            id: row

                            required property var modelData
                            required property int index

                            width: items.width
                            first: row.index === 0
                            last: row.index === page.dayItems.length - 1
                            containerColor: Theme.withBlur(Theme.surfaceHighest)
                            clickable: false
                            headline: row.modelData.name
                            supporting: Agenda.timeText(row.modelData) + (row.modelData.repeat ? "  ·  " + Agenda.repeatText(row.modelData) : "")
                            icon: row.modelData.repeat ? "repeat" : "notifications"
                            iconColor: Theme.primary
                            trailing: [
                                IconButton {
                                    icon: "delete"
                                    size: "xs"
                                    onClicked: Agenda.remove(row.modelData.id)
                                }
                            ]
                        }

                    }

                }

                Column {
                    visible: page.dayItems.length === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 24
                    spacing: 8

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "event_available"
                        size: 32
                        color: Theme.subtextDim
                    }

                    LText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        role: "bodyMedium"
                        color: Theme.subtext
                        text: "A free day"
                    }

                }

            }

            Column {
                id: form

                anchors.bottom: parent.bottom
                width: parent.width
                spacing: 10

                TextField {
                    id: nameField

                    width: parent.width
                    label: "New reminder"
                    placeholder: "What should it say?"
                    containerColor: Theme.withBlur(Theme.surfaceHighest)
                    onAccepted: page.submit()
                }

                ButtonGroup {
                    width: parent.width
                    size: "xs"
                    options: Agenda.repeatOptions
                    current: page.newRepeat
                    onPicked: (k) => {
                        return page.newRepeat = k;
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        id: timeBox

                        width: 150
                        height: 36
                        radius: 18
                        color: Theme.withBlur(Theme.surfaceHighest)

                        IconButton {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "remove"
                            size: "xs"
                            onClicked: page.step(-15)
                        }

                        LText {
                            anchors.centerIn: parent
                            role: "labelLarge"
                            weight: 640
                            tabular: true
                            text: Agenda.timeText({ "hour": page.newHour, "minute": page.newMinute })
                        }

                        IconButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "add"
                            size: "xs"
                            onClicked: page.step(15)
                        }

                        // the wheel moves a minute at a time
                        WheelHandler {
                            onWheel: (e) => {
                                return page.step(e.angleDelta.y > 0 ? 1 : -1);
                            }
                        }

                    }

                    Item {
                        width: parent.width - timeBox.width - addBtn.width - 16
                        height: 1
                    }

                    Button {
                        id: addBtn

                        variant: "filled"
                        size: "xs"
                        icon: "add"
                        text: "Add"
                        disabled: nameField.text.trim() === ""
                        onClicked: page.submit()
                    }

                }

            }

        }

    }

}
