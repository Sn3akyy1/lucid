import QtQuick
import qs
import qs.lucidui

// lucidui's MonthView for the clock app, which runs apart from the shell: the
// same month (today on lucid's pentagon, the picked day in a tonal circle, a
// dot for a reminder), but today, the week's start and the marks are handed in
Item {
    id: month

    property int year: new Date().getFullYear()
    property int monthIndex: new Date().getMonth()
    // { year, month, day } or null
    property var selected: null
    property var today: new Date()
    property bool mondayFirst: true
    // a day with something on: (y, m, d) => bool; rev changes when that does
    property var marked: function(y, m, d) {
        return false;
    }
    property int rev: 0
    property int cell: Theme.dp(44)
    // the day's number grows with the cell, so a big month is not a sparse one
    readonly property int daySize: Math.max(Theme.fs(13), Math.round(month.cell * 0.31))
    property real slideX: 0
    readonly property bool isCurrent: month.year === month.today.getFullYear() && month.monthIndex === month.today.getMonth()
    readonly property var weekdays: {
        const out = [];
        for (let i = 0; i < 7; i++) out.push(new Date(2023, 0, (month.mondayFirst ? 2 : 1) + i).toLocaleDateString(Qt.locale(), "ddd").charAt(0))
        return out;
    }
    readonly property var cells: {
        month.rev;
        const t = month.today;
        const lead = (new Date(month.year, month.monthIndex, 1).getDay() + (month.mondayFirst ? 6 : 0)) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(month.year, month.monthIndex, 1 - lead + i);
            out.push({
                "year": d.getFullYear(),
                "month": d.getMonth(),
                "day": d.getDate(),
                "other": d.getMonth() !== month.monthIndex,
                "today": d.getFullYear() === t.getFullYear() && d.getMonth() === t.getMonth() && d.getDate() === t.getDate(),
                "marked": month.marked(d.getFullYear(), d.getMonth(), d.getDate())
            });
        }
        return out;
    }

    signal picked(int y, int m, int d)

    function page(dir) {
        let m = month.monthIndex + dir;
        let y = month.year;
        if (m < 0) {
            m = 11;
            y -= 1;
        } else if (m > 11) {
            m = 0;
            y += 1;
        }
        month.year = y;
        month.monthIndex = m;
        slideIn.from = dir * 42;
        slideIn.restart();
    }

    function show(y, m) {
        const dir = (y * 12 + m) >= (month.year * 12 + month.monthIndex) ? 1 : -1;
        if (y === month.year && m === month.monthIndex)
            return ;

        month.year = y;
        month.monthIndex = m;
        slideIn.from = dir * 42;
        slideIn.restart();
    }

    function goToday() {
        month.show(month.today.getFullYear(), month.today.getMonth());
    }

    implicitWidth: month.cell * 7
    implicitHeight: Theme.dp(44) + Theme.dp(26) + month.cell * 6

    NumberAnimation {
        id: slideIn

        target: month
        property: "slideX"
        to: 0
        duration: Theme.durDefaultSpatial
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.curveDefaultSpatial
    }

    // the wheel turns the months
    WheelHandler {
        property real acc: 0

        onWheel: (e) => {
            acc += e.angleDelta.y;
            if (Math.abs(acc) >= 120) {
                month.page(acc > 0 ? -1 : 1);
                acc = 0;
            }
        }
    }

    Item {
        id: head

        width: parent.width
        height: Theme.dp(44)

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(6)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(6)

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "titleLarge"
                weight: 600
                color: Theme.primary
                text: new Date(month.year, month.monthIndex, 1).toLocaleDateString(Qt.locale(), "MMMM")
            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "titleLarge"
                weight: 420
                color: Theme.subtext
                text: month.year
            }

        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            IconButton {
                visible: !month.isCurrent
                icon: "today"
                size: "xs"
                tooltip: "This month"
                onClicked: month.goToday()
            }

            IconButton {
                icon: "chevron_left"
                size: "xs"
                tooltip: "Last month"
                onClicked: month.page(-1)
            }

            IconButton {
                icon: "chevron_right"
                size: "xs"
                tooltip: "Next month"
                onClicked: month.page(1)
            }

        }

    }

    Item {
        anchors.top: head.bottom
        width: parent.width
        height: Theme.dp(26) + month.cell * 6
        clip: true

        Item {
            x: month.slideX
            width: parent.width
            height: parent.height
            opacity: 1 - Math.abs(month.slideX) / 60

            Row {
                id: weekRow

                width: parent.width
                height: Theme.dp(26)

                Repeater {
                    model: month.weekdays

                    LText {
                        required property var modelData
                        required property int index

                        width: month.cell
                        horizontalAlignment: Text.AlignHCenter
                        role: "labelMedium"
                        color: (month.mondayFirst ? index >= 5 : (index === 0 || index === 6)) ? Theme.primary : Theme.subtext
                        text: modelData
                    }

                }

            }

            Grid {
                anchors.top: weekRow.bottom
                columns: 7

                Repeater {
                    model: month.cells

                    Item {
                        id: c

                        required property var modelData
                        readonly property bool isSelected: month.selected !== null && month.selected.year === c.modelData.year && month.selected.month === c.modelData.month && month.selected.day === c.modelData.day

                        width: month.cell
                        height: month.cell

                        Rectangle {
                            anchors.centerIn: parent
                            width: month.cell - Theme.dp(4)
                            height: month.cell - Theme.dp(4)
                            radius: width / 2
                            color: c.isSelected && !c.modelData.today ? Theme.secondaryContainer : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durFastEffects
                                }

                            }

                        }

                        Loader {
                            anchors.centerIn: parent
                            active: c.modelData.today

                            sourceComponent: MaterialShape {
                                width: month.cell
                                height: month.cell
                                shape: "pentagon"
                                color: Theme.primary
                                scale: c.isSelected ? 1.06 : 0.92
                                rotation: c.isSelected ? -12 : 0

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.durFastSpatial
                                        easing.type: Easing.Bezier
                                        easing.bezierCurve: Theme.curveFastSpatial
                                    }

                                }

                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: Theme.durDefaultSpatial
                                        easing.type: Easing.Bezier
                                        easing.bezierCurve: Theme.curveDefaultSpatial
                                    }

                                }

                            }

                        }

                        StateLayer {
                            anchors.fill: undefined
                            anchors.centerIn: parent
                            width: month.cell - Theme.dp(4)
                            height: month.cell - Theme.dp(4)
                            radius: width / 2
                            hoverOpacity: c.modelData.today ? 0 : Theme.stateHover
                            pressOpacity: c.modelData.today ? 0 : Theme.statePressed
                            ripple: !c.modelData.today
                            onClicked: month.picked(c.modelData.year, c.modelData.month, c.modelData.day)
                        }

                        TextMetrics {
                            id: dayCap

                            font: dayText.font
                            text: "7"
                        }

                        FontMetrics {
                            id: dayFm

                            font: dayText.font
                        }

                        LText {
                            id: dayText

                            anchors.horizontalCenter: parent.horizontalCenter
                            // centre the cap-height box, not the line box
                            y: (c.height - dayCap.tightBoundingRect.height) / 2 - dayCap.tightBoundingRect.y - dayFm.ascent
                            role: "bodyLarge"
                            size: month.daySize
                            weight: c.modelData.today || c.isSelected ? 650 : 440
                            rounded: c.modelData.today ? 100 : 0
                            color: c.modelData.today ? Theme.fgPrimary : (c.isSelected ? Theme.fgSecondaryContainer : Theme.text)
                            opacity: c.modelData.other && !c.modelData.today ? 0.35 : 1
                            text: c.modelData.day
                        }

                        Rectangle {
                            visible: c.modelData.marked
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.dp(5)
                            width: Theme.dp(5)
                            height: Theme.dp(5)
                            radius: width / 2
                            color: c.modelData.today ? Theme.fgPrimary : Theme.tertiary
                        }

                    }

                }

            }

        }

    }

}
