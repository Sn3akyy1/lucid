import QtQuick
import QtQuick.Effects
import qs
import qs.lucidui

// the lock screen's style editor, full screen: the frosted wallpaper, the lock
// itself large in the middle, a bar of what is being edited over it and the
// styles under it. the arrows step through the styles; a widget on the preview
// can be dragged anywhere, or clicked for its options at the side. it all works
// on a draft (LockStyle.draft): Apply keeps it, closing drops it
Item {
    id: ed

    // 0 gone .. 1 up, from the window
    property real k: 0
    property string selected: ""
    // the slot whose + was pressed, while the list of widgets is up
    property string adding: ""
    property bool login: false
    property bool typing: false
    // the side sheet with every slot in it, opened from the bar
    property bool widgetsOpen: LockStyle.editorSheet === "widgets"
    property bool stylesOpen: false
    // closing with changes asks first
    property bool confirming: false
    readonly property var stage: lp.surface.stage
    readonly property bool sideOpen: ed.selected !== "" || ed.adding !== "" || ed.widgetsOpen
    readonly property var presets: LockStyle.presets
    readonly property int index: Math.max(0, ed.presets.findIndex((p) => {
        return p.id === LockStyle.preset;
    }))
    readonly property var current: LockStyle.presetInfo(LockStyle.preset)
    readonly property bool inUse: LockStyle.preset === LockStyle.layout.preset
    property real useK: ed.inUse ? 1 : 0
    // the widgets' own chrome (outlines, + and tags) is up only while they are
    // being edited: browsing the styles shows each one clean, as it would lock
    readonly property bool widgetMode: ed.sideOpen || ed.outType !== ""
    // ── room ───────────────────────────────────────────────────────────────
    readonly property real topH: Theme.dp(100)
    readonly property real footH: Theme.dp(76)
    readonly property real gutter: Theme.dp(124)
    readonly property real sheetW: Theme.dp(360)
    readonly property real stripH: thumbs.height + Theme.dp(34)
    property real sideK: ed.sideOpen ? 1 : 0
    property real stylesK: ed.stylesOpen ? 1 : 0
    // the card: the screen's own shape, as large as the room around it allows
    readonly property rect card: {
        var aw = ed.width - ed.gutter * 2 - ed.sideK * (ed.sheetW + Theme.dp(24));
        var ah = ed.height - ed.topH - ed.footH - ed.stylesK * ed.stripH;
        var w = Math.max(10, Math.min(aw, ah * lp.aspect));
        var h = w / lp.aspect;
        return Qt.rect(ed.gutter + (aw - w) / 2, ed.topH + (ah - h) / 2, w, h);
    }
    // ── a widget in the air ────────────────────────────────────────────────
    property string outType: ""
    readonly property bool dragging: ed.outType !== "" || (!!ed.stage && ed.stage.dragType !== "")
    readonly property var dragInfo: {
        var t = ed.outType !== "" ? ed.outType : (ed.stage ? ed.stage.dragType : "");
        return t !== "" ? LockStyle.widgetInfo(t) : null;
    }
    readonly property string dragName: ed.dragInfo ? ed.dragInfo.name : ""
    property point dragAt: Qt.point(-1, -1)
    property real dragK: ed.dragging ? 1 : 0
    readonly property bool overRemove: ed.dragging && ed.dragAt.x >= bin.x && ed.dragAt.x <= bin.x + bin.width && ed.dragAt.y >= bin.y - Theme.dp(14) && ed.dragAt.y <= bin.y + bin.height + Theme.dp(14)
    // what LucidShot's window mode can take while the editor hides the windows:
    // the lock itself, cut to the card's own corners, and the sheet when it is out
    readonly property var shotTargets: {
        if (ed.k < 0.99)
            return [];

        var out = [{
            "x": Math.round(lp.x),
            "y": Math.round(lp.y),
            "w": Math.round(lp.width),
            "h": Math.round(lp.height),
            "title": ed.current.name + (ed.login ? I18n.tr(" · login screen") : I18n.tr(" · lock screen")),
            "round": lp.radius
        }];
        if (ed.sideK > 0.99)
            out.unshift({
                "x": Math.round(side.x),
                "y": Math.round(side.y),
                "w": Math.round(side.width),
                "h": Math.round(side.height),
                "title": I18n.tr("Lock screen widgets"),
                "round": side.radius
            });

        return out;
    }
    readonly property string sideKey: ed.adding !== "" ? "add:" + ed.adding : (ed.selected !== "" ? "w:" + ed.selected : "layout:" + LockStyle.preset)

    // the next style along, either way round
    function step(by) {
        var n = ed.presets.length;
        ed.selected = "";
        ed.adding = "";
        LockStyle.setPreset(ed.presets[(ed.index + by + n) % n].id);
    }

    function requestClose() {
        if (LockStyle.dirty)
            ed.confirming = true;
        else
            LockStyle.closeEditor(false);
    }

    function stagePoint(q) {
        return lp.surface.mapFromItem(ed, q.x, q.y);
    }

    function overPreview(q) {
        return q.x >= lp.x && q.x <= lp.x + lp.width && q.y >= lp.y && q.y <= lp.y + lp.height;
    }

    function removeWidget(type) {
        if (LockStyle.placedIn(type) === "")
            return false;

        if (ed.selected === type)
            ed.selected = "";

        LockStyle.remove(type);
        return true;
    }

    // ── a drag from the side sheet ─────────────────────────────────────────
    function beginOutside(type, q) {
        ed.outType = type;
        ed.dragAt = q;
    }

    function moveOutside(q) {
        if (ed.outType === "")
            return ;

        ed.dragAt = q;
        var st = ed.stage;
        if (ed.overPreview(q)) {
            if (st.dragType === "") {
                var m = st.memo[ed.outType];
                var size = m ? Qt.size(m.w, m.h) : Qt.size(st.dp(280), st.dp(96));
                st.beginDrag(ed.outType, LockStyle.placedIn(ed.outType), Qt.point(size.width / 2, size.height / 2), size, true);
            }
            st.moveDrag(ed.stagePoint(q));
        } else if (st.dragType !== "") {
            st.moveDrag(Qt.point(-100000, -100000));
        }
    }

    function endOutside(q) {
        if (ed.outType === "")
            return ;

        var type = ed.outType;
        ed.dragAt = q;
        if (ed.stage.dragType !== "")
            ed.stage.endDrag(ed.overPreview(q) ? ed.stagePoint(q) : Qt.point(-100000, -100000));
        else if (ed.overRemove)
            ed.removeWidget(type);
        ed.outType = "";
        ed.dragAt = Qt.point(-1, -1);
    }

    function cancelOutside() {
        if (ed.stage && ed.stage.dragType !== "")
            ed.stage.cancelDrag();

        ed.outType = "";
        ed.dragAt = Qt.point(-1, -1);
    }

    onSideKeyChanged: sideIn.restart()
    onShotTargetsChanged: LockStyle.shotTargets = ed.shotTargets
    Component.onCompleted: {
        // let go on nothing: over the bin it is removed, anywhere else it goes back
        lp.surface.dropOutside = (type, at) => {
            return ed.overRemove ? ed.removeWidget(type) : false;
        };
        keys.forceActiveFocus();
    }

    Behavior on sideK {
        NumberAnimation {
            duration: Theme.ms(460)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    Behavior on useK {
        NumberAnimation {
            duration: Theme.ms(260)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveEffects
        }

    }

    Behavior on stylesK {
        NumberAnimation {
            duration: Theme.ms(460)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    Behavior on dragK {
        NumberAnimation {
            duration: Theme.ms(240)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveEffects
        }

    }

    Connections {
        function onOpened() {
            ed.widgetsOpen = true;
        }

        function onPicked(type) {
            ed.widgetsOpen = true;
            ed.adding = "";
            ed.selected = ed.selected === type ? "" : type;
        }

        function onSlotPicked(slot) {
            ed.widgetsOpen = true;
            ed.selected = "";
            ed.adding = slot;
        }

        function onDropped(type, slot, index) {
            LockStyle.move(type, slot, index);
            ed.adding = "";
            ed.selected = type;
        }

        function onDragMoved(type, at) {
            if (ed.outType === "")
                ed.dragAt = ed.mapFromItem(lp.surface, at.x, at.y);

        }

        target: lp
    }

    Connections {
        // the close bind, from outside: ask first if there is anything to lose
        function onDismissRequested() {
            if (ed.confirming)
                return ;

            ed.requestClose();
        }

        target: LockStyle
    }

    // ── the backdrop: the wallpaper, frosted and dimmed ─────────────────────
    Item {
        id: paperBox

        anchors.fill: parent
        visible: false

        Image {
            anchors.fill: parent
            source: "file://" + encodeURI(Lockscreen.wallpaper)
            fillMode: Image.PreserveAspectCrop
            // it is blurred to nothing: a small decode is plenty
            sourceSize.width: 960
            asynchronous: true
            cache: true
        }

    }

    MultiEffect {
        anchors.fill: parent
        source: paperBox
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: 1
        opacity: ed.k
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.cScrim
        opacity: ed.k * 0.5

        // a click off everything closes whatever sheet is out
        MouseArea {
            anchors.fill: parent
            onClicked: {
                ed.selected = "";
                ed.adding = "";
                ed.widgetsOpen = false;
                ed.stylesOpen = false;
                keys.forceActiveFocus();
            }
            onWheel: (wheel) => {
                return wheel.accepted = true;
            }
        }

    }

    Item {
        id: keys

        focus: true
        Keys.onEscapePressed: {
            if (ed.dragging)
                return ;

            if (ed.confirming)
                ed.confirming = false;
            else if (ed.adding !== "")
                ed.adding = "";
            else if (ed.selected !== "")
                ed.selected = "";
            else if (ed.widgetsOpen)
                ed.widgetsOpen = false;
            else if (ed.stylesOpen)
                ed.stylesOpen = false;
            else
                ed.requestClose();
        }
        Keys.onLeftPressed: ed.step(-1)
        Keys.onRightPressed: ed.step(1)
        Keys.onReturnPressed: LockStyle.closeEditor(true)
        Keys.onEnterPressed: LockStyle.closeEditor(true)
        Keys.onDeletePressed: {
            if (ed.selected !== "" && ed.selected !== "auth") {
                LockStyle.remove(ed.selected);
                ed.selected = "";
            }
        }
    }

    // ── the lock, large, at the heart of it ─────────────────────────────────
    LockPreview {
        id: lp

        x: ed.card.x
        y: ed.card.y
        width: ed.card.width
        height: ed.card.height
        radius: Theme.rad(36)
        layout: LockStyle.work
        greeterLook: ed.login
        previewFocus: ed.typing
        editing: ed.widgetMode
        selected: ed.selected
        opacity: ed.k
        scale: 0.9 + 0.1 * ed.k

        transform: Translate {
            y: (1 - ed.k) * Theme.dp(48)
        }

    }

    // ── the bar along the top ───────────────────────────────────────────────
    Item {
        id: bar

        x: Theme.dp(40)
        width: ed.width - Theme.dp(80)
        height: Theme.dp(64)
        y: Theme.dp(22) - (1 - ed.k) * Theme.dp(24)
        opacity: ed.k

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(14)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "lock"
                size: Theme.dp(26)
                color: Theme.text
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: Theme.dp(10)
                text: I18n.tr("Lock screen style")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitleLg
                font.variableAxes: Theme.axes(Theme.fontTitleLg, 500, 0)
                font.weight: Font.Medium
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(4)

                LockStyleChoice {
                    icon: "lock"
                    label: I18n.tr("Lock screen")
                    on: !ed.login
                    onClicked: ed.login = false
                }

                LockStyleChoice {
                    icon: "login"
                    label: I18n.tr("Login screen")
                    on: ed.login
                    onClicked: ed.login = true
                }

            }

        }

        // the style on show, by name, and what kind of style it is
        Row {
            anchors.centerIn: parent
            spacing: Theme.dp(10)

            Text {
                anchors.baseline: kindText.baseline
                text: ed.current.name
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitleLg
                font.variableAxes: Theme.axes(Theme.fontTitleLg, 560, 0)
                font.weight: Font.DemiBold
            }

            Text {
                id: kindText

                anchors.verticalCenter: parent.verticalCenter
                text: ed.current.kind || ""
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyLg
                font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
            }

            // in use: the style the lock wears now
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: (useRow.implicitWidth + Theme.dp(24)) * ed.useK
                height: Theme.dp(32)
                radius: height / 2
                color: Theme.accentContainer
                opacity: ed.useK
                visible: ed.useK > 0.01
                clip: true

                Row {
                    id: useRow

                    anchors.centerIn: parent
                    spacing: Theme.dp(6)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "check_circle"
                        size: Theme.dp(17)
                        fill: 1
                        color: Theme.fgAccentContainer
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("In use")
                        color: Theme.fgAccentContainer
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelLg
                        font.variableAxes: Theme.axes(Theme.fontLabelLg, 560, 0)
                        font.weight: Font.Medium
                    }

                }

            }

        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(10)
            visible: !ed.confirming

            // the lock as it looks with a password being typed
            LockStyleChoice {
                anchors.verticalCenter: parent.verticalCenter
                icon: "keyboard"
                label: I18n.tr("Typing")
                on: ed.typing
                onClicked: ed.typing = !ed.typing
            }

            LockStyleChoice {
                anchors.verticalCenter: parent.verticalCenter
                icon: ed.widgetMode ? "check" : "edit"
                label: ed.widgetMode ? I18n.tr("Done") : I18n.tr("Edit widgets")
                on: ed.widgetMode
                onClicked: {
                    var going = ed.widgetMode;
                    ed.selected = "";
                    ed.adding = "";
                    ed.widgetsOpen = !going;
                    keys.forceActiveFocus();
                }
            }

            LockStyleRound {
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                size: Theme.dp(48)
                onClicked: ed.requestClose()
            }

            // m3 filled button, the way out that keeps the draft
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: applyRow.implicitWidth + Theme.dp(44)
                height: Theme.dp(52)
                radius: applyArea.containsMouse ? Theme.shapeLg : height / 2
                color: applyArea.containsMouse ? Theme.accentHover : Theme.accent
                scale: applyArea.pressed ? 0.95 : 1

                Row {
                    id: applyRow

                    anchors.centerIn: parent
                    spacing: Theme.dp(8)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "check"
                        size: Theme.dp(20)
                        color: Theme.fgAccent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Apply")
                        color: Theme.fgAccent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitleSm
                        font.variableAxes: Theme.axes(Theme.fontTitleSm, 600, 0)
                        font.weight: Font.DemiBold
                    }

                }

                MouseArea {
                    id: applyArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LockStyle.closeEditor(true)
                }

                Behavior on radius {
                    NumberAnimation {
                        duration: Theme.ms(220)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveFastSpatial
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.ms(120)
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        // closing with changes: drop them, or keep editing
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(10)
            visible: ed.confirming

            Text {
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: Theme.dp(6)
                text: I18n.tr("Drop these changes?")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyLg
                font.variableAxes: Theme.axes(Theme.fontBodyLg, 480, 0)
            }

            M3Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "text"
                text: I18n.tr("Keep editing")
                onClicked: ed.confirming = false
            }

            M3Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "tonal"
                destructive: true
                iconPath: "delete"
                text: I18n.tr("Drop them")
                onClicked: {
                    ed.confirming = false;
                    LockStyle.closeEditor(false);
                }
            }

        }

    }

    // ── through the styles, either way round ────────────────────────────────
    LockStyleRound {
        x: (lp.x - width) / 2
        y: lp.y + (lp.height - height) / 2
        size: Theme.dp(60)
        icon: "chevron_left"
        opacity: ed.k * (1 - ed.dragK)
        visible: opacity > 0.01
        onClicked: ed.step(-1)
    }

    LockStyleRound {
        x: lp.x + lp.width + (ed.gutter - width) / 2
        y: lp.y + (lp.height - height) / 2
        size: Theme.dp(60)
        icon: "chevron_right"
        opacity: ed.k * (1 - ed.dragK)
        visible: opacity > 0.01
        onClicked: ed.step(1)
    }

    // ── every style, in a strip that rises from under the card ──────────────
    Item {
        id: strip

        x: lp.x
        y: ed.height - ed.footH - ed.stripH + Theme.dp(10)
        width: lp.width
        height: thumbs.height
        opacity: ed.k * ed.stylesK * (1 - ed.dragK)
        visible: opacity > 0.01

        transform: Translate {
            y: (1 - ed.stylesK) * Theme.dp(24)
        }

        Row {
            id: thumbs

            readonly property real tileW: Math.min(Theme.dp(170), (strip.width - spacing * (ed.presets.length - 1)) / ed.presets.length)

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.dp(14)

            Repeater {
                model: ed.presets

                LockPresetThumb {
                    required property var modelData

                    width: thumbs.tileW
                    preset: modelData.id
                    name: modelData.name
                    current: LockStyle.preset === modelData.id
                    onChosen: {
                        ed.selected = "";
                        ed.adding = "";
                        LockStyle.setPreset(modelData.id);
                    }
                }

            }

        }

    }

    // the handle that brings the strip up, or puts it away
    Rectangle {
        id: handle

        x: (ed.width - width) / 2 - ed.sideK * (ed.sheetW + Theme.dp(24)) / 2
        y: ed.height - ed.footH + (ed.footH - height) / 2 + (1 - ed.k) * Theme.dp(30)
        width: handleRow.implicitWidth + Theme.dp(36)
        height: Theme.dp(42)
        radius: height / 2
        color: handleArea.containsMouse ? Theme.surfaceHighest : Theme.alpha(Theme.surfaceContainer, 0.9)
        opacity: ed.k * (1 - ed.dragK)
        visible: opacity > 0.01

        Row {
            id: handleRow

            anchors.centerIn: parent
            spacing: Theme.dp(8)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "keyboard_arrow_up"
                size: Theme.dp(20)
                color: Theme.subtext
                rotation: ed.stylesK * 180
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ed.stylesOpen ? I18n.tr("Hide styles") : I18n.trn("%1 style", "%1 styles", ed.presets.length)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.variableAxes: Theme.axes(Theme.fontLabelLg, 540, 0)
                font.weight: Font.Medium
            }

        }

        MouseArea {
            id: handleArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ed.stylesOpen = !ed.stylesOpen
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(140)
            }

        }

    }

    // ── the bin, where the handle was, while something is carried ──────────
    Rectangle {
        id: bin

        x: (ed.width - width) / 2 - ed.sideK * (ed.sheetW + Theme.dp(24)) / 2
        y: ed.height - ed.footH + (ed.footH - height) / 2 - Theme.dp(4)
        width: Theme.dp(420)
        height: Theme.dp(60)
        // m3 expressive: a pill that squares off as a widget reaches it
        radius: ed.overRemove ? Theme.shapeXl : height / 2
        visible: ed.dragK > 0.01
        opacity: ed.dragK
        scale: 0.92 + 0.08 * ed.dragK + (ed.overRemove ? 0.04 : 0)
        color: ed.overRemove ? Theme.error : Theme.alpha(Theme.error, 0.16)

        Row {
            anchors.centerIn: parent
            spacing: Theme.dp(10)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "delete"
                size: Theme.dp(22)
                fill: ed.overRemove ? 1 : 0
                color: ed.overRemove ? Theme.fgError : Theme.error
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ed.overRemove ? I18n.tr("Let go to remove %1", ed.dragName.toLowerCase()) : I18n.tr("Drop here to remove")
                color: ed.overRemove ? Theme.fgError : Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.variableAxes: Theme.axes(Theme.fontLabelLg, 560, 0)
                font.weight: Font.Medium
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(140)
            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: Theme.ms(260)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.ms(220)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

    }

    // ── the side sheet: a widget's options, what can go in a slot, or all of it
    Rectangle {
        id: side

        x: ed.width - (ed.sheetW + Theme.dp(24)) * ed.sideK
        y: ed.topH
        width: ed.sheetW
        height: ed.height - ed.topH - Theme.dp(24)
        radius: Theme.shapeXl
        color: Theme.surfaceContainer
        opacity: ed.k * Math.min(1, ed.sideK * 1.4)
        visible: ed.sideK > 0.01

        // a click inside the sheet stays inside it
        MouseArea {
            anchors.fill: parent
            onWheel: (wheel) => {
                return wheel.accepted = false;
            }
        }

        Flickable {
            id: sideFlick

            anchors.fill: parent
            anchors.margins: Theme.dp(20)
            contentHeight: inspector.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            LockInspector {
                id: inspector

                width: sideFlick.width
                editor: ed

                transform: Translate {
                    id: sideShift
                }

            }

        }

    }

    // a new page in the sheet comes in from the side, as m3's shared axis does
    ParallelAnimation {
        id: sideIn

        NumberAnimation {
            target: sideShift
            property: "x"
            from: Theme.dp(22)
            to: 0
            duration: Theme.ms(320)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

        NumberAnimation {
            target: inspector
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.ms(200)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveEffects
        }

    }

    // ── the chip under the pointer, for a drag from the sheet ───────────────
    Rectangle {
        id: chip

        property real lift: 0

        x: ed.dragAt.x - width / 2
        y: ed.dragAt.y - height / 2
        z: 50
        width: chipRow.implicitWidth + Theme.dp(28)
        height: Theme.dp(44)
        radius: height / 2
        // a drag from the sheet, or one off the card's edge, where the stage's
        // own ghost is clipped away
        visible: ed.outType !== "" || (!!ed.stage && ed.stage.dragType !== "" && ed.dragAt.x >= 0 && !ed.overPreview(ed.dragAt))
        color: Theme.accentContainer
        onVisibleChanged: {
            if (chip.visible)
                chipIn.restart();

        }
        opacity: 0.6 + 0.35 * chip.lift
        scale: 0.85 + 0.15 * chip.lift

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: Theme.dp(8)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: ed.dragInfo ? ed.dragInfo.icon : "widgets"
                size: Theme.dp(19)
                fill: 1
                color: Theme.fgAccentContainer
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ed.dragName
                color: Theme.fgAccentContainer
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.variableAxes: Theme.axes(Theme.fontLabelLg, 560, 0)
                font.weight: Font.Medium
            }

        }

    }

    NumberAnimation {
        id: chipIn

        target: chip
        property: "lift"
        from: 0
        to: 1
        duration: Theme.ms(260)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveFastSpatial
    }

}
