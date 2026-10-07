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
    // the hour is freshTime's next-hour guess, not one anybody chose
    property bool hourGuessed: false
    property string newRepeat: ""
    readonly property bool pm: page.newHour >= 12
    readonly property int shownHour: Prefs.clock24h ? page.newHour : (page.newHour % 12 === 0 ? 12 : page.newHour % 12)
    // a one-off set before now would never ring
    readonly property bool past: {
        Agenda.minuteKey;
        return page.newRepeat === "" && page.gone(page.newHour, page.newMinute);
    }
    readonly property bool shown: page.visible && (!page.host || page.host.expanded)

    onShownChanged: if (page.shown)
        page.freshTime()

    function selectToday() {
        const n = Loc.now();
        page.selected = { "year": n.getFullYear(), "month": n.getMonth(), "day": n.getDate() };
        month.goToday();
        page.freshTime();
    }

    // earlier than the minute we are in, on the picked day
    function gone(hour, minute) {
        const n = Loc.now();
        return new Date(page.selected.year, page.selected.month, page.selected.day, hour, minute) < new Date(n.getFullYear(), n.getMonth(), n.getDate(), n.getHours(), n.getMinutes());
    }

    // 9:00, or the next hour once 9:00 has gone today; a time already set for a name stays
    function freshTime() {
        if (nameField.text !== "")
            return ;

        page.newHour = 9;
        page.newMinute = 0;
        page.hourGuessed = false;
        const next = Loc.now().getHours() + 1;
        if (page.gone(9, 0) && next < 24 && !page.gone(next, 0)) {
            page.newHour = next;
            page.hourGuessed = true;
        }
    }

    // a typed 12-hour time means the half still to come: 12:04 at noon is pm
    function preferUpcoming() {
        if (Prefs.clock24h || !page.past)
            return ;

        const flipped = (page.newHour + 12) % 24;
        if (!page.gone(flipped, page.newMinute))
            page.newHour = flipped;

    }

    function focusName() {
        nameField.input.forceActiveFocus();
    }

    function submit() {
        const name = nameField.text.trim();
        if (name === "" || page.past)
            return ;

        Agenda.add(page.selected.year, page.selected.month, page.selected.day, page.newHour, page.newMinute, name, page.newRepeat);
        nameField.text = "";
        page.newRepeat = "";
    }

    function step(minutes) {
        page.hourGuessed = false;
        let t = (page.newHour * 60 + page.newMinute + minutes + 1440) % 1440;
        page.newHour = Math.floor(t / 60);
        page.newMinute = t % 60;
    }

    // typed hours are 0-23, or 1-12 next to the am/pm toggle
    function typeHour(h) {
        page.hourGuessed = false;
        if (Prefs.clock24h)
            page.newHour = Math.min(23, h);
        else
            page.newHour = Math.min(12, h) % 12 + (page.pm ? 12 : 0);
        page.preferUpcoming();
    }

    // minutes typed under the guessed hour mean the next time the clock shows
    // them: at 12:19, 20 is 12:20 rather than 1:20
    function typeMinute(m) {
        page.newMinute = Math.min(59, m);
        const today = page.gone(0, 0) && !page.gone(23, 59);
        if (page.hourGuessed && today) {
            const h = Loc.now().getHours();
            if (!page.gone(h, page.newMinute))
                page.newHour = h;
            else if (h + 1 < 24)
                page.newHour = h + 1;
        }
        page.preferUpcoming();
    }

    function setPm(wantPm) {
        page.hourGuessed = false;
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

        width: Theme.dp(30)
        height: Theme.dp(30)
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
            width: parent.width - Theme.dp(6)
            height: Theme.dp(2)
            radius: 1
            color: digit.typing ? Theme.primary : Theme.alpha(Theme.subtext, 0.4)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durFastEffects
                }

            }

        }

    }

    implicitHeight: Theme.dp(404)

    Rectangle {
        id: monthCard

        width: Theme.dp(312)
        height: parent.height
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.surfaceHigh)

        MonthView {
            id: month

            anchors.centerIn: parent
            cell: Theme.dp(40)
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
        anchors.leftMargin: Theme.dp(12)
        anchors.right: parent.right
        height: parent.height
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.surfaceHigh)

        Item {
            anchors.fill: parent
            anchors.margins: Theme.dp(18)

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
                anchors.topMargin: Theme.dp(12)
                anchors.bottom: form.top
                anchors.bottomMargin: Theme.dp(12)
                width: parent.width
                contentHeight: items.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: items

                    width: list.width
                    spacing: Theme.dp(2)

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
                    y: Theme.dp(24)
                    spacing: Theme.dp(8)

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "event_available"
                        size: Theme.dp(32)
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
                spacing: Theme.dp(10)

                TextField {
                    id: nameField

                    width: parent.width
                    label: "New reminder"
                    placeholder: "What should it say?"
                    supporting: page.past && nameField.text.trim() !== "" ? (page.gone(0, 0) && !page.gone(23, 59) ? Agenda.timeText({ "hour": page.newHour, "minute": page.newMinute }) + " has already gone by today" : "That day has already gone by") : ""
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
                    spacing: Theme.dp(8)

                    Rectangle {
                        id: timeBox

                        width: timeRow.implicitWidth + Theme.dp(20)
                        height: Theme.dp(36)
                        radius: Theme.dp(18)
                        color: Theme.withBlur(Theme.surfaceHighest)

                        Row {
                            id: timeRow

                            anchors.centerIn: parent
                            spacing: Theme.dp(2)

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
                                width: Theme.dp(32)
                                height: Theme.dp(30)

                                LText {
                                    anchors.centerIn: parent
                                    role: "labelMedium"
                                    weight: 640
                                    color: Theme.primary
                                    text: page.pm ? "PM" : "AM"
                                }

                                StateLayer {
                                    radius: Theme.rad(8)
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
                        width: parent.width - timeBox.width - addBtn.width - Theme.dp(16)
                        height: 1
                    }

                    Button {
                        id: addBtn

                        variant: "filled"
                        size: "xs"
                        icon: "add"
                        text: "Add"
                        disabled: nameField.text.trim() === "" || page.past
                        onClicked: page.submit()
                    }

                }

            }

        }

    }

}
