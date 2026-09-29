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
        Agenda.checkedDay;
        return Agenda.forDay(page.selected.year, page.selected.month, page.selected.day);
    }
    property int newHour: 9
    property int newMinute: 0
    property string newRepeat: ""
    readonly property bool pm: page.newHour >= 12
    readonly property int shownHour: Prefs.clock24h ? page.newHour : (page.newHour % 12 === 0 ? 12 : page.newHour % 12)

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

    // typed hours are 0-23, or 1-12 next to the am/pm toggle
    function typeHour(h) {
        if (Prefs.clock24h)
            page.newHour = Math.min(23, h);
        else
            page.newHour = Math.min(12, h) % 12 + (page.pm ? 12 : 0);
    }

    function typeMinute(m) {
        page.newMinute = Math.min(59, m);
    }

    function setPm(wantPm) {
        page.newHour = page.newHour % 12 + (wantPm ? 12 : 0);
    }

    // two digits you type into, each holding its own value until focus leaves
    component TimeDigit: Item {
        id: digit

        property int value: 0
        property int span: 60
        property Item nextDigit: null
        readonly property bool typing: field.activeFocus

        signal typed(int v)
        signal meridiem(bool wantPm)
        signal accepted()

        function show() {
            field.text = String(digit.value).padStart(2, "0");
        }

        function take() {
            field.forceActiveFocus();
            field.selectAll();
        }

        function nudge(by) {
            digit.typed((digit.value + by + digit.span) % digit.span);
            digit.show();
        }

        width: 30
        height: 30
        onValueChanged: if (!field.activeFocus)
            digit.show()
        Component.onCompleted: digit.show()

        TextInput {
            id: field

            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            maximumLength: 2
            inputMethodHints: Qt.ImhDigitsOnly
            selectByMouse: true
            color: Theme.text
            selectionColor: Theme.alpha(Theme.primary, 0.35)
            selectedTextColor: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeSize("labelLarge")
            font.variableAxes: Theme.axes(Theme.typeSize("labelLarge"), 640, 0)
            font.features: ({
                "tnum": 1
            })
            onTextEdited: {
                if (field.text !== "")
                    digit.typed(parseInt(field.text, 10));

                if (field.text.length === 2 && digit.nextDigit)
                    digit.nextDigit.take();

            }
            onActiveFocusChanged: {
                if (field.activeFocus)
                    Qt.callLater(field.selectAll);
                else
                    digit.show();
            }
            onAccepted: digit.accepted()
            Keys.onUpPressed: digit.nudge(1)
            Keys.onDownPressed: digit.nudge(-1)
            Keys.onTabPressed: digit.nextDigit ? digit.nextDigit.take() : digit.show()
            Keys.onPressed: (e) => {
                const c = e.text.toLowerCase();
                if (c === "a" || c === "p")
                    digit.meridiem(c === "p");

            }

            validator: RegularExpressionValidator {
                regularExpression: /[0-9]{0,2}/
            }

        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 6
            height: 2
            radius: 1
            color: digit.typing ? Theme.primary : Theme.alpha(Theme.subtext, 0.4)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durFastEffects
                }

            }

        }

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

                        width: timeRow.implicitWidth + 20
                        height: 36
                        radius: 18
                        color: Theme.withBlur(Theme.surfaceHighest)

                        Row {
                            id: timeRow

                            anchors.centerIn: parent
                            spacing: 2

                            TimeDigit {
                                id: hourDigit

                                anchors.verticalCenter: parent.verticalCenter
                                value: page.shownHour
                                span: Prefs.clock24h ? 24 : 12
                                nextDigit: minuteDigit
                                onTyped: (v) => {
                                    return page.typeHour(v);
                                }
                                onMeridiem: (wantPm) => {
                                    return page.setPm(wantPm);
                                }
                                onAccepted: page.submit()
                            }

                            LText {
                                anchors.verticalCenter: parent.verticalCenter
                                role: "labelLarge"
                                weight: 640
                                color: Theme.subtext
                                text: ":"
                            }

                            TimeDigit {
                                id: minuteDigit

                                anchors.verticalCenter: parent.verticalCenter
                                value: page.newMinute
                                span: 60
                                onTyped: (v) => {
                                    return page.typeMinute(v);
                                }
                                onMeridiem: (wantPm) => {
                                    return page.setPm(wantPm);
                                }
                                onAccepted: page.submit()
                            }

                            Item {
                                visible: !Prefs.clock24h
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32
                                height: 30

                                LText {
                                    anchors.centerIn: parent
                                    role: "labelMedium"
                                    weight: 640
                                    color: Theme.primary
                                    text: page.pm ? "PM" : "AM"
                                }

                                StateLayer {
                                    radius: 8
                                    onClicked: page.setPm(!page.pm)
                                }

                            }

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
