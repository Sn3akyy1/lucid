import QtQuick
import qs

// a small stand-in for a bar module in one of its styles, drawn with the
// bar's own fonts and colours, for the style tiles on the module's card.
// a module's samples are keyed "<id>/<style>", its panel's "<id>/panel/<style>"
Item {
    id: sample

    property string moduleId: ""
    property string styleKey: ""
    property bool panel: false

    readonly property string sampleKey: sample.moduleId + "/" + (sample.panel ? "panel/" : "") + sample.styleKey
    readonly property var samples: ({
        "clock/inline": clockInline,
        "clock/stacked": clockStacked,
        "clock/accent": clockAccent,
        "clock/panel/full": clockPanelFull,
        "clock/panel/calendar": clockPanelCalendar
    })
    // what the samples show: the time and date as the bar would
    readonly property string timeText: {
        const now = Loc.now();
        if (Prefs.clock24h)
            return now.toLocaleTimeString(Qt.locale(), Prefs.clockSeconds ? "HH:mm:ss" : "HH:mm");

        // h only counts to 12 next to AP; the bar leaves the AM/PM out
        const t = now.toLocaleTimeString(Qt.locale(), Prefs.clockSeconds ? "hh:mm:ss AP" : "hh:mm AP");
        return t.replace(now.toLocaleTimeString(Qt.locale(), "AP"), "").trim();
    }
    readonly property string dateText: Loc.now().toLocaleDateString(Qt.locale(), Prefs.clockDateFormat === "long" ? "ddd d MMM" : (Prefs.clockDateFormat === "numeric" ? Qt.locale().dateFormat(Locale.ShortFormat) : "ddd d"))

    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: loader.item ? loader.item.implicitHeight : 0

    Loader {
        id: loader

        anchors.centerIn: parent
        sourceComponent: sample.samples[sample.sampleKey] || fallback
    }

    Component {
        id: clockInline

        Row {
            spacing: 8

            BarText {
                text: sample.timeText
            }

            Rectangle {
                visible: Prefs.clockShowDate
                width: 3
                height: 3
                radius: 1.5
                color: Theme.subtextDim
                anchors.verticalCenter: parent.verticalCenter
            }

            BarText {
                visible: Prefs.clockShowDate
                text: sample.dateText
                color: Theme.subtextDim
            }

        }

    }

    Component {
        id: clockStacked

        Column {
            spacing: -2

            BarText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: sample.timeText
                font.pixelSize: Theme.fs(12)
            }

            BarText {
                visible: Prefs.clockShowDate
                anchors.horizontalCenter: parent.horizontalCenter
                text: sample.dateText
                color: Theme.subtextDim
                font.pixelSize: Theme.fs(10)
            }

        }

    }

    Component {
        id: clockAccent

        Row {
            spacing: 8

            Rectangle {
                width: accentTime.implicitWidth + 16
                height: 24
                radius: height / 2
                color: Theme.accent

                BarText {
                    id: accentTime

                    anchors.centerIn: parent
                    text: sample.timeText
                    color: Theme.fgAccent
                }

            }

            BarText {
                visible: Prefs.clockShowDate
                anchors.verticalCenter: parent.verticalCenter
                text: sample.dateText
                color: Theme.subtextDim
            }

        }

    }

    Component {
        id: clockPanelFull

        MiniPanel {
            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Column {
                    width: (parent.width - 6) * 0.42
                    spacing: 4

                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: Theme.radiusSm
                        color: Theme.accentContainer
                    }

                    Rectangle {
                        width: parent.width
                        height: 22
                        radius: Theme.radiusSm
                        color: Theme.bgHigh
                    }

                    Rectangle {
                        width: parent.width
                        height: 22
                        radius: Theme.radiusSm
                        color: Theme.bgHigh
                    }

                }

                MiniCalendar {
                    width: (parent.width - 6) * 0.58
                    height: parent.height
                }

            }

        }

    }

    Component {
        id: clockPanelCalendar

        MiniPanel {
            width: 96

            MiniCalendar {
                anchors.fill: parent
                anchors.margins: 8
            }

        }

    }

    // a panel, shrunk: the frame the panel samples are drawn in
    component MiniPanel: Rectangle {
        width: 150
        height: 90
        radius: Theme.radiusMd
        color: Theme.bg
    }

    // a month, as dots, today in the accent
    component MiniCalendar: Grid {
        columns: 7
        columnSpacing: (width - 7 * 7) / 6
        rowSpacing: (height - 5 * 7) / 4

        Repeater {
            model: 35

            Rectangle {
                required property int index

                width: 7
                height: 7
                radius: 2
                color: index === 17 ? Theme.accent : Theme.bgHigh
            }

        }

    }

    Component {
        id: fallback

        Text {
            text: sample.styleKey
            color: Theme.text
            font.family: Theme.fontFamily
            font.bold: true
            font.pixelSize: Theme.fs(13)
        }

    }

    // a bit of bar text, as the modules set it
    component BarText: Text {
        color: Theme.text
        font.family: Theme.fontFamily
        font.bold: true
        font.pixelSize: Theme.fs(13)
    }

}
