import QtQuick
import QtQuick.Shapes
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
        "clock/panel/calendar": clockPanelCalendar,
        "media/playing": mediaPlaying,
        "media/cover": mediaCover,
        "media/compact": mediaCompact,
        "media/panel/side": mediaPanelSide,
        "media/panel/cover": mediaPanelCover,
        "workspaces/dots": workspacesDots,
        "workspaces/numbers": workspacesNumbers,
        "notifications/badge": notificationsBadge,
        "notifications/dot": notificationsDot,
        "notifications/chip": notificationsChip
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

    Component {
        id: mediaPlaying

        Row {
            spacing: 8

            MiniBars {
                anchors.verticalCenter: parent.verticalCenter
            }

            BarText {
                text: Prefs.mediaArtist ? "Artist  -  Song" : "Song"
            }

            MiniPlay {
                visible: Prefs.mediaPlayButton
                anchors.verticalCenter: parent.verticalCenter
            }

        }

    }

    Component {
        id: mediaCover

        Row {
            spacing: 8

            Rectangle {
                width: 22
                height: 22
                radius: 6
                color: Theme.accentContainer
                anchors.verticalCenter: parent.verticalCenter
            }

            BarText {
                text: Prefs.mediaArtist ? "Artist  -  Song" : "Song"
            }

            MiniPlay {
                visible: Prefs.mediaPlayButton
                anchors.verticalCenter: parent.verticalCenter
            }

        }

    }

    Component {
        id: mediaCompact

        Row {
            spacing: 8

            MiniBars {
                anchors.verticalCenter: parent.verticalCenter
            }

            MiniPlay {
                visible: Prefs.mediaPlayButton
                anchors.verticalCenter: parent.verticalCenter
            }

        }

    }

    Component {
        id: mediaPanelSide

        MiniPanel {
            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Rectangle {
                    width: 44
                    height: 44
                    radius: Theme.radiusSm
                    color: Theme.accentContainer
                }

                MiniLines {
                    width: parent.width - 52
                }

            }

            MiniTrack {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
            }

        }

    }

    Component {
        id: mediaPanelCover

        MiniPanel {
            height: 104

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Rectangle {
                    width: parent.width
                    height: 46
                    radius: Theme.radiusSm
                    color: Theme.accentContainer
                }

                MiniLines {
                    width: parent.width
                }

                MiniTrack {
                    width: parent.width
                }

            }

        }

    }

    Component {
        id: workspacesDots

        Row {
            spacing: 6

            Repeater {
                model: Math.min(Prefs.workspacesShown, 6)

                Rectangle {
                    required property int index

                    width: index === 0 ? 24 : 10
                    height: 10
                    radius: height / 2
                    color: index === 0 ? Theme.accent : Theme.withBlur(Theme._darken(Theme.subtext, 0.45))
                    anchors.verticalCenter: parent.verticalCenter
                }

            }

        }

    }

    Component {
        id: workspacesNumbers

        Row {
            spacing: 6

            Repeater {
                model: Math.min(Prefs.workspacesShown, 6)

                Rectangle {
                    required property int index

                    width: index === 0 ? 30 : 20
                    height: 20
                    radius: height / 2
                    color: index === 0 ? Theme.accent : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    BarText {
                        anchors.centerIn: parent
                        text: index + 1
                        font.pixelSize: Theme.fs(12)
                        color: index === 0 ? Theme.bgOpaque : Theme.subtext
                        opacity: index < 3 ? 1 : 0.5
                    }

                }

            }

        }

    }

    Component {
        id: notificationsBadge

        Row {
            spacing: 5

            MiniBell {
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: 16
                height: 16
                radius: height / 2
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter

                BarText {
                    anchors.centerIn: parent
                    text: "3"
                    color: Theme.fgAccent
                    font.pixelSize: Theme.fs(11)
                }

            }

        }

    }

    Component {
        id: notificationsDot

        MiniBell {
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -1
                width: 7
                height: 7
                radius: 3.5
                color: Theme.accent
                border.width: 1.5
                border.color: Theme.bg
            }

        }

    }

    Component {
        id: notificationsChip

        Rectangle {
            implicitWidth: chipRow.implicitWidth + 14
            implicitHeight: 24
            radius: height / 2
            color: Theme.accent

            Row {
                id: chipRow

                anchors.centerIn: parent
                spacing: 5

                MiniBell {
                    ink: Theme.fgAccent
                    anchors.verticalCenter: parent.verticalCenter
                }

                BarText {
                    text: "3"
                    color: Theme.fgAccent
                    font.pixelSize: Theme.fs(12)
                    anchors.verticalCenter: parent.verticalCenter
                }

            }

        }

    }

    // a bell: the notifications module's own glyph
    component MiniBell: Item {
        property color ink: Theme.text

        implicitWidth: 17
        implicitHeight: 17

        Shape {
            width: 24
            height: 24
            scale: 17 / 24
            anchors.centerIn: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: ink
                strokeWidth: 0

                PathSvg {
                    path: Notifs.icons.notifications
                }

            }

        }

    }

    // the media module's moving bars, standing still
    component MiniBars: Row {
        spacing: 2.5

        Repeater {
            model: [7, 14, 10]

            Rectangle {
                required property int modelData

                width: 2.5
                height: modelData
                radius: 1.25
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }

        }

    }

    // a play button: a triangle on the accent
    component MiniPlay: Rectangle {
        width: 22
        height: 22
        radius: height / 2
        color: Theme.accent

        Canvas {
            property color ink: Theme.fgAccent

            anchors.fill: parent
            onInkChanged: requestPaint()
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.fillStyle = ink;
                c.beginPath();
                c.moveTo(8.5, 6.5);
                c.lineTo(16, 11);
                c.lineTo(8.5, 15.5);
                c.closePath();
                c.fill();
            }
        }

    }

    // a title and a line under it
    component MiniLines: Column {
        spacing: 5

        Rectangle {
            width: parent.width * 0.8
            height: 7
            radius: 3.5
            color: Theme.text
            opacity: 0.8
        }

        Rectangle {
            width: parent.width * 0.5
            height: 6
            radius: 3
            color: Theme.subtextDim
        }

    }

    // a progress track, part played
    component MiniTrack: Rectangle {
        height: 4
        radius: 2
        color: Theme.bgHigh

        Rectangle {
            width: parent.width * 0.4
            height: parent.height
            radius: 2
            color: Theme.accent
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
