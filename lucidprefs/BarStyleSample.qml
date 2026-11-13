import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Services.SystemTray
import qs
import qs.lucidicons
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
    // the apps in the tray right now, for its samples
    readonly property var trayApps: sample.moduleId === "tray" ? Tray.ordered(SystemTray.items ? SystemTray.items.values : []) : []
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
        "media/progress": mediaProgress,
        "media/controls": mediaControls,
        "media/panel/vinyl": mediaPanelVinyl,
        "media/panel/backdrop": mediaPanelBackdrop,
        "media/panel/mini": mediaPanelMini,
        "workspaces/dots": workspacesSample,
        "workspaces/numbers": workspacesSample,
        "notifications/badge": notificationsBadge,
        "notifications/dot": notificationsDot,
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
        "start/logo": startLogo,
        "start/grid": startGrid,
        "start/distro": startDistro,
        "start/avatar": startAvatar,
        "start/label": startLabel
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
    // the day's name and the date, apart, as the clock shows them
    readonly property var dateParts: {
        switch (Prefs.clockDateFormat) {
        case "short":
            return ["ddd", "d"];
        case "long":
            return ["ddd", "d MMM"];
        case "numeric":
            return ["", Qt.locale().dateFormat(Locale.ShortFormat)];
        default:
            return ["ddd,", "dd/MM"];
        }
    }
    readonly property string dayText: sample.dateParts[0] === "" ? "" : Loc.now().toLocaleDateString(Qt.locale(), sample.dateParts[0])
    readonly property string dayDateText: Loc.now().toLocaleDateString(Qt.locale(), sample.dateParts[1])

    // the strip of bar behind it, and how far the module's own pill pads it
    readonly property int stripHeight: Math.min(Theme.dp(34), Theme.dp(Prefs.barHeight))
    readonly property int pad: loader.item && loader.item.pad !== undefined ? loader.item.pad : Theme.dp(12)
    // the media samples' track, as the bar's title shows it
    readonly property string mediaTitle: Prefs.mediaArtist ? "Artist  -  Song" : "Song"

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

            Row {
                visible: Prefs.clockShowDate
                spacing: Theme.dp(4)

                BarText {
                    visible: sample.dayText !== ""
                    text: sample.dayText
                    color: Theme.subtextDim
                }

                BarText {
                    text: sample.dayDateText
                    color: Theme.accent
                }

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

            Row {
                visible: Prefs.clockShowDate
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.dp(3)

                BarText {
                    visible: sample.dayText !== ""
                    text: sample.dayText
                    color: Theme.subtextDim
                    font.pixelSize: Theme.fs(10)
                }

                BarText {
                    text: sample.dayDateText
                    color: Theme.accent
                    font.pixelSize: Theme.fs(10)
                }

            }

        }

    }

    Component {
        id: clockAccent

        Row {
            spacing: Theme.dp(8)

            Row {
                visible: Prefs.clockShowDate
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(4)

                BarText {
                    visible: sample.dayText !== ""
                    text: sample.dayText
                    color: Theme.subtext
                }

                BarText {
                    text: sample.dayDateText
                    color: Theme.accent
                }

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
            readonly property int pad: Theme.dp(10)

            spacing: Theme.dp(8)

            Item {
                width: Theme.dp(26)
                height: Theme.dp(26)
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
                    width: Theme.dp(18)
                    height: Theme.dp(18)
                    radius: Theme.dp(9)
                    color: Theme.accentContainer
                }

            }

            Item {
                width: Math.min(Theme.dp(Prefs.mediaTitleWidth), Math.max(Theme.dp(60), Math.ceil(discTitle.implicitWidth)))
                height: Theme.dp(18)
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Text {
                    id: discTitle

                    anchors.verticalCenter: parent.verticalCenter
                    text: sample.mediaTitle
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(13)
                    font.variableAxes: Theme.axes(Theme.fs(13), 640, 0)
                }

            }

            MiniPlay {
                visible: Prefs.mediaPlayButton
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
            readonly property int pad: Theme.dp(10)

            spacing: Theme.dp(8)

            Rectangle {
                width: Theme.dp(22)
                height: Theme.dp(22)
                radius: Theme.dp(6)
                color: Theme.accentContainer
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: Math.min(Theme.dp(Prefs.mediaTitleWidth), Math.max(Theme.dp(60), Math.ceil(coverTitle.implicitWidth)))
                height: Theme.dp(18)
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Text {
                    id: coverTitle

                    anchors.verticalCenter: parent.verticalCenter
                    text: sample.mediaTitle
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(13)
                    font.variableAxes: Theme.axes(Theme.fs(13), 640, 0)
                }

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
            readonly property int pad: Theme.dp(10)

            spacing: Theme.dp(8)

            Item {
                width: Theme.dp(26)
                height: Theme.dp(26)
                anchors.verticalCenter: parent.verticalCenter

                MiniBars {
                    anchors.centerIn: parent
                }

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

    Component {
        id: mediaProgress

        Item {
            id: prog

            readonly property int pad: Theme.dp(10)

            implicitWidth: progRow.implicitWidth
            implicitHeight: progRow.implicitHeight

            // the fill runs in the pill itself, inset 4 all round
            Rectangle {
                readonly property real track: prog.implicitWidth + prog.pad * 2 - Theme.dp(8)

                x: Theme.dp(4) - prog.pad
                anchors.verticalCenter: parent.verticalCenter
                height: sample.stripHeight - Theme.dp(8)
                width: Math.max(height, Math.round(track * 0.45))
                radius: height / 2
                color: Theme.alpha(Theme.accent, 0.28)
            }

            Row {
                id: progRow

                spacing: Theme.dp(8)

                Item {
                    width: Theme.dp(26)
                    height: Theme.dp(26)
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.centerIn: parent
                        width: Theme.dp(18)
                        height: Theme.dp(18)
                        radius: Theme.dp(9)
                        color: Theme.accentContainer
                    }

                }

                Item {
                    width: Math.min(Theme.dp(Prefs.mediaTitleWidth), Math.max(Theme.dp(60), Math.ceil(progTitle.implicitWidth)))
                    height: Theme.dp(18)
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true

                    Text {
                        id: progTitle

                        anchors.verticalCenter: parent.verticalCenter
                        text: sample.mediaTitle
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(13)
                        font.variableAxes: Theme.axes(Theme.fs(13), 640, 0)
                    }

                }

                MiniPlay {
                    visible: Prefs.mediaPlayButton
                    anchors.verticalCenter: parent.verticalCenter
                }

            }

        }

    }

    Component {
        id: mediaControls

        Row {
            readonly property int pad: Theme.dp(10)

            spacing: Theme.dp(8)

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(2)

                Item {
                    width: Theme.dp(24)
                    height: Theme.dp(24)
                    anchors.verticalCenter: parent.verticalCenter

                    Icon {
                        anchors.centerIn: parent
                        name: "skip_previous"
                        size: Theme.dp(18)
                        fill: 1
                        color: Theme.text
                    }

                }

                MiniPlay {
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: Theme.dp(24)
                    height: Theme.dp(24)
                    anchors.verticalCenter: parent.verticalCenter

                    Icon {
                        anchors.centerIn: parent
                        name: "skip_next"
                        size: Theme.dp(18)
                        fill: 1
                        color: Theme.text
                    }

                }

            }

            Item {
                width: Math.min(Theme.dp(Prefs.mediaTitleWidth), Math.max(Theme.dp(60), Math.ceil(controlsTitle.implicitWidth)))
                height: Theme.dp(18)
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Text {
                    id: controlsTitle

                    anchors.verticalCenter: parent.verticalCenter
                    text: sample.mediaTitle
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(13)
                    font.variableAxes: Theme.axes(Theme.fs(13), 640, 0)
                }

            }

        }

    }

    Component {
        id: mediaPanelVinyl

        MiniPanel {
            height: Theme.dp(104)

            Column {
                anchors.fill: parent
                anchors.margins: Theme.dp(8)
                spacing: Theme.dp(6)

                Item {
                    width: parent.width
                    height: Theme.dp(52)

                    CircularProgress {
                        anchors.centerIn: parent
                        width: parent.height
                        height: width
                        thickness: Theme.dp(3)
                        value: 0.4
                        color: Theme.accent
                        trackColor: Theme.alpha(Theme.text, 0.14)
                    }

                    ShapedImage {
                        anchors.centerIn: parent
                        width: parent.height - Theme.dp(12)
                        height: width
                        shape: "cookie12"
                        fallbackColor: Theme.accentContainer
                    }

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
        id: mediaPanelBackdrop

        MiniPanel {
            clip: true

            // the cover's colours, run together behind the panel
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                opacity: 0.55
                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: Theme.accentContainer
                    }

                    GradientStop {
                        position: 1
                        color: Theme.alpha(Theme.cTertiary, 0.6)
                    }

                }

            }

            Row {
                anchors.fill: parent
                anchors.margins: Theme.dp(8)
                spacing: Theme.dp(8)

                Rectangle {
                    width: Theme.dp(44)
                    height: Theme.dp(44)
                    radius: Theme.radiusSm
                    color: Theme.accent
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
        id: mediaPanelMini

        MiniPanel {
            width: Theme.dp(124)
            height: Theme.dp(64)

            // clear of the panel's corners
            MiniLines {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Theme.dp(14)
                anchors.rightMargin: Theme.dp(14)
                anchors.topMargin: Theme.dp(12)
            }

            MiniTrack {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: Theme.dp(14)
                anchors.rightMargin: Theme.dp(14)
                anchors.bottomMargin: Theme.dp(12)
            }

        }

    }

    // the bar's own cells: square, inset as far as the pill pads them, those in
    // use on one surface, the accent pill on the first, as many as the bar shows
    Component {
        id: workspacesSample

        Item {
            id: ws

            readonly property bool numbered: sample.styleKey === "numbers"
            readonly property int pad: Theme.dp(4)
            readonly property int cell: Math.max(Theme.dp(16), sample.stripHeight - ws.pad * 2)
            readonly property int count: Math.max(3, Prefs.workspacesShown)

            implicitWidth: ws.cell * ws.count
            implicitHeight: ws.cell

            Rectangle {
                width: ws.cell * 3
                height: ws.cell
                radius: Theme.pill(height)
                color: Theme.withBlur(Theme.surfaceHighest)
            }

            Rectangle {
                width: ws.cell
                height: ws.cell
                radius: Theme.pill(height)
                color: Theme.accent
            }

            Repeater {
                model: ws.count

                Item {
                    id: mark

                    required property int index
                    readonly property bool focused: mark.index === 0
                    readonly property bool occupied: mark.index < 3
                    readonly property real size: ws.cell * (mark.focused ? 2 / 3 : (mark.occupied ? 1 / 3 : 1 / 4))

                    x: mark.index * ws.cell
                    width: ws.cell
                    height: ws.cell

                    Item {
                        anchors.fill: parent
                        visible: !ws.numbered
                        layer.enabled: true
                        layer.samples: 8
                        layer.smooth: true

                        Shape {
                            x: (ws.cell - mark.size) / 2
                            y: (ws.cell - mark.size) / 2
                            width: mark.size
                            height: mark.size
                            preferredRendererType: Shape.GeometryRenderer

                            ShapePath {
                                fillColor: mark.focused ? Theme.fgPrimary : (mark.occupied ? Theme.text : Theme.alpha(Theme.subtext, 0.5))
                                strokeColor: "transparent"
                                strokeWidth: 0

                                PathSvg {
                                    path: Shapes.path(mark.focused ? "cookie9" : (mark.occupied ? "square" : "circle"), mark.size, 0)
                                }

                            }

                        }

                    }

                    Text {
                        anchors.centerIn: parent
                        visible: ws.numbered
                        text: mark.index + 1
                        color: mark.focused ? Theme.fgPrimary : (mark.occupied ? Theme.text : Theme.alpha(Theme.subtext, 0.55))
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(12)
                        font.variableAxes: Theme.axes(Theme.fs(12), 680, 100)
                    }

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

    // the tray's samples show the apps in it now, or the palette's colours with none
    Component {
        id: trayCollapsed

        Row {
            spacing: Theme.dp(5)

            Item {
                id: stack

                readonly property int tile: Theme.dp(16)
                readonly property int step: Math.round(stack.tile * 0.78)
                readonly property int gap: Theme.dp(2)

                width: stack.tile + 2 * stack.step
                height: stack.tile
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: 3

                    Item {
                        id: stacked

                        required property int index
                        readonly property var app: sample.trayApps[stacked.index] || null
                        readonly property string slot: stacked.app ? Tray.slotOf(stacked.app) : ""

                        x: stacked.index * stack.step
                        z: -stacked.index
                        width: stack.tile
                        height: stack.tile
                        layer.enabled: stacked.index > 0

                        Rectangle {
                            anchors.fill: parent
                            visible: !stacked.app
                            radius: Theme.dp(4)
                            color: [Theme.accent, Theme.subtext, Theme.accentContainer][stacked.index]
                        }

                        Image {
                            anchors.fill: parent
                            visible: !!stacked.app && stacked.slot === ""
                            source: stacked.app && stacked.slot === "" ? Tray.iconSource(stacked.app.icon) : ""
                            sourceSize.width: stack.tile * 2
                            sourceSize.height: stack.tile * 2
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: false
                        }

                        Loader {
                            anchors.centerIn: parent
                            active: stacked.slot !== ""

                            sourceComponent: TonalIcon {
                                size: stack.tile
                                slot: stacked.slot
                            }

                        }

                        // the one in front, a gap larger all round
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskInverted: true
                            maskSource: stackCut
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }

                    }

                }

                Item {
                    id: stackCut

                    width: stack.tile
                    height: stack.tile
                    visible: false
                    layer.enabled: true

                    Rectangle {
                        x: -stack.step - stack.gap
                        y: -stack.gap
                        width: stack.tile + 2 * stack.gap
                        height: stack.tile + 2 * stack.gap
                        radius: width * 0.32
                        color: "black"
                    }

                }

            }

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                visible: sample.trayApps.length === 0 || sample.trayApps.length > 3
                text: "+" + (sample.trayApps.length > 3 ? sample.trayApps.length - 3 : 2)
                color: Theme.subtext
                font.pixelSize: Theme.fs(11)
            }

        }

    }

    Component {
        id: trayIcons

        Row {
            spacing: 0

            Repeater {
                model: 3

                Item {
                    id: slotted

                    required property int index
                    readonly property var app: sample.trayApps[slotted.index] || null
                    readonly property string slot: slotted.app ? Tray.slotOf(slotted.app) : ""

                    width: Theme.dp(22)
                    height: Theme.dp(22)
                    anchors.verticalCenter: parent.verticalCenter

                    // a slot lit as under the pointer
                    Rectangle {
                        anchors.centerIn: parent
                        width: Theme.dp(21)
                        height: Theme.dp(21)
                        radius: width / 2
                        color: Theme.text
                        opacity: slotted.index === 1 ? 0.12 : 0
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Theme.dp(15)
                        height: Theme.dp(15)
                        visible: !slotted.app
                        radius: Theme.dp(4)
                        color: [Theme.accent, Theme.subtext, Theme.accentContainer][slotted.index]
                    }

                    Image {
                        anchors.centerIn: parent
                        width: Theme.dp(15)
                        height: Theme.dp(15)
                        visible: !!slotted.app && slotted.slot === ""
                        source: slotted.app && slotted.slot === "" ? Tray.iconSource(slotted.app.icon) : ""
                        sourceSize.width: Theme.dp(15) * 2
                        sourceSize.height: Theme.dp(15) * 2
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: false
                    }

                    Loader {
                        anchors.centerIn: parent
                        active: slotted.slot !== ""

                        sourceComponent: TonalIcon {
                            size: Theme.dp(15)
                            slot: slotted.slot
                        }

                    }

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
        id: startLogo

        // Lucid's mark, as the bar draws it, in a circle as wide as the bar is tall
        Item {
            id: logoSample

            readonly property int pad: 0
            readonly property int glyph: Math.max(Theme.dp(16), Math.min(Theme.dp(22), sample.stripHeight - Theme.dp(14)))

            implicitWidth: sample.stripHeight
            implicitHeight: sample.stripHeight

            Shape {
                anchors.centerIn: parent
                width: logoSample.glyph
                height: logoSample.glyph
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: Theme.accent
                    strokeWidth: 3
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    PathSvg {
                        path: "M15.92,5.72 A7.4,7.4 0 1 0 18.95,14.53"
                    }

                }

                ShapePath {
                    strokeWidth: 0
                    fillColor: Theme.text

                    PathSvg {
                        path: "M12,7.4 C12.598,10.62 13.38,11.402 16.6,12 C13.38,12.598 12.598,13.38 12,16.6 C11.402,13.38 10.62,12.598 7.4,12 C10.62,11.402 11.402,10.62 12,7.4 Z"
                    }

                }

                ShapePath {
                    strokeWidth: 0
                    fillColor: Theme.accent

                    PathSvg {
                        path: "M20,9.4 A1,1 0 1 0 22,9.4 A1,1 0 1 0 20,9.4 Z"
                    }

                }

                transform: Scale {
                    xScale: logoSample.glyph / 24
                    yScale: logoSample.glyph / 24
                }

            }

        }

    }

    Component {
        id: startGrid

        // the bar's grid of nine, in a circle as wide as the bar is tall
        Item {
            id: gridSample

            readonly property int pad: 0
            readonly property int size: {
                const s = Math.round(gridSample.glyph * 0.78);
                return (sample.stripHeight - s) % 2 === 0 ? s : s - 1;
            }
            readonly property int glyph: Math.max(Theme.dp(16), Math.min(Theme.dp(22), sample.stripHeight - Theme.dp(14)))

            implicitWidth: sample.stripHeight
            implicitHeight: sample.stripHeight

            Grid {
                anchors.centerIn: parent
                columns: 3
                spacing: gridSample.size / 8

                Repeater {
                    model: 9

                    Rectangle {
                        required property int index

                        width: gridSample.size / 4
                        height: width
                        radius: Theme.pill(height)
                        color: index === 4 ? Theme.accent : Theme.text
                    }

                }

            }

        }

    }

    Component {
        id: startDistro

        // a generic peak, in the accent: the real logo is read on the bar.
        // in a circle as wide as the bar is tall, at the bar's glyph size
        Item {
            id: distroSample

            readonly property int pad: 0
            readonly property int glyph: Math.max(Theme.dp(16), Math.min(Theme.dp(22), sample.stripHeight - Theme.dp(14)))

            implicitWidth: sample.stripHeight
            implicitHeight: sample.stripHeight

            Shape {
                anchors.centerIn: parent
                width: distroSample.glyph
                height: distroSample.glyph
                preferredRendererType: Shape.CurveRenderer
                transform: Scale {
                    xScale: distroSample.glyph / 24
                    yScale: distroSample.glyph / 24
                }

                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: Theme.accent

                    PathSvg {
                        path: "M12 2 3 21h4.5L12 11l4.5 10H21Z"
                    }

                }

            }

        }

    }

    Component {
        id: startAvatar

        // the account picture, as the bar shows it, in a circle as wide as the bar is tall
        Item {
            id: avatarSample

            readonly property int pad: 0
            readonly property int glyph: Math.max(Theme.dp(16), Math.min(Theme.dp(22), sample.stripHeight - Theme.dp(14)))

            implicitWidth: sample.stripHeight
            implicitHeight: sample.stripHeight

            UserAvatar {
                anchors.centerIn: parent
                user: Users.me
                size: avatarSample.glyph + Theme.dp(2)
            }

        }

    }

    Component {
        id: startLabel

        // the word on its chip, hugged as closely at its ends as at its top
        Item {
            id: labelSample

            readonly property int pad: 0
            readonly property int chipHeight: Math.min(Theme.dp(24), sample.stripHeight - Theme.dp(8))

            implicitWidth: Math.ceil(startLabelText.implicitWidth) + Theme.dp(20) + sample.stripHeight - labelSample.chipHeight
            implicitHeight: sample.stripHeight

            Rectangle {
                anchors.centerIn: parent
                width: Math.ceil(startLabelText.implicitWidth) + Theme.dp(20)
                height: labelSample.chipHeight
                radius: Theme.pill(height)
                color: Theme.accent

                BarText {
                    id: startLabelText

                    anchors.centerIn: parent
                    text: "Start"
                    color: Theme.fgAccent
                    font.pixelSize: Theme.fs(12)
                }

            }

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

    // the media module's moving bars, standing still
    component MiniBars: Row {
        spacing: Theme.dp(2)

        Repeater {
            model: [6, 11, 8]

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

    // the bar's play button: a pill on the accent, paused while it plays
    component MiniPlay: Rectangle {
        width: Math.round(Theme.dp(24) * 1.3)
        height: Theme.dp(24)
        radius: Theme.dp(12)
        color: Theme.accent

        Icon {
            anchors.centerIn: parent
            name: "pause"
            size: Theme.dp(16)
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
