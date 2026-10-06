import QtQuick
import "../lucidwidgets"
import qs
import qs.lucidui

// the clock app's first page: the time, the sky, and what is next
Item {
    id: page

    property var host: null
    property date now: Loc.now()
    readonly property var wx: WeatherSource.report
    readonly property bool night: page.wx ? !page.wx.isDay : (page.now.getHours() < 6 || page.now.getHours() >= 20)
    // every third hour of the next day
    readonly property var hours: {
        if (!page.wx || !page.wx.hours)
            return [];

        const out = [];
        for (let i = 0; i < page.wx.hours.length && out.length < 8; i += 3) out.push(page.wx.hours[i])
        return out;
    }

    signal addRequested()

    implicitHeight: Theme.dp(404)

    Timer {
        interval: 1000
        repeat: true
        running: page.visible
        triggeredOnStart: true
        onTriggered: page.now = Loc.now()
    }

    Rectangle {
        id: hero

        width: Theme.dp(250)
        height: Theme.dp(330)
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.primaryContainer)
        clip: true

        // a scalloped dial that turns with the seconds, the way pixel's clock does
        MaterialShape {
            anchors.centerIn: timeCol
            width: Theme.dp(210)
            height: Theme.dp(210)
            shape: "cookie12"
            color: Theme.alpha(Theme.fgPrimaryContainer, 0.08)
            rotation: page.now.getSeconds() * 6

            Behavior on rotation {
                RotationAnimation {
                    duration: Theme.durDefaultSpatial
                    direction: RotationAnimation.Clockwise
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }

            }

        }

        Column {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Theme.dp(22)
            spacing: 0

            LText {
                role: "titleMedium"
                weight: 600
                color: Theme.fgPrimaryContainer
                text: page.now.toLocaleDateString(Qt.locale(), "dddd")
            }

            LText {
                role: "bodyMedium"
                color: Theme.alpha(Theme.fgPrimaryContainer, 0.75)
                text: page.now.toLocaleDateString(Qt.locale(), "d MMMM")
            }

        }

        Column {
            id: timeCol

            anchors.centerIn: parent
            anchors.verticalCenterOffset: Theme.dp(2)
            spacing: -Theme.dp(16)

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                size: Theme.fs(74)
                weight: 620
                rounded: 100
                color: Theme.fgPrimaryContainer
                text: {
                    const h = page.now.getHours();
                    return Prefs.clock24h ? String(h).padStart(2, "0") : String(h % 12 === 0 ? 12 : h % 12);
                }
            }

            LText {
                id: minuteText

                anchors.horizontalCenter: parent.horizontalCenter
                size: Theme.fs(74)
                weight: 620
                rounded: 100
                color: Theme.primary
                text: String(page.now.getMinutes()).padStart(2, "0")

                // a third line under the stack, anchored so the column keeps its axis
                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: -Theme.dp(16)
                    size: Theme.fs(26)
                    weight: 620
                    rounded: 100
                    tabular: true
                    color: Theme.alpha(Theme.fgPrimaryContainer, 0.55)
                    text: String(page.now.getSeconds()).padStart(2, "0")
                }

            }

        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(20)
            spacing: Theme.dp(6)

            Rectangle {
                visible: !Prefs.clock24h
                anchors.verticalCenter: parent.verticalCenter
                width: ampm.implicitWidth + Theme.dp(16)
                height: Theme.dp(24)
                radius: Theme.dp(12)
                color: Theme.alpha(Theme.fgPrimaryContainer, 0.1)

                LText {
                    id: ampm

                    anchors.centerIn: parent
                    role: "labelMedium"
                    color: Theme.fgPrimaryContainer
                    text: page.now.getHours() < 12 ? "AM" : "PM"
                }

            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "labelMedium"
                color: Theme.alpha(Theme.fgPrimaryContainer, 0.75)
                text: Lockscreen.greeting + (Lockscreen.displayName !== "" ? ", " + Lockscreen.displayName.split(" ")[0] : "")
            }

        }

    }

    Rectangle {
        id: weather

        anchors.left: hero.right
        anchors.leftMargin: Theme.dp(12)
        anchors.right: parent.right
        height: hero.height
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.surfaceHigh)

        Column {
            visible: page.wx === null
            anchors.centerIn: parent
            spacing: Theme.dp(10)

            LoadingIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: WeatherSource.busy
            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "bodyMedium"
                color: Theme.subtext
                text: WeatherSource.lastError !== "" ? "Weather is unavailable — " + WeatherSource.lastError : "Fetching the forecast"
            }

        }

        Item {
            visible: page.wx !== null
            anchors.fill: parent
            anchors.margins: Theme.dp(20)

            Row {
                id: nowRow

                spacing: Theme.dp(14)

                Item {
                    width: Theme.dp(64)
                    height: Theme.dp(64)

                    MaterialShape {
                        anchors.fill: parent
                        shape: "sunny"
                        color: Theme.tertiaryContainer
                        rotation: 8
                    }

                    WeatherIcon {
                        anchors.centerIn: parent
                        size: Theme.dp(44)
                        kind: page.wx ? WeatherSource.kindFor(page.wx.code, page.night) : "clear"
                        tint: Theme.fgTertiaryContainer
                        cloudColor: Theme.fgTertiaryContainer
                    }

                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Row {
                        spacing: Theme.dp(2)

                        LText {
                            role: "displaySmall"
                            weight: 600
                            rounded: 100
                            text: page.wx ? page.wx.tempC + "°" : ""
                        }

                    }

                    LText {
                        role: "bodyMedium"
                        color: Theme.subtext
                        text: page.wx ? WeatherSource.descFor(page.wx.code) + (page.wx.days && page.wx.days.length ? "  ·  " + page.wx.days[0].maxC + "° / " + page.wx.days[0].minC + "°" : "") : ""
                    }

                }

            }

            LText {
                anchors.right: parent.right
                anchors.top: parent.top
                width: Math.min(implicitWidth, parent.width - nowRow.width - Theme.dp(20))
                horizontalAlignment: Text.AlignRight
                role: "labelMedium"
                color: Theme.subtext
                text: WeatherSource.place
                elide: Text.ElideRight
            }

            Flow {
                id: chips

                anchors.top: nowRow.bottom
                anchors.topMargin: Theme.dp(14)
                width: parent.width
                spacing: Theme.dp(6)

                Repeater {
                    model: page.wx ? [["thermostat", "Feels " + page.wx.feelsC + "°"], ["water_drop", page.wx.humidity + "%"], ["air", page.wx.windKmph + " km/h " + (page.wx.windDir || "")], ["umbrella", (page.wx.pop || 0) + "%"], ["light_mode", "UV " + page.wx.uv]] : []

                    Rectangle {
                        required property var modelData

                        width: chipRow.implicitWidth + Theme.dp(20)
                        height: Theme.dp(28)
                        radius: Theme.dp(14)
                        color: Theme.withBlur(Theme.surfaceHighest)

                        Row {
                            id: chipRow

                            anchors.centerIn: parent
                            spacing: Theme.dp(5)

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: modelData[0]
                                size: Theme.dp(15)
                                color: Theme.primary
                            }

                            LText {
                                anchors.verticalCenter: parent.verticalCenter
                                role: "labelMedium"
                                text: modelData[1]
                            }

                        }

                    }

                }

            }

            // the next day, three hours at a time
            Row {
                id: hourly

                anchors.top: chips.bottom
                anchors.topMargin: Theme.dp(14)
                width: parent.width

                Repeater {
                    model: page.hours

                    Column {
                        required property var modelData
                        required property int index

                        width: hourly.width / Math.max(1, page.hours.length)
                        spacing: Theme.dp(4)

                        LText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            role: "labelSmall"
                            color: index === 0 ? Theme.primary : Theme.subtext
                            text: index === 0 ? "Now" : new Date(modelData.time).toLocaleTimeString(Qt.locale(), Prefs.clock24h ? "HH" : "h AP").replace(":00", "")
                        }

                        WeatherIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: Theme.dp(26)
                            animate: false
                            kind: WeatherSource.kindFor(modelData.code, !modelData.day)
                            tint: Theme.primary
                            cloudColor: Theme.subtext
                        }

                        LText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            role: "labelLarge"
                            rounded: 100
                            text: modelData.tempC + "°"
                        }

                    }

                }

            }

            Rectangle {
                id: rule

                anchors.top: hourly.bottom
                anchors.topMargin: Theme.dp(12)
                width: parent.width
                height: 1
                color: Theme.divider
            }

            Row {
                id: daily

                anchors.top: rule.bottom
                anchors.topMargin: Theme.dp(10)
                width: parent.width

                Repeater {
                    model: page.wx && page.wx.days ? page.wx.days.slice(1, 6) : []

                    Row {
                        required property var modelData

                        width: daily.width / 5
                        spacing: Theme.dp(4)

                        Column {
                            spacing: 0

                            LText {
                                role: "labelMedium"
                                text: new Date(modelData.date + "T12:00").toLocaleDateString(Qt.locale(), "ddd")
                            }

                            LText {
                                role: "labelSmall"
                                color: Theme.subtext
                                text: modelData.maxC + "° " + modelData.minC + "°"
                            }

                        }

                        WeatherIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            size: Theme.dp(24)
                            animate: false
                            kind: WeatherSource.kindFor(modelData.code, false)
                            tint: Theme.primary
                            cloudColor: Theme.subtext
                        }

                    }

                }

            }

        }

    }

    Rectangle {
        id: next

        anchors.top: hero.bottom
        anchors.topMargin: Theme.dp(12)
        width: parent.width
        height: Theme.dp(62)
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.surfaceHigh)

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(12)

            Item {
                width: Theme.dp(38)
                height: Theme.dp(38)
                anchors.verticalCenter: parent.verticalCenter

                MaterialShape {
                    anchors.fill: parent
                    shape: "cookie9"
                    color: Agenda.next ? Theme.secondaryContainer : Theme.withBlur(Theme.surfaceHighest)
                }

                Icon {
                    anchors.centerIn: parent
                    name: Agenda.next ? "notifications_active" : "event_available"
                    size: Theme.dp(20)
                    fill: 1
                    color: Agenda.next ? Theme.fgSecondaryContainer : Theme.subtext
                }

            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                LText {
                    role: "titleSmall"
                    text: Agenda.next ? Agenda.next.item.name : "Nothing coming up"
                }

                LText {
                    role: "bodySmall"
                    color: Theme.subtext
                    text: Agenda.next ? Agenda.next.at.toLocaleDateString(Qt.locale(), "ddd d MMM") + " · " + Agenda.timeText(Agenda.next.item) + " · " + Agenda.untilText(Agenda.next.at) : "Reminders you add show up here"
                }

            }

        }

        Button {
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(12)
            anchors.verticalCenter: parent.verticalCenter
            variant: "tonal"
            icon: "add"
            text: "Reminder"
            onClicked: page.addRequested()
        }

    }

}
