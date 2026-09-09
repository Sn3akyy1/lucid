import QtQuick
import qs

WidgetBody {
    id: w

    readonly property bool metric: w.opt("units") !== "imperial"
    readonly property string unitMark: "°"
    readonly property var report: (WeatherSource.report === null && w.preview) ? w.sample : WeatherSource.report
    // enough of a report to draw every variant in a gallery tile
    readonly property var sample: ({
        "code": 2,
        "tempC": 19,
        "tempF": 66,
        "feelsC": 18,
        "feelsF": 64,
        "humidity": 58,
        "windKmph": 11,
        "windMph": 7,
        "uv": 4,
        "sunrise": "",
        "sunset": "",
        "days": [{
            "date": "",
            "code": 2,
            "maxC": 21,
            "maxF": 70,
            "minC": 12,
            "minF": 54
        }, {
            "date": "",
            "code": 0,
            "maxC": 23,
            "maxF": 73,
            "minC": 13,
            "minF": 55
        }, {
            "date": "",
            "code": 61,
            "maxC": 18,
            "maxF": 64,
            "minC": 11,
            "minF": 52
        }]
    })
    readonly property var current: w.report
    readonly property var days: w.report ? w.report.days.slice(0, 4) : []
    readonly property string place: WeatherSource.place !== "" ? WeatherSource.place : "Here"
    readonly property bool ready: w.current !== null && w.current !== undefined
    readonly property string trouble: WeatherSource.lastError

    function temp(c, f) {
        return w.metric ? c : f;
    }

    function nowTemp() {
        return w.current ? w.temp(w.current.tempC, w.current.tempF) : 0;
    }

    function feels() {
        return w.current ? w.temp(w.current.feelsC, w.current.feelsF) : 0;
    }

    function describe() {
        return w.current ? WeatherSource.descFor(w.current.code) : "";
    }

    function iconFor(code) {
        const h = Loc.now().getHours();
        return WeatherSource.kindFor(code, h < 6 || h >= 20);
    }

    function dayIcon(d) {
        return d ? WeatherSource.kindFor(d.code, false) : "cloud";
    }

    function dayName(d, i) {
        if (!d || !d.date) {
            var fake = Loc.now();
            fake.setDate(fake.getDate() + i);
            return i === 0 ? "Today" : fake.toLocaleDateString(Qt.locale(), "ddd");
        }
        var parts = d.date.split("-");
        var dt = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
        var today = Loc.now();
        if (dt.getDate() === today.getDate() && dt.getMonth() === today.getMonth())
            return "Today";

        return dt.toLocaleDateString(Qt.locale(), "ddd");
    }

    function windText() {
        if (!w.current)
            return "";

        return w.metric ? w.current.windKmph + " km/h" : w.current.windMph + " mph";
    }

    Component.onCompleted: {
        if (!w.preview)
            WeatherSource.ensure();

    }

    // shown by every variant when there is nothing to draw yet
    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: !w.ready
        width: parent.width - 40

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: w.trouble !== "" ? "Weather unavailable" : "Fetching weather…"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.bold: true
        }

        Text {
            width: parent.width
            text: w.trouble
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: w.trouble !== ""
        }

        WidgetButton {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: "refresh"
            diameter: 30
            iconSize: 16
            visible: w.trouble !== ""
            onClicked: WeatherSource.refresh()
        }

    }

    Item {
        id: currentView

        visible: w.variant === "current" && w.ready
        anchors.fill: parent
        anchors.margins: 18

        WeatherIcon {
            id: bigIcon

            anchors.left: parent.left
            anchors.top: parent.top
            kind: w.current ? w.iconFor(w.current.code) : "cloud"
            size: 54
        }

        Row {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: -2
            spacing: 1

            Text {
                id: bigTemp

                text: w.nowTemp()
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 50
                font.bold: true
                font.letterSpacing: -2
            }

            Text {
                anchors.top: parent.top
                anchors.topMargin: 6
                text: w.unitMark
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.bold: true
            }

        }

        Text {
            id: desc

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: bigIcon.bottom
            anchors.topMargin: 8
            text: w.describe()
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: desc.bottom
            anchors.topMargin: 2
            text: w.place + " · feels like " + w.feels() + w.unitMark
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Row {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            spacing: 16

            Row {
                spacing: 5

                WidgetGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "drop"
                    size: 13
                    color: Theme.subtextDim
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: w.current ? w.current.humidity + "%" : ""
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

            }

            Row {
                spacing: 5

                WidgetGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "wind"
                    size: 13
                    color: Theme.subtextDim
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: w.windText()
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

            }

        }

    }

    Item {
        id: forecastView

        visible: w.variant === "forecast" && w.ready
        anchors.fill: parent
        anchors.margins: 18

        WeatherIcon {
            id: fIcon

            anchors.left: parent.left
            anchors.top: parent.top
            kind: w.current ? w.iconFor(w.current.code) : "cloud"
            size: 42
        }

        Column {
            anchors.left: fIcon.right
            anchors.leftMargin: 12
            anchors.right: fTemp.left
            anchors.rightMargin: 8
            anchors.verticalCenter: fIcon.verticalCenter
            spacing: 0

            Text {
                width: parent.width
                text: w.describe()
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: w.place
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }

        }

        Text {
            id: fTemp

            anchors.right: parent.right
            anchors.verticalCenter: fIcon.verticalCenter
            text: w.nowTemp() + w.unitMark
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 32
            font.bold: true
            font.letterSpacing: -1
        }

        Rectangle {
            id: fRule

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: fIcon.bottom
            anchors.topMargin: 14
            height: 1
            color: Theme.alpha(Theme.outline, 0.5)
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: fRule.bottom
            anchors.bottom: parent.bottom
            spacing: 0

            Repeater {
                model: w.days

                Column {
                    id: dayCell

                    required property var modelData
                    required property int index

                    width: w.days.length > 0 ? forecastView.width / w.days.length : 0
                    spacing: 4

                    Item {
                        width: parent.width
                        height: 6
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: w.dayName(dayCell.modelData, dayCell.index)
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 0.6
                    }

                    WeatherIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        kind: w.dayIcon(dayCell.modelData)
                        size: 30
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        Text {
                            text: w.temp(dayCell.modelData.maxC, dayCell.modelData.maxF) + "°"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            text: w.temp(dayCell.modelData.minC, dayCell.modelData.minF) + "°"
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }

                    }

                }

            }

        }

    }

    Row {
        id: compactView

        visible: w.variant === "compact" && w.ready
        anchors.centerIn: parent
        spacing: 10

        WeatherIcon {
            anchors.verticalCenter: parent.verticalCenter
            kind: w.current ? w.iconFor(w.current.code) : "cloud"
            size: 38
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2

            Text {
                text: w.nowTemp() + w.unitMark
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 30
                font.bold: true
                font.letterSpacing: -1
            }

            Text {
                text: w.describe()
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 11
                width: 96
                elide: Text.ElideRight
            }

        }

    }

}
