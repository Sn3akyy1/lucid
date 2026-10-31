import QtQuick
import QtQuick.Effects
import qs
import qs.lucidui

// the m3 expressive floating toolbar the overlay is run from, with the fab at
// its end. while choosing it holds the modes, the targets and their options;
// while marking up, the editor's tools. it trades one set for the other in
// place, the container springing to the new width
Item {
    id: bar

    property var stage: null
    // tooltips and sheets open away from the edge the toolbar sits on
    property bool tipAbove: true
    property bool stylesOpen: false
    readonly property string mode: bar.stage ? bar.stage.mode : "shot"
    readonly property string phase: bar.stage ? bar.stage.phase : "select"
    readonly property bool marking: bar.phase === "mark"
    readonly property bool working: bar.phase === "read" || (bar.stage && bar.stage.busy)
    readonly property bool recording: Capture.active
    readonly property var tools: [{
        "key": "move",
        "icon": "crop_free",
        "tip": "Move and resize the selection (M)"
    }, {
        "key": "pen",
        "icon": "draw",
        "tip": "Pen (P)"
    }, {
        "key": "hl",
        "icon": "ink_highlighter",
        "tip": "Highlighter (H)"
    }, {
        "key": "arrow",
        "icon": "arrow_outward",
        "tip": "Arrow (A)"
    }, {
        "key": "rect",
        "icon": "rectangle",
        "tip": "Box (B)"
    }, {
        "key": "oval",
        "icon": "circle",
        "tip": "Ellipse (O)"
    }, {
        "key": "text",
        "icon": "title",
        "tip": "Text (T)"
    }, {
        "key": "step",
        "icon": "123",
        "tip": "Numbered steps (N)"
    }, {
        "key": "redact",
        "icon": "blur_on",
        "tip": "Redact (X)"
    }]

    // room round the toolbar for its shadow, inside the item: drawn as one
    // picture while it fades, everything it shows has to fall within it
    readonly property int pad: Theme.dp(28)
    readonly property int bodyHeight: Theme.dp(64)

    implicitWidth: pill.width + Theme.dp(8) + fab.width + bar.pad * 2
    implicitHeight: bar.bodyHeight + bar.pad * 2
    onMarkingChanged: bar.stylesOpen = false

    RectangularShadow {
        anchors.fill: pill
        radius: pill.radius
        blur: Theme.dp(20)
        offset.y: Theme.dp(4)
        color: Theme.alpha(Theme.shadow, Theme.isLight ? 0.18 : 0.4)
    }

    Rectangle {
        id: pill

        x: bar.pad
        y: bar.pad
        width: (bar.marking ? markRow.implicitWidth : pickRow.implicitWidth) + Theme.dp(16)
        height: Theme.dp(64)
        radius: height / 2
        color: Theme.surfaceContainer
        // only while it changes width: clipped for good, the tooltips that
        // stand above the buttons would be cut away
        clip: grow.running

        Row {
            id: pickRow

            x: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(4)
            opacity: bar.marking ? 0 : (bar.working ? 0.5 : 1)
            visible: opacity > 0.01
            enabled: !bar.marking && !bar.working

            ShotModeButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "screenshot_region"
                label: "Screenshot"
                tip: "Screenshot (S)"
                tipAbove: bar.tipAbove
                selected: bar.mode === "shot"
                onClicked: bar.stage.setMode("shot")
            }

            ShotModeButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: bar.recording ? "stop_circle" : "screen_record"
                label: bar.recording ? "Recording" : "Record"
                tip: bar.recording ? "A recording is running" : "Record the screen (R)"
                tipAbove: bar.tipAbove
                selected: bar.mode === "record"
                disabled: bar.recording
                onFill: Theme.errorContainer
                onInk: Theme.fgErrorContainer
                onClicked: bar.stage.setMode("record")
            }

            ShotModeButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "text_fields"
                label: "Text"
                tip: "Copy the text in it (T)"
                tipAbove: bar.tipAbove
                selected: bar.mode === "text"
                onClicked: bar.stage.setMode("text")
            }

            ShotModeButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "colorize"
                label: "Colour"
                tip: "Pick a colour (C)"
                tipAbove: bar.tipAbove
                selected: bar.mode === "colour"
                onClicked: bar.stage.setMode("colour")
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Theme.dp(24)
                color: Theme.alpha(Theme.outline, 0.7)
            }

            ShotSegments {
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.mode !== "colour"
                tipAbove: bar.tipAbove
                current: bar.stage ? bar.stage.target : "region"
                options: [{
                    "key": "region",
                    "icon": "screenshot_region",
                    "tip": "A region, or a window you click (Tab)"
                }, {
                    "key": "window",
                    "icon": "select_window",
                    "tip": "A window (W)"
                }]
                onPicked: (key) => {
                    return bar.stage.setTarget(key);
                }
            }

            ShotSegments {
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.mode === "colour"
                tipAbove: bar.tipAbove
                current: bar.stage ? bar.stage.format : "hex"
                options: [{
                    "key": "hex",
                    "label": "HEX",
                    "tip": "#3a7bd5"
                }, {
                    "key": "rgb",
                    "label": "RGB",
                    "tip": "rgb(58, 123, 213)"
                }, {
                    "key": "hsl",
                    "label": "HSL",
                    "tip": "hsl(215, 65%, 53%)"
                }]
                onPicked: (key) => {
                    bar.stage.format = key;
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.mode === "shot" || bar.mode === "record"
                width: 1
                height: Theme.dp(24)
                color: Theme.alpha(Theme.outline, 0.7)
            }

            ShotButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.mode === "shot"
                icon: "edit"
                tip: bar.stage && bar.stage.markup ? "Mark up before saving: on (E)" : "Mark up before saving (E)"
                tipAbove: bar.tipAbove
                checked: bar.stage ? bar.stage.markup : false
                onClicked: bar.stage.markup = !bar.stage.markup
            }

            ShotButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.mode === "record"
                icon: bar.stage && bar.stage.mic ? "mic" : "mic_off"
                tip: bar.stage && bar.stage.mic ? "Recording the microphone" : "Not recording the microphone"
                tipAbove: bar.tipAbove
                checked: bar.stage ? bar.stage.mic : false
                onClicked: bar.stage.mic = !bar.stage.mic
            }

            ShotButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.mode === "record"
                icon: bar.stage && bar.stage.system ? "volume_up" : "volume_off"
                tip: bar.stage && bar.stage.system ? "Recording what is playing" : "Not recording what is playing"
                tipAbove: bar.tipAbove
                checked: bar.stage ? bar.stage.system : false
                onClicked: bar.stage.system = !bar.stage.system
            }

            ShotButton {
                readonly property int secs: !bar.stage ? 0 : (bar.mode === "record" ? bar.stage.countdown : bar.stage.timer)

                anchors.verticalCenter: parent.verticalCenter
                visible: bar.mode === "shot" || bar.mode === "record"
                icon: "timer"
                badge: secs > 0 ? String(secs) : ""
                tip: bar.mode === "record" ? (secs > 0 ? "Counts down " + secs + " s before recording" : "Starts recording straight away") : (secs > 0 ? "Self-timer: " + secs + " s" : "Self-timer")
                tipAbove: bar.tipAbove
                checked: secs > 0
                onClicked: bar.stage.cycleTimer()
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Theme.dp(24)
                color: Theme.alpha(Theme.outline, 0.7)
            }

            ShotButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "settings"
                tip: "Screenshot settings"
                tipAbove: bar.tipAbove
                onClicked: bar.stage.openSettings()
            }

            ShotButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                tip: "Close (Esc)"
                tipAbove: bar.tipAbove
                onClicked: bar.stage.close()
            }

        }

        Row {
            id: markRow

            x: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(4)
            opacity: bar.marking ? (bar.working ? 0.5 : 1) : 0
            visible: opacity > 0.01
            enabled: bar.marking && !bar.working

            ShotButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "arrow_back"
                tip: bar.stage && bar.stage.editing ? "Discard the changes" : "Back to choosing"
                tipAbove: bar.tipAbove
                onClicked: bar.stage.leaveMarkup()
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Theme.dp(24)
                color: Theme.alpha(Theme.outline, 0.7)
            }

            Repeater {
                model: bar.tools

                ShotButton {
                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    icon: modelData.icon
                    tip: modelData.tip
                    tipAbove: bar.tipAbove
                    checked: bar.stage && bar.stage.tool === modelData.key
                    onClicked: bar.stage.tool = modelData.key
                }

            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Theme.dp(24)
                color: Theme.alpha(Theme.outline, 0.7)
            }

            ShotButton {
                id: styleButton

                anchors.verticalCenter: parent.verticalCenter
                dot: bar.stage ? bar.stage.ink : "transparent"
                tip: "Colour and size"
                tipAbove: bar.tipAbove
                checked: bar.stylesOpen
                onClicked: bar.stylesOpen = !bar.stylesOpen
            }

            ShotButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "undo"
                tip: "Undo (Ctrl+Z)"
                tipAbove: bar.tipAbove
                disabled: !bar.stage || !bar.stage.canUndo
                onClicked: bar.stage.undo()
            }

            ShotButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "redo"
                tip: "Redo (Ctrl+Shift+Z)"
                tipAbove: bar.tipAbove
                disabled: !bar.stage || !bar.stage.canRedo
                onClicked: bar.stage.redo()
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Theme.dp(24)
                color: Theme.alpha(Theme.outline, 0.7)
            }

            ShotButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "content_copy"
                tip: "Copy without saving (Ctrl+C)"
                tipAbove: bar.tipAbove
                onClicked: bar.stage.finishMarkup("copy")
            }

            ShotButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "keep"
                tip: "Pin it to the screen"
                tipAbove: bar.tipAbove
                onClicked: bar.stage.finishMarkup("pin")
            }

            ShotButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.stage && !bar.stage.editing
                icon: "document_scanner"
                tip: "Copy the text in it"
                tipAbove: bar.tipAbove
                onClicked: bar.stage.readSelection()
            }

        }

        Behavior on width {
            NumberAnimation {
                id: grow

                duration: Theme.durDefaultSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

    }

    ShotFab {
        id: fab

        readonly property bool colourMode: bar.mode === "colour" && !bar.marking

        x: pill.x + pill.width + Theme.dp(8)
        anchors.verticalCenter: pill.verticalCenter
        visible: !fab.colourMode || (bar.stage && bar.stage.palette.length > 0)
        tipAbove: bar.tipAbove
        busy: bar.working
        icon: bar.marking ? "check" : (bar.mode === "record" ? "fiber_manual_record" : (bar.mode === "text" ? "document_scanner" : (bar.mode === "colour" ? "content_copy" : "photo_camera")))
        tip: bar.stage ? bar.stage.fabTip : ""
        fill: bar.marking ? Theme.primary : (bar.mode === "record" ? Theme.error : (bar.mode === "text" ? Theme.tertiary : Theme.primaryContainer))
        ink: bar.marking ? Theme.fgPrimary : (bar.mode === "record" ? Theme.fgError : (bar.mode === "text" ? Theme.fgTertiary : Theme.fgPrimaryContainer))
        disabled: bar.mode === "record" && bar.recording
        onClicked: bar.stage.fabAction()
    }

    ShotSwatches {
        stage: bar.stage
        shown: bar.stylesOpen && bar.marking
        x: Math.round(pill.x + markRow.x + styleButton.x + styleButton.width / 2 - width / 2)
        y: bar.tipAbove ? pill.y - height - Theme.dp(12) : pill.y + pill.height + Theme.dp(12)
        transformOrigin: bar.tipAbove ? Item.Bottom : Item.Top
        onDone: bar.stylesOpen = false
    }

    ShotPalette {
        stage: bar.stage
        tipAbove: bar.tipAbove
        visible: bar.mode === "colour" && !bar.marking && opacity > 0.01
        x: Math.round(pill.x + (pill.width - width) / 2)
        y: bar.tipAbove ? pill.y - height - Theme.dp(12) : pill.y + pill.height + Theme.dp(12)
    }

}
