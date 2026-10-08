import QtQuick
import QtQuick.Shapes
import qs
import qs.lucidui
import "../lucidui/Shapes.js" as Shapes

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
        "media/disc": mediaDisc,
        "media/playing": mediaPlaying,
        "media/cover": mediaCover,
        "media/compact": mediaCompact,
        "media/panel/side": mediaPanelSide,
        "media/panel/cover": mediaPanelCover,
        "workspaces/dots": workspacesDots,
        "workspaces/numbers": workspacesNumbers,
        "notifications/badge": notificationsBadge,
        "notifications/dot": notificationsDot,
        "notifications/chip": notificationsChip,
        "system/values": systemValues,
        "system/icons": systemIcons,
        "tray/collapsed": trayCollapsed,
        "tray/icons": trayIcons,
        "privacy/marks": privacyMarks,
        "privacy/dot": privacyDot,
        "power/icon": powerIcon,
        "power/accent": powerAccent,
        "power/panel/list": powerPanelList,
        "power/panel/grid": powerPanelGrid,
        "window/plain": windowPlain,
        "window/chip": windowChip
    })
    // what the samples show: the time and date as the bar would
    readonly property string timeText: {
        const now = Loc.now();
        if (Prefs.clock24h)
            return now.toLocaleTimeString(Qt.locale(), "HH:mm");

        // h only counts to 12 next to AP; the bar leaves the AM/PM out
        const t = now.toLocaleTimeString(Qt.locale(), "h:mm AP");
        return t.replace(now.toLocaleTimeString(Qt.locale(), "AP"), "").trim();
    }
    readonly property string dateText: {
        switch (Prefs.clockDateFormat) {
        case "short":
            return Loc.now().toLocaleDateString(Qt.locale(), "ddd d");
        case "long":
            return Loc.now().toLocaleDateString(Qt.locale(), "ddd d MMM");
        case "numeric":
            return Loc.now().toLocaleDateString(Qt.locale(), Qt.locale().dateFormat(Locale.ShortFormat));
        default:
            return Loc.now().toLocaleDateString(Qt.locale(), "ddd, dd/MM");
        }
    }

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
            spacing: Theme.dp(8)

            BarText {
                text: sample.timeText
            }

            Rectangle {
                visible: Prefs.clockShowDate
                width: Theme.dp(3)
                height: Theme.dp(3)
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
            spacing: -Theme.dp(2)

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
            spacing: Theme.dp(8)

            BarText {
                visible: Prefs.clockShowDate
                anchors.verticalCenter: parent.verticalCenter
                text: sample.dateText
                color: Theme.subtext
            }

            Rectangle {
                width: accentTime.implicitWidth + Theme.dp(16)
                height: Theme.dp(24)
                radius: height / 2
                color: Theme.primary

                BarText {
                    id: accentTime

                    anchors.centerIn: parent
                    text: sample.timeText
                    color: Theme.fgAccent
                }

            }

        }

    }

    Component {
        id: clockPanelFull

        MiniPanel {
            Row {
                anchors.fill: parent
                anchors.margins: Theme.dp(8)
                spacing: Theme.dp(6)

                Column {
                    width: (parent.width - Theme.dp(6)) * 0.42
                    spacing: Theme.dp(4)

                    Rectangle {
                        width: parent.width
                        height: Theme.dp(30)
                        radius: Theme.radiusSm
                        color: Theme.accentContainer
                    }

                    Rectangle {
                        width: parent.width
                        height: Theme.dp(22)
                        radius: Theme.radiusSm
                        color: Theme.bgHigh
                    }

                    Rectangle {
                        width: parent.width
                        height: Theme.dp(22)
                        radius: Theme.radiusSm
                        color: Theme.bgHigh
                    }

                }

                MiniCalendar {
                    width: (parent.width - Theme.dp(6)) * 0.58
                    height: parent.height
                }

            }

        }

    }

    Component {
        id: clockPanelCalendar

        MiniPanel {
            width: Theme.dp(96)

            MiniCalendar {
                anchors.fill: parent
                anchors.margins: Theme.dp(8)
            }

        }

    }

    Component {
        id: mediaDisc

        Row {
            spacing: Theme.dp(8)

            Item {
                width: Theme.dp(24)
                height: Theme.dp(24)
                anchors.verticalCenter: parent.verticalCenter

                CircularProgress {
                    anchors.fill: parent
                    value: 0.4
                    thickness: 2.5
                    color: Theme.accent
                    trackColor: Theme.alpha(Theme.subtext, 0.22)
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.dp(16)
                    height: Theme.dp(16)
                    radius: height / 2
                    color: Theme.accentContainer
                }

            }

            BarText {
                text: "Artist  -  Song"
            }

            MiniPlay {
                anchors.verticalCenter: parent.verticalCenter
            }

        }

    }

    Component {
        id: mediaPlaying

        Row {
            spacing: Theme.dp(8)

            MiniBars {
                anchors.verticalCenter: parent.verticalCenter
            }

            BarText {
                text: "Artist  -  Song"
            }

            MiniPlay {
                visible: true
                anchors.verticalCenter: parent.verticalCenter
            }

        }

    }

    Component {
        id: mediaCover

        Row {
            spacing: Theme.dp(8)

            Rectangle {
                width: Theme.dp(22)
                height: Theme.dp(22)
                radius: Theme.dp(6)
                color: Theme.accentContainer
                anchors.verticalCenter: parent.verticalCenter
            }

            BarText {
                text: "Artist  -  Song"
            }

            MiniPlay {
                visible: true
                anchors.verticalCenter: parent.verticalCenter
            }

        }

    }

    Component {
        id: mediaCompact

        Row {
            spacing: Theme.dp(8)

            MiniBars {
                anchors.verticalCenter: parent.verticalCenter
            }

            MiniPlay {
                visible: true
                anchors.verticalCenter: parent.verticalCenter
            }

        }

    }

    Component {
        id: mediaPanelSide

        MiniPanel {
            Row {
                anchors.fill: parent
                anchors.margins: Theme.dp(8)
                spacing: Theme.dp(8)

                Rectangle {
                    width: Theme.dp(44)
                    height: Theme.dp(44)
                    radius: Theme.radiusSm
                    color: Theme.accentContainer
                }

                MiniLines {
                    width: parent.width - Theme.dp(52)
                }

            }

            MiniTrack {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.dp(8)
            }

        }

    }

    Component {
        id: mediaPanelCover

        MiniPanel {
            height: Theme.dp(104)

            Column {
                anchors.fill: parent
                anchors.margins: Theme.dp(8)
                spacing: Theme.dp(6)

                Rectangle {
                    width: parent.width
                    height: Theme.dp(46)
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

    // a run of two in use, the second the one you are on, then four empty
    Component {
        id: workspacesDots

        Item {
            id: wsd

            readonly property int cell: Theme.dp(26)

            implicitWidth: wsd.cell * 6
            implicitHeight: wsd.cell

            Rectangle {
                width: wsd.cell * 2
                height: wsd.cell
                radius: Theme.pill(height)
                color: Theme.withBlur(Theme.surfaceHighest)
            }

            Rectangle {
                x: wsd.cell
                width: wsd.cell
                height: wsd.cell
                radius: Theme.pill(height)
                color: Theme.accent
            }

            Repeater {
                model: 6

                Item {
                    id: mark

                    required property int index
                    readonly property real size: wsd.cell * (mark.index === 1 ? 2 / 3 : (mark.index === 0 ? 1 / 3 : 1 / 4))

                    x: mark.index * wsd.cell
                    width: wsd.cell
                    height: wsd.cell
                    layer.enabled: true
                    layer.samples: 8

                    Shape {
                        x: (wsd.cell - mark.size) / 2
                        y: (wsd.cell - mark.size) / 2
                        width: mark.size
                        height: mark.size
                        preferredRendererType: Shape.GeometryRenderer

                        ShapePath {
                            fillColor: mark.index === 1 ? Theme.fgPrimary : (mark.index === 0 ? Theme.text : Theme.alpha(Theme.subtext, 0.5))
                            strokeColor: "transparent"
                            strokeWidth: 0

                            PathSvg {
                                path: Shapes.path(mark.index === 1 ? "cookie9" : (mark.index === 0 ? "square" : "circle"), mark.size, 0)
                            }

                        }

                    }

                }

            }

        }

    }

    Component {
        id: workspacesNumbers

        Item {
            id: wsn

            readonly property int cell: Theme.dp(26)

            implicitWidth: wsn.cell * 6
            implicitHeight: wsn.cell

            Rectangle {
                width: wsn.cell * 2
                height: wsn.cell
                radius: Theme.pill(height)
                color: Theme.withBlur(Theme.surfaceHighest)
            }

            Rectangle {
                x: wsn.cell
                width: wsn.cell
                height: wsn.cell
                radius: Theme.pill(height)
                color: Theme.accent
            }

            Repeater {
                model: 6

                BarText {
                    required property int index

                    x: index * wsn.cell
                    width: wsn.cell
                    height: wsn.cell
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: index + 1
                    font.pixelSize: Theme.fs(12)
                    color: index === 1 ? Theme.fgPrimary : (index === 0 ? Theme.text : Theme.alpha(Theme.subtext, 0.55))
                }

            }

        }

    }

    Component {
        id: notificationsBadge

        Row {
            spacing: Theme.dp(5)

            MiniBell {
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: Theme.dp(16)
                height: Theme.dp(16)
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
                width: Theme.dp(7)
                height: Theme.dp(7)
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
            implicitWidth: chipRow.implicitWidth + Theme.dp(14)
            implicitHeight: Theme.dp(24)
            radius: height / 2
            color: Theme.accent

            Row {
                id: chipRow

                anchors.centerIn: parent
                spacing: Theme.dp(5)

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

        implicitWidth: Theme.dp(17)
        implicitHeight: Theme.dp(17)

        Icon {
            anchors.centerIn: parent
            name: "notifications"
            size: Theme.dp(19)
            fill: 1
            color: ink
        }

    }

    Component {
        id: systemValues

        MiniSystem {
            values: true
        }

    }

    Component {
        id: systemIcons

        MiniSystem {
            values: false
        }

    }

    // the system module's face: volume, microphone and battery, as picked
    component MiniSystem: Row {
        property bool values: true
        readonly property var on: ["wifi", "bluetooth", "volume", "mic", "battery"]

        spacing: Theme.dp(10)

        Row {
            visible: parent.on.indexOf("volume") !== -1
            spacing: Theme.dp(4)
            anchors.verticalCenter: parent.verticalCenter

            MiniGlyph {
                name: "volume_up"
                anchors.verticalCenter: parent.verticalCenter
            }

            BarText {
                visible: values
                text: "75"
                font.pixelSize: Theme.fontLabelLg
            }

        }

        Row {
            visible: parent.on.indexOf("mic") !== -1
            spacing: Theme.dp(4)
            anchors.verticalCenter: parent.verticalCenter

            MiniGlyph {
                name: "mic"
                anchors.verticalCenter: parent.verticalCenter
            }

            BarText {
                visible: values
                text: "On"
                font.pixelSize: Theme.fontLabelLg
            }

        }

        Row {
            visible: parent.on.indexOf("battery") !== -1
            spacing: Theme.dp(6)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: Theme.dp(22)
                height: Theme.dp(12)
                radius: Theme.dp(3)
                color: "transparent"
                border.width: 1.5
                border.color: Theme.subtext
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    x: 2.5
                    y: 2.5
                    width: (parent.width - Theme.dp(5)) * 0.8
                    height: parent.height - Theme.dp(5)
                    radius: 1
                    color: Theme.subtext
                }

            }

            BarText {
                visible: values
                text: "80%"
                font.pixelSize: Theme.fontLabelLg
            }

        }

    }

    // a material symbol at the bar's icon size
    component MiniGlyph: Item {
        id: glyph

        property string name: ""
        property color ink: Theme.text

        implicitWidth: Theme.dp(14)
        implicitHeight: Theme.dp(14)

        Icon {
            anchors.centerIn: parent
            name: glyph.name
            size: Math.round(glyph.width * 1.15)
            fill: 1
            color: glyph.ink
        }

    }

    Component {
        id: trayCollapsed

        Row {
            spacing: Theme.dp(4)

            MiniGlyph {
                name: "dashboard"
                implicitWidth: Theme.dp(16)
                implicitHeight: Theme.dp(16)
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: Theme.dp(16)
                height: Theme.dp(16)
                radius: height / 2
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter

                BarText {
                    anchors.centerIn: parent
                    text: "3"
                    color: Theme.bgOpaque
                    font.pixelSize: Theme.fs(11)
                }

            }

        }

    }

    Component {
        id: trayIcons

        Row {
            spacing: Theme.dp(6)

            Repeater {
                model: [Theme.accent, Theme.subtext, Theme.accentContainer]

                Rectangle {
                    required property color modelData

                    width: Theme.dp(16)
                    height: Theme.dp(16)
                    radius: Theme.dp(4)
                    color: modelData
                    anchors.verticalCenter: parent.verticalCenter
                }

            }

        }

    }

    Component {
        id: privacyMarks

        Row {
            spacing: Theme.dp(4)

            Repeater {
                model: [{
                    "ink": Theme.warning,
                    "name": "mic"
                }, {
                    "ink": Theme.error,
                    "name": "screen_share"
                }]

                Rectangle {
                    required property var modelData

                    width: Theme.dp(26)
                    height: Theme.dp(22)
                    radius: height / 2
                    color: Theme.alpha(modelData.ink, 0.2)

                    MiniGlyph {
                        anchors.centerIn: parent
                        name: parent.modelData.name
                        ink: parent.modelData.ink
                    }

                }

            }

        }

    }

    Component {
        id: privacyDot

        Rectangle {
            implicitWidth: Theme.dp(10)
            implicitHeight: Theme.dp(10)
            radius: Theme.dp(5)
            color: Theme.error
        }

    }

    Component {
        id: powerIcon

        MiniGlyph {
            name: "power_settings_new"
            implicitWidth: Theme.dp(17)
            implicitHeight: Theme.dp(17)
        }

    }

    Component {
        id: powerAccent

        Rectangle {
            implicitWidth: Theme.dp(24)
            implicitHeight: Theme.dp(24)
            radius: height / 2
            color: Theme.accent

            MiniGlyph {
                anchors.centerIn: parent
                name: "power_settings_new"
                ink: Theme.fgAccent
            }

        }

    }

    Component {
        id: powerPanelList

        MiniPanel {
            width: Theme.dp(110)

            Column {
                anchors.fill: parent
                anchors.margins: Theme.dp(8)
                spacing: Theme.dp(5)

                Repeater {
                    model: 5

                    Row {
                        required property int index

                        spacing: Theme.dp(6)

                        Rectangle {
                            width: Theme.dp(11)
                            height: Theme.dp(11)
                            radius: height / 2
                            color: index > 2 ? Theme.errorContainer : Theme.accentContainer
                        }

                        Rectangle {
                            width: Theme.dp(50)
                            height: Theme.dp(5)
                            radius: 2.5
                            color: Theme.subtextDim
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                }

            }

        }

    }

    Component {
        id: powerPanelGrid

        MiniPanel {
            width: Theme.dp(130)
            height: Theme.dp(80)

            Grid {
                anchors.centerIn: parent
                columns: 3
                spacing: Theme.dp(8)

                Repeater {
                    model: 6

                    Column {
                        required property int index

                        spacing: Theme.dp(4)

                        Rectangle {
                            width: Theme.dp(20)
                            height: Theme.dp(20)
                            radius: height / 2
                            color: index > 3 ? Theme.errorContainer : Theme.accentContainer
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Theme.dp(16)
                            height: Theme.dp(4)
                            radius: Theme.dp(2)
                            color: Theme.subtextDim
                        }

                    }

                }

            }

        }

    }

    Component {
        id: windowPlain

        Row {
            spacing: Theme.dp(8)

            Rectangle {
                width: Theme.dp(17)
                height: Theme.dp(17)
                radius: Theme.dp(4)
                color: Theme.accentContainer
                anchors.verticalCenter: parent.verticalCenter
            }

            BarText {
                text: Prefs.windowModuleText === "icon" ? "" : "Window title"
                visible: text !== ""
                font.pixelSize: Theme.fontLabelLg
                font.weight: Font.Medium
                font.bold: false
            }

        }

    }

    Component {
        id: windowChip

        Rectangle {
            implicitWidth: chipRow.implicitWidth + (Prefs.windowModuleText === "icon" ? Theme.dp(12) : Theme.dp(18))
            implicitHeight: Theme.dp(26)
            radius: height / 2
            color: Theme.accentContainer

            Row {
                id: chipRow

                anchors.centerIn: parent
                spacing: Theme.dp(8)

                Rectangle {
                    width: Theme.dp(17)
                    height: Theme.dp(17)
                    radius: Theme.dp(4)
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }

                BarText {
                    text: Prefs.windowModuleText === "icon" ? "" : "Window title"
                    visible: text !== ""
                    color: Theme.fgAccentContainer
                    font.pixelSize: Theme.fontLabelLg
                    font.weight: Font.Medium
                    font.bold: false
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

    // a play button on the accent
    component MiniPlay: Rectangle {
        width: Theme.dp(22)
        height: Theme.dp(22)
        radius: height / 2
        color: Theme.accent

        Icon {
            anchors.centerIn: parent
            name: "play_arrow"
            size: Theme.dp(18)
            fill: 1
            color: Theme.fgAccent
        }

    }

    // a title and a line under it
    component MiniLines: Column {
        spacing: Theme.dp(5)

        Rectangle {
            width: parent.width * 0.8
            height: Theme.dp(7)
            radius: 3.5
            color: Theme.text
            opacity: 0.8
        }

        Rectangle {
            width: parent.width * 0.5
            height: Theme.dp(6)
            radius: Theme.dp(3)
            color: Theme.subtextDim
        }

    }

    // a progress track, part played
    component MiniTrack: Rectangle {
        height: Theme.dp(4)
        radius: Theme.dp(2)
        color: Theme.bgHigh

        Rectangle {
            width: parent.width * 0.4
            height: parent.height
            radius: Theme.dp(2)
            color: Theme.accent
        }

    }

    // a panel, shrunk: the frame the panel samples are drawn in
    component MiniPanel: Rectangle {
        width: Theme.dp(150)
        height: Theme.dp(90)
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

                width: Theme.dp(7)
                height: Theme.dp(7)
                radius: Theme.dp(2)
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
