import QtQuick
import Quickshell.Widgets
import qs
import qs.lucidlumen
import qs.lucidui

// the editor beside the picture: crop and turn it, adjust its light and colour,
// give it a look, or draw on it. the tabs slide past one another
Rectangle {
    id: panel

    required property var win
    required property var app
    required property var stage
    readonly property var e: panel.win.edits
    readonly property var a: panel.e.adjust || ({})
    readonly property real fullW: Theme.dp(336)
    readonly property var tabs: [{
        "key": "crop",
        "label": "Crop",
        "icon": "crop"
    }, {
        "key": "adjust",
        "label": "Adjust",
        "icon": "tune"
    }, {
        "key": "filters",
        "label": "Filters",
        "icon": "photo_filter"
    }, {
        "key": "markup",
        "label": "Draw",
        "icon": "draw"
    }]
    readonly property int tabIndex: Math.max(0, ["crop", "adjust", "filters", "markup"].indexOf(panel.win.tab))
    // the looks, as adjustments from -100 to 100
    readonly property var looks: [{
        "id": "",
        "name": "Original",
        "a": {}
    }, {
        "id": "vivid",
        "name": "Vivid",
        "a": {
            "contrast": 15,
            "saturation": 22,
            "vibrance": 30
        }
    }, {
        "id": "warm",
        "name": "Warm",
        "a": {
            "warmth": 35,
            "saturation": 8,
            "exposure": 3
        }
    }, {
        "id": "cool",
        "name": "Cool",
        "a": {
            "warmth": -32,
            "tint": 4,
            "contrast": 6
        }
    }, {
        "id": "golden",
        "name": "Golden",
        "a": {
            "warmth": 48,
            "highlights": 15,
            "saturation": 12,
            "fade": 12
        }
    }, {
        "id": "fresh",
        "name": "Fresh",
        "a": {
            "exposure": 7,
            "vibrance": 34,
            "warmth": -8,
            "contrast": 8,
            "shadows": 10
        }
    }, {
        "id": "matte",
        "name": "Matte",
        "a": {
            "fade": 55,
            "contrast": -14,
            "saturation": -12
        }
    }, {
        "id": "vintage",
        "name": "Vintage",
        "a": {
            "warmth": 24,
            "fade": 42,
            "saturation": -24,
            "tint": 9,
            "vignette": 28
        }
    }, {
        "id": "drama",
        "name": "Drama",
        "a": {
            "contrast": 42,
            "highlights": -28,
            "shadows": -12,
            "saturation": 10,
            "vignette": 34
        }
    }, {
        "id": "mono",
        "name": "Mono",
        "a": {
            "mono": 100,
            "contrast": 8
        }
    }, {
        "id": "noir",
        "name": "Noir",
        "a": {
            "mono": 100,
            "contrast": 50,
            "exposure": -6,
            "vignette": 38
        }
    }, {
        "id": "silver",
        "name": "Silver",
        "a": {
            "mono": 100,
            "fade": 35,
            "contrast": -10,
            "highlights": 12
        }
    }]
    readonly property var inks: [{
        "id": "red",
        "c": "#e53935"
    }, {
        "id": "orange",
        "c": "#fb8c00"
    }, {
        "id": "yellow",
        "c": "#fdd835"
    }, {
        "id": "green",
        "c": "#43a047"
    }, {
        "id": "blue",
        "c": "#1e88e5"
    }, {
        "id": "purple",
        "c": "#8e24aa"
    }, {
        "id": "accent",
        "c": Theme.toHex(Theme.accent)
    }, {
        "id": "white",
        "c": "#ffffff"
    }, {
        "id": "black",
        "c": "#141414"
    }]
    readonly property var tools: [{
        "id": "pen",
        "label": "Pen",
        "icon": "ink_pen"
    }, {
        "id": "marker",
        "label": "Highlight",
        "icon": "ink_highlighter"
    }, {
        "id": "arrow",
        "label": "Arrow",
        "icon": "arrow_outward"
    }, {
        "id": "line",
        "label": "Line",
        "icon": "pen_size_2"
    }, {
        "id": "rect",
        "label": "Box",
        "icon": "rectangle"
    }, {
        "id": "ellipse",
        "label": "Ring",
        "icon": "circle"
    }, {
        "id": "text",
        "label": "Text",
        "icon": "text_fields"
    }, {
        "id": "redact",
        "label": "Hide",
        "icon": "blur_on"
    }, {
        "id": "eraser",
        "label": "Erase",
        "icon": "ink_eraser"
    }]
    readonly property var ratios: [{
        "id": "free",
        "label": "Free"
    }, {
        "id": "original",
        "label": "Original"
    }, {
        "id": "1:1",
        "label": "Square"
    }, {
        "id": "4:3",
        "label": "4:3"
    }, {
        "id": "3:2",
        "label": "3:2"
    }, {
        "id": "16:9",
        "label": "16:9"
    }, {
        "id": "screen",
        "label": "Screen"
    }]

    function lookOf(id) {
        for (var i = 0; i < panel.looks.length; i++) {
            if (panel.looks[i].id === id)
                return panel.looks[i];

        }
        return null;
    }

    // a look at some strength: each of its adjustments scaled
    function scaled(look, k) {
        var out = {};
        for (var key in look.a) out[key] = Math.round(look.a[key] * k)
        return out;
    }

    function useLook(id) {
        var look = panel.lookOf(id);
        if (!look)
            return ;

        var k = (panel.e.strength === undefined ? 100 : panel.e.strength) / 100;
        panel.win.change({
            "adjust": panel.scaled(look, id === "" ? 1 : k),
            "filter": id,
            "strength": id === "" ? 100 : Math.round(k * 100)
        });
    }

    function setStrength(v, dragging) {
        var look = panel.lookOf(panel.e.filter || "");
        if (!look || look.id === "")
            return ;

        var patch = {
            "adjust": panel.scaled(look, v / 100),
            "filter": look.id,
            "strength": Math.round(v)
        };
        if (dragging)
            panel.win.live(patch);
        else {
            panel.win.live(patch);
            panel.win.settled();
        }
    }

    // a quick fix from the histogram: the middle tones lifted or eased, more
    // contrast where it is flat, and a touch more colour
    function auto() {
        var st = panel.win.info && panel.win.info.histogram ? panel.win.info.histogram.stats : null;
        if (!st) {
            panel.win.say("Still looking at the picture…");
            return ;
        }
        var spread = st.hi - st.lo;
        var clamp = function(v, lo, hi) {
            return Math.round(Math.max(lo, Math.min(hi, v)));
        };
        var a = Object.assign({}, panel.a);
        a.exposure = clamp((0.46 - st.mean) * 110, -45, 45);
        a.contrast = clamp((0.86 - spread) * 70, 0, 35);
        a.shadows = clamp(st.lo > 0.1 ? -(st.lo - 0.1) * 80 : (0.25 - st.mean) * 40, -20, 25);
        a.highlights = clamp(st.hi < 0.9 ? (0.9 - st.hi) * 60 : -(st.hi - 0.97) * 300, -25, 20);
        a.vibrance = Math.max(a.vibrance || 0, 18);
        panel.win.change({
            "adjust": a,
            "filter": ""
        });
    }

    color: Theme.withBlur(Theme.bgSunken)
    radius: Theme.shapeXl
    clip: true

    Item {
        id: sheet

        x: panel.width - panel.fullW
        width: panel.fullW
        height: parent.height

        Tabs {
            id: tabBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Theme.dp(8)
            anchors.rightMargin: Theme.dp(8)
            anchors.topMargin: Theme.dp(6)
            options: panel.tabs
            current: panel.win.tab
            onPicked: (key) => {
                return panel.win.tab = key;
            }
        }

        Rectangle {
            anchors.top: tabBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.divider
        }

        // the four pages side by side, the open one slid into view
        Item {
            id: pages

            anchors.top: tabBar.bottom
            anchors.topMargin: 1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true

            Row {
                id: pageRow

                x: -panel.tabIndex * pages.width
                height: pages.height

                Behavior on x {
                    NumberAnimation {
                        duration: Theme.durMedium
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

                Page {
                    // crop and turn
                    Column {
                        width: parent.width
                        spacing: Theme.dp(18)

                        Heading {
                            text: "Shape"
                        }

                        Flow {
                            width: parent.width
                            spacing: Theme.dp(8)

                            Repeater {
                                model: panel.ratios

                                delegate: Chip {
                                    required property var modelData

                                    kind: "filter"
                                    text: modelData.label
                                    selected: panel.app.prefs.cropRatio === modelData.id
                                    onClicked: panel.app.prefs.cropRatio = modelData.id
                                }

                            }

                            IconButton {
                                icon: "crop_rotate"
                                tooltip: panel.win.cropPortrait ? "Make it wide" : "Make it tall"
                                variant: "tonal"
                                checkable: true
                                checked: panel.win.cropPortrait
                                disabled: ["free", "1:1"].indexOf(panel.app.prefs.cropRatio) >= 0

                                Tip {
                                }

                                onClicked: panel.win.cropPortrait = !panel.win.cropPortrait
                            }

                        }

                        Heading {
                            text: "Turn"
                        }

                        Row {
                            spacing: Theme.dp(8)

                            IconButton {
                                variant: "tonal"
                                size: "m"
                                icon: "rotate_left"
                                tooltip: "Rotate left"

                                Tip {
                                }

                                onClicked: panel.win.turn(-1)
                            }

                            IconButton {
                                variant: "tonal"
                                size: "m"
                                icon: "rotate_right"
                                tooltip: "Rotate right"

                                Tip {
                                }

                                onClicked: panel.win.turn(1)
                            }

                            IconButton {
                                variant: "tonal"
                                size: "m"
                                icon: "flip"
                                tooltip: "Flip side to side"

                                Tip {
                                }

                                onClicked: panel.win.flip(true)
                            }

                            IconButton {
                                variant: "tonal"
                                size: "m"
                                icon: "flip"
                                rotation: 90
                                tooltip: "Flip upside down"

                                Tip {
                                }

                                onClicked: panel.win.flip(false)
                            }

                        }

                        AdjustSlider {
                            width: parent.width
                            label: "Straighten"
                            from: -45
                            to: 45
                            stepSize: 0.5
                            decimals: 1
                            unit: "°"
                            value: panel.e.angle || 0
                            onDraggingChanged: panel.win.straightening = dragging
                            onChanging: (v) => {
                                return panel.win.live({
                                    "angle": v
                                });
                            }
                            onChanged: (v) => {
                                panel.win.live({
                                    "angle": v
                                });
                                panel.win.settled();
                            }
                        }

                        LText {
                            width: parent.width
                            role: "bodyMedium"
                            color: Theme.subtext
                            wrapMode: Text.Wrap
                            text: "Drag the corners or the edges to crop, or drag inside to move the crop. Shift keeps its shape."
                        }

                        Button {
                            variant: "outlined"
                            icon: "restart_alt"
                            text: "Reset the crop"
                            disabled: !panel.e.crop && !panel.e.angle && !panel.e.turns && !panel.e.flipH && !panel.e.flipV
                            onClicked: panel.win.change({
                                "crop": null,
                                "angle": 0,
                                "turns": 0,
                                "flipH": false,
                                "flipV": false
                            })
                        }

                    }

                }

                Page {
                    // light and colour
                    Column {
                        width: parent.width
                        spacing: Theme.dp(14)

                        Button {
                            variant: "tonal"
                            icon: "auto_fix_high"
                            text: "Auto"
                            onClicked: panel.auto()
                        }

                        Heading {
                            text: "Light"
                        }

                        Adjuster {
                            key: "exposure"
                            label: "Exposure"
                        }

                        Adjuster {
                            key: "contrast"
                            label: "Contrast"
                        }

                        Adjuster {
                            key: "highlights"
                            label: "Highlights"
                        }

                        Adjuster {
                            key: "shadows"
                            label: "Shadows"
                        }

                        Heading {
                            text: "Colour"
                        }

                        Adjuster {
                            key: "saturation"
                            label: "Saturation"
                        }

                        Adjuster {
                            key: "vibrance"
                            label: "Vibrance"
                        }

                        Adjuster {
                            key: "warmth"
                            label: "Warmth"
                        }

                        Adjuster {
                            key: "tint"
                            label: "Tint"
                        }

                        Heading {
                            text: "Finish"
                        }

                        Adjuster {
                            key: "fade"
                            label: "Fade"
                            from: 0
                        }

                        Adjuster {
                            key: "vignette"
                            label: "Vignette"
                        }

                        Adjuster {
                            key: "mono"
                            label: "Black and white"
                            from: 0
                        }

                    }

                }

                Page {
                    // looks
                    Column {
                        width: parent.width
                        spacing: Theme.dp(16)

                        Grid {
                            id: lookGrid

                            readonly property real cw: (width - 2 * columnSpacing) / 3

                            width: parent.width
                            columns: 3
                            columnSpacing: Theme.dp(10)
                            rowSpacing: Theme.dp(12)

                            Repeater {
                                model: panel.looks

                                delegate: Item {
                                    id: look

                                    required property var modelData
                                    readonly property bool on: (panel.e.filter || "") === look.modelData.id

                                    width: lookGrid.cw
                                    height: lookGrid.cw + Theme.dp(26)

                                    ClippingRectangle {
                                        id: frame

                                        width: lookGrid.cw
                                        height: lookGrid.cw
                                        radius: look.on ? Theme.radiusLg : Theme.radiusMd
                                        color: Theme.surfaceHigh
                                        scale: lookArea.pressed ? 0.94 : 1

                                        // the picture itself, in this look
                                        Picture {
                                            id: lookPic

                                            readonly property real k: lookPic.width > 0 ? Math.max(frame.width / lookPic.width, frame.height / lookPic.height) : 1

                                            x: (frame.width - lookPic.width * k) / 2
                                            y: (frame.height - lookPic.height * k) / 2
                                            transformOrigin: Item.TopLeft
                                            scale: k
                                            source: panel.win.current && panel.win.current.thumb ? "file://" + panel.win.current.thumb : ""
                                            edits: ({
                                                "turns": panel.e.turns,
                                                "flipH": panel.e.flipH,
                                                "flipV": panel.e.flipV,
                                                "angle": panel.e.angle,
                                                "crop": panel.e.crop,
                                                "adjust": panel.scaled(look.modelData, look.modelData.id === "" ? 1 : (panel.e.strength === undefined || !look.on ? 1 : panel.e.strength / 100)),
                                                "marks": []
                                            })
                                        }

                                        Behavior on radius {
                                            NumberAnimation {
                                                duration: Theme.durFastSpatial
                                                easing.type: Easing.Bezier
                                                easing.bezierCurve: Theme.curveDefaultSpatial
                                            }

                                        }

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: Theme.durFastSpatial
                                                easing.type: Easing.Bezier
                                                easing.bezierCurve: Theme.curveFastSpatial
                                            }

                                        }

                                    }

                                    Rectangle {
                                        anchors.centerIn: frame
                                        width: frame.width + Theme.dp(6)
                                        height: frame.height + Theme.dp(6)
                                        radius: frame.radius + Theme.dp(3)
                                        color: "transparent"
                                        border.width: Theme.dp(2)
                                        border.color: Theme.accent
                                        visible: look.on
                                    }

                                    LText {
                                        anchors.horizontalCenter: frame.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        role: "labelMedium"
                                        text: look.modelData.name
                                        color: look.on ? Theme.accent : Theme.text
                                    }

                                    MouseArea {
                                        id: lookArea

                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: panel.useLook(look.modelData.id)
                                    }

                                }

                            }

                        }

                        AdjustSlider {
                            width: parent.width
                            visible: (panel.e.filter || "") !== ""
                            label: "Strength"
                            from: 0
                            to: 100
                            origin: 0
                            unit: "%"
                            value: panel.e.strength === undefined ? 100 : panel.e.strength
                            onChanging: (v) => {
                                return panel.setStrength(v, true);
                            }
                            onChanged: (v) => {
                                return panel.setStrength(v, false);
                            }
                        }

                        LText {
                            width: parent.width
                            role: "bodyMedium"
                            color: Theme.subtext
                            wrapMode: Text.Wrap
                            text: "A look sets the adjustments; fine-tune it under Adjust."
                        }

                    }

                }

                Page {
                    // drawing
                    Column {
                        width: parent.width
                        spacing: Theme.dp(18)

                        Grid {
                            id: toolGrid

                            readonly property real cw: (width - 2 * columnSpacing) / 3

                            width: parent.width
                            columns: 3
                            columnSpacing: Theme.dp(6)
                            rowSpacing: Theme.dp(6)

                            Repeater {
                                model: panel.tools

                                delegate: Rectangle {
                                    id: tool

                                    required property var modelData
                                    readonly property bool on: panel.app.prefs.tool === tool.modelData.id

                                    width: toolGrid.cw
                                    height: Theme.dp(64)
                                    radius: tool.on ? Theme.radiusLg : Theme.radiusMd
                                    color: tool.on ? Theme.secondaryContainer : Theme.surfaceHigh

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: Theme.dp(4)

                                        Icon {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            name: tool.modelData.icon
                                            size: Theme.dp(22)
                                            fill: tool.on ? 1 : 0
                                            color: tool.on ? Theme.fgSecondaryContainer : Theme.subtext
                                        }

                                        LText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            role: "labelMedium"
                                            text: tool.modelData.label
                                            color: tool.on ? Theme.fgSecondaryContainer : Theme.text
                                        }

                                    }

                                    MouseArea {
                                        id: toolArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: panel.app.prefs.tool = tool.modelData.id
                                    }

                                    HoverLayer {
                                        area: toolArea
                                    }

                                    Behavior on radius {
                                        NumberAnimation {
                                            duration: Theme.durFastSpatial
                                            easing.type: Easing.Bezier
                                            easing.bezierCurve: Theme.curveDefaultSpatial
                                        }

                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.durShort
                                        }

                                    }

                                }

                            }

                        }

                        Heading {
                            text: "Colour"
                            visible: ["redact", "eraser"].indexOf(panel.app.prefs.tool) < 0
                        }

                        Flow {
                            width: parent.width
                            spacing: Theme.dp(6)
                            visible: ["redact", "eraser"].indexOf(panel.app.prefs.tool) < 0

                            Repeater {
                                model: panel.inks

                                delegate: Item {
                                    id: ink

                                    required property var modelData
                                    readonly property bool on: panel.app.prefs.ink === ink.modelData.id

                                    width: Theme.dp(34)
                                    height: Theme.dp(34)

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Theme.dp(32)
                                        height: width
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: Theme.dp(2)
                                        border.color: ink.modelData.c
                                        opacity: ink.on ? 1 : 0
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Theme.dp(24)
                                        height: width
                                        radius: width / 2
                                        color: ink.modelData.c
                                        border.width: 1
                                        border.color: Theme.alpha(Theme.text, 0.16)
                                        scale: inkArea.pressed ? 0.86 : inkArea.containsMouse ? 1.1 : 1

                                        Icon {
                                            anchors.centerIn: parent
                                            visible: ink.on
                                            name: "check"
                                            size: Theme.dp(16)
                                            color: ink.modelData.id === "white" || ink.modelData.id === "yellow" ? "#141414" : "#ffffff"
                                        }

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: Theme.durFastSpatial
                                                easing.type: Easing.Bezier
                                                easing.bezierCurve: Theme.curveFastSpatial
                                            }

                                        }

                                    }

                                    MouseArea {
                                        id: inkArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: panel.app.prefs.ink = ink.modelData.id
                                    }

                                }

                            }

                        }

                        Heading {
                            text: "Size"
                            visible: panel.app.prefs.tool !== "eraser"
                        }

                        // five sizes, each shown as the dot it draws
                        Row {
                            spacing: Theme.dp(6)
                            visible: panel.app.prefs.tool !== "eraser"

                            Repeater {
                                model: 5

                                delegate: Rectangle {
                                    id: size

                                    required property int index
                                    readonly property bool on: panel.app.prefs.inkSize === size.index

                                    width: Theme.dp(48)
                                    height: Theme.dp(40)
                                    radius: size.on ? Theme.radiusMd : height / 2
                                    color: size.on ? Theme.secondaryContainer : Theme.surfaceHigh

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Theme.dp([4, 7, 11, 16, 22][size.index])
                                        height: width
                                        radius: width / 2
                                        color: size.on ? Theme.fgSecondaryContainer : Theme.subtext
                                    }

                                    MouseArea {
                                        id: sizeArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: panel.app.prefs.inkSize = size.index
                                    }

                                    HoverLayer {
                                        area: sizeArea
                                    }

                                }

                            }

                        }

                        Row {
                            width: parent.width
                            spacing: Theme.dp(12)
                            visible: ["rect", "ellipse", "text"].indexOf(panel.app.prefs.tool) >= 0

                            LText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - fillSwitch.width - Theme.dp(12)
                                role: "bodyLarge"
                                text: panel.app.prefs.tool === "text" ? "Put the words on a label" : "Fill the shape"
                            }

                            Switch {
                                id: fillSwitch

                                anchors.verticalCenter: parent.verticalCenter
                                checked: panel.app.prefs.fillShapes
                                onToggled: (v) => {
                                    return panel.app.prefs.fillShapes = v;
                                }
                            }

                        }

                        LText {
                            width: parent.width
                            role: "bodyMedium"
                            color: Theme.subtext
                            wrapMode: Text.Wrap
                            text: panel.app.prefs.tool === "text" ? "Click where the words go, type, then press Enter." : panel.app.prefs.tool === "redact" ? "Drag over what should be hidden: it is drawn back in blocks too coarse to read." : panel.app.prefs.tool === "eraser" ? "Click a drawing to take it away." : "Draw on the picture. Ctrl+Z takes the last mark back. Shift keeps a line straight and a shape even."
                        }

                        Button {
                            variant: "outlined"
                            icon: "delete"
                            text: "Clear the drawings"
                            disabled: !panel.e.marks || panel.e.marks.length === 0
                            onClicked: panel.win.change({
                                "marks": []
                            })
                        }

                    }

                }

            }

        }

    }

    component Page: Flickable {
        width: pages.width
        height: pages.height
        contentHeight: inner.implicitHeight + Theme.dp(40)
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        default property alias content: inner.data

        Column {
            id: inner

            x: Theme.dp(20)
            y: Theme.dp(18)
            width: parent.width - Theme.dp(40)
        }

    }

    component Heading: LText {
        role: "labelLarge"
        color: Theme.accent
    }

    component Adjuster: AdjustSlider {
        property string key: ""

        width: parent ? parent.width : 0
        value: panel.a[key] || 0
        onChanging: (v) => {
            return panel.win.setAdjust(key, v, true);
        }
        onChanged: (v) => {
            panel.win.setAdjust(key, v, true);
            panel.win.settled();
        }
    }

}
