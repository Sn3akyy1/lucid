import QtQuick
import qs
import qs.lucidui

// the editor's side panel: what a picked widget can be, what can go in a
// slot, or, with nothing picked, the layout itself and every slot in it
Column {
    id: insp

    property var editor: null
    readonly property string type: insp.editor ? insp.editor.selected : ""
    readonly property string adding: insp.editor ? insp.editor.adding : ""
    readonly property var info: insp.type !== "" && insp.type !== "auth" ? LockStyle.widgetInfo(insp.type) : null
    readonly property bool login: insp.editor ? insp.editor.login : false
    readonly property string mode: insp.adding !== "" ? "add" : (insp.type === "auth" ? "auth" : (insp.info ? "widget" : "layout"))
    readonly property var preset: LockStyle.presetInfo(LockStyle.preset)
    // the options on offer, rebuilt only when what decides them changes, so a
    // switch is not torn down under the pointer the moment it is flipped
    readonly property string optKey: insp.info ? insp.type + "|" + LockStyle.opt(insp.type, "style") + "|" + insp.login : ""
    property var optList: []

    onOptKeyChanged: insp.optList = insp.info ? LockStyle.optionsFor(insp.type, insp.login) : []

    function slotName(id) {
        var s = LockStyle.slotInfo(id);
        return s ? s.name : id;
    }

    // and again once a language's words arrive, for their names
    Connections {
        function onStringsChanged() {
            insp.optList = insp.info ? LockStyle.optionsFor(insp.type, insp.login) : [];
        }

        target: I18n
    }

    spacing: Theme.dp(18)

    component Heading: Text {
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabelLg
        font.variableAxes: Theme.axes(Theme.fontLabelLg, 600, 0)
        font.weight: Font.DemiBold
    }

    component Body: Text {
        width: insp.width
        wrapMode: Text.Wrap
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyMd
        font.variableAxes: Theme.axes(Theme.fontBodyMd, 420, 0)
        lineHeight: 1.1
    }

    // a tonal mark with a symbol in it, on one of m3's expressive shapes
    component Mark: Item {
        property string icon: "info"
        property string shape: "cookie9"

        width: Theme.dp(40)
        height: width

        MaterialShape {
            anchors.fill: parent
            shape: parent.shape
            color: Theme.accentContainer
        }

        Icon {
            anchors.centerIn: parent
            name: parent.icon
            size: Theme.dp(20)
            fill: 1
            color: Theme.fgAccentContainer
        }

    }

    // ── the header, whatever is showing ─────────────────────────────────────
    Item {
        width: insp.width
        height: Math.max(Theme.dp(44), headCol.implicitHeight)

        Mark {
            id: headMark

            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(44)
            shape: insp.mode === "widget" ? "cookie12" : (insp.mode === "add" ? "clover4" : "cookie9")
            icon: {
                switch (insp.mode) {
                case "add":
                    return "add";
                case "auth":
                    return "lock";
                case "widget":
                    return insp.info.icon;
                }
                return "dashboard";
            }
        }

        Column {
            id: headCol

            anchors.left: headMark.right
            anchors.leftMargin: Theme.dp(12)
            anchors.right: closeBtn.left
            anchors.rightMargin: Theme.dp(6)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(1)

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: {
                    switch (insp.mode) {
                    case "add":
                        return I18n.tr("Add to %1", insp.slotName(insp.adding).toLowerCase());
                    case "auth":
                        return I18n.tr("Sign-in");
                    case "widget":
                        return insp.info.name;
                    }
                    return insp.preset.name;
                }
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitleLg
                font.variableAxes: Theme.axes(Theme.fontTitleLg, 540, 0)
                font.weight: Font.Medium
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: {
                    switch (insp.mode) {
                    case "add":
                        return I18n.tr("Pick a widget to put there");
                    case "auth":
                        return I18n.tr("Part of the layout");
                    case "widget":
                        return insp.info.where === "lock" ? I18n.tr("On the lock screen only") : I18n.tr("On the lock and login screens");
                    }
                    return I18n.tr("Layout");
                }
                color: insp.mode === "widget" && insp.info.where === "lock" ? Theme.warning : Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelMd
                font.variableAxes: Theme.axes(Theme.fontLabelMd, 480, 0)
            }

        }

        M3IconButton {
            id: closeBtn

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.dp(36)
            iconSize: Theme.dp(19)
            iconPath: "close"
            visible: insp.mode !== "layout"
            onClicked: {
                insp.editor.adding = "";
                insp.editor.selected = "";
            }
        }

    }

    // ── nothing picked: the layout and its slots ────────────────────────────
    Column {
        width: insp.width
        spacing: Theme.dp(18)
        visible: insp.mode === "layout"

        Body {
            text: I18n.tr("%1. Drag a widget on the preview to move it, or click it to change it; a + puts another in that place. The widgets below can be dragged onto the preview too.", insp.preset.blurb)
        }

        Repeater {
            model: (insp.preset.options || [])

            Column {
                required property var modelData

                width: insp.width
                spacing: Theme.dp(8)

                Heading {
                    text: modelData.name
                }

                M3Segmented {
                    width: fitWidth
                    current: LockStyle.presetOpt(modelData.key)
                    options: modelData.choices.map((c) => {
                        return {
                            "key": c[0],
                            "label": c[1]
                        };
                    })
                    onChosen: (key) => {
                        return LockStyle.setPresetOpt(modelData.key, key);
                    }
                }

            }

        }

        Heading {
            text: I18n.tr("In this layout")
        }

        Repeater {
            model: insp.preset.slots

            Column {
                id: slotRow

                required property var modelData
                readonly property var types: LockStyle.layout.slots[modelData.id] || []

                width: insp.width
                spacing: Theme.dp(6)

                Text {
                    text: slotRow.modelData.name
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                    font.variableAxes: Theme.axes(Theme.fontLabelLg, 540, 0)
                    font.weight: Font.Medium
                }

                Flow {
                    width: insp.width
                    spacing: Theme.dp(6)

                    Repeater {
                        model: slotRow.types

                        Rectangle {
                            id: chip

                            required property string modelData
                            readonly property var w: LockStyle.widgetInfo(modelData)

                            width: chipRow.implicitWidth + Theme.dp(22)
                            height: Theme.dp(32)
                            radius: Theme.shapeSm
                            color: chipDrag.containsMouse ? Theme.surfaceHighest : Theme.surfaceHigh
                            opacity: chipDrag.carrying ? 0.4 : 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.ms(120)
                                }

                            }

                            Row {
                                id: chipRow

                                anchors.centerIn: parent
                                spacing: Theme.dp(6)

                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: chip.w ? chip.w.icon : "info"
                                    size: Theme.dp(16)
                                    fill: 1
                                    color: Theme.accent
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: chip.w ? chip.w.name : chip.modelData
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontLabelLg
                                    font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
                                    font.weight: Font.Medium
                                }

                            }

                            LockDragSource {
                                id: chipDrag

                                anchors.fill: parent
                                type: chip.modelData
                                editor: insp.editor
                                onTapped: insp.editor.selected = chip.modelData
                            }

                        }

                    }

                    // put another here
                    Rectangle {
                        width: Theme.dp(32)
                        height: Theme.dp(32)
                        radius: Theme.shapeSm
                        color: addHover.hovered ? Theme.accentContainer : "transparent"
                        border.width: 1
                        border.color: Theme.alpha(Theme.accent, 0.5)

                        Icon {
                            anchors.centerIn: parent
                            name: "add"
                            size: Theme.dp(18)
                            color: addHover.hovered ? Theme.fgAccentContainer : Theme.accent
                        }

                        HoverHandler {
                            id: addHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: insp.editor.adding = slotRow.modelData.id
                        }

                    }

                }

            }

        }

        M3Button {
            variant: "tonal"
            iconPath: "restart_alt"
            text: I18n.tr("Reset this layout's widgets")
            onClicked: {
                insp.editor.selected = "";
                LockStyle.resetSlots();
            }
        }

    }

    // ── the sign-in ─────────────────────────────────────────────────────────
    Body {
        visible: insp.mode === "auth"
        text: I18n.tr("The sign-in is part of the layout, so where it sits and how it dresses come with the preset: a card of its own in Split and Bento, straight on the wallpaper in Centre and Minimal, inside the sheet in Panel. Pick another layout below to see it change.")
    }

    // ── a slot's +: everything that could go there ──────────────────────────
    Column {
        width: insp.width
        spacing: Theme.dp(6)
        visible: insp.mode === "add"

        Repeater {
            model: insp.mode === "add" ? LockStyle.widgets : []

            Rectangle {
                id: option

                required property var modelData
                readonly property string at: LockStyle.placedIn(modelData.id)
                readonly property bool here: option.at === insp.adding

                width: insp.width
                height: optRow.implicitHeight + Theme.dp(20)
                radius: Theme.shapeLg
                color: optDrag.containsMouse && !option.here ? Theme.surfaceHighest : Theme.surfaceHigh
                opacity: option.here ? 0.55 : (optDrag.carrying ? 0.4 : 1)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.ms(120)
                    }

                }

                Row {
                    id: optRow

                    x: Theme.dp(12)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.dp(24)
                    spacing: Theme.dp(12)

                    Mark {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: option.modelData.icon
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.dp(52)
                        spacing: Theme.dp(2)

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: option.modelData.name + (option.here ? I18n.tr(" · already here") : (option.at !== "" ? I18n.tr(" · moves from %1", insp.slotName(option.at).toLowerCase()) : ""))
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTitleSm
                            font.variableAxes: Theme.axes(Theme.fontTitleSm, 540, 0)
                            font.weight: Font.Medium
                        }

                        Text {
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: option.modelData.blurb + (option.modelData.where === "lock" ? I18n.tr(". Lock screen only.") : "")
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelMd
                            font.variableAxes: Theme.axes(Theme.fontLabelMd, 450, 0)
                        }

                    }

                }

                // a click puts it in the slot whose + opened this list; a
                // drag takes it to wherever it is let go on the preview
                LockDragSource {
                    id: optDrag

                    anchors.fill: parent
                    enabled: !option.here
                    type: option.modelData.id
                    editor: insp.editor
                    // held in locals first: closing the list destroys this row
                    // before the handler is done with it
                    onTapped: {
                        var ed = insp.editor;
                        var slot = insp.adding;
                        var type = option.modelData.id;
                        LockStyle.add(slot, type);
                        ed.adding = "";
                        ed.selected = type;
                    }
                }

            }

        }

    }

    // ── a widget: its look, its options and its place ───────────────────────
    Column {
        width: insp.width
        spacing: Theme.dp(18)
        visible: insp.mode === "widget"

        Body {
            text: insp.info ? I18n.tr("%1.", insp.info.blurb) : ""
        }

        Column {
            width: insp.width
            spacing: Theme.dp(8)
            visible: !!insp.info && insp.info.styles.length > 1

            Heading {
                text: I18n.tr("Style")
            }

            M3Chips {
                width: insp.width
                current: insp.info ? LockStyle.opt(insp.type, "style") : ""
                options: insp.info ? insp.info.styles.map((s) => {
                    return {
                        "key": s[0],
                        "label": s[1]
                    };
                }) : []
                onChosen: (key) => {
                    return LockStyle.setOpt(insp.type, "style", key);
                }
            }

        }

        Column {
            width: insp.width
            spacing: Theme.dp(8)
            visible: !!insp.info && insp.info.sized === true

            Heading {
                text: I18n.tr("Size")
            }

            M3Segmented {
                width: insp.width
                current: insp.info ? LockStyle.opt(insp.type, "size") : ""
                options: LockStyle.sizes.map((s) => {
                    return {
                        "key": s[0],
                        "label": s[0]
                    };
                })
                onChosen: (key) => {
                    return LockStyle.setOpt(insp.type, "size", key);
                }
            }

        }

        Repeater {
            model: insp.optList

            Column {
                id: optCol

                required property var modelData

                width: insp.width
                spacing: Theme.dp(8)

                // a switch sits beside its name; anything else goes under it
                Item {
                    width: insp.width
                    height: Math.max(optName.implicitHeight, optCol.modelData.type === "bool" ? Theme.dp(32) : 0)

                    Heading {
                        id: optName

                        anchors.verticalCenter: parent.verticalCenter
                        text: optCol.modelData.name
                        color: optCol.modelData.type === "bool" ? Theme.text : Theme.accent
                    }

                    M3Switch {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: optCol.modelData.type === "bool"
                        checked: optCol.modelData.type === "bool" ? LockStyle.opt(insp.type, optCol.modelData.key) === true : false
                        onToggled: (v) => {
                            return LockStyle.setOpt(insp.type, optCol.modelData.key, v);
                        }
                    }

                }

                M3Chips {
                    width: insp.width
                    visible: optCol.modelData.type === "choice"
                    current: optCol.modelData.type === "choice" ? LockStyle.opt(insp.type, optCol.modelData.key) : ""
                    options: optCol.modelData.type === "choice" ? optCol.modelData.choices.map((c) => {
                        return {
                            "key": c[0],
                            "label": c[1]
                        };
                    }) : []
                    onChosen: (key) => {
                        return LockStyle.setOpt(insp.type, optCol.modelData.key, key);
                    }
                }

                M3TextField {
                    width: insp.width
                    visible: optCol.modelData.type === "text"
                    placeholder: I18n.tr("Your message")
                    text: optCol.modelData.type === "text" ? String(LockStyle.opt(insp.type, optCol.modelData.key) || "") : ""
                    onAccepted: (v) => {
                        return LockStyle.setOpt(insp.type, optCol.modelData.key, String(v).slice(0, 160));
                    }
                }

            }

        }

        Column {
            width: insp.width
            spacing: Theme.dp(8)

            Heading {
                text: I18n.tr("Place")
            }

            Item {
                width: insp.width
                height: Theme.dp(40)

                Text {
                    anchors.left: parent.left
                    anchors.right: moves.left
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: I18n.tr("In %1", insp.slotName(LockStyle.placedIn(insp.type)).toLowerCase())
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    font.variableAxes: Theme.axes(Theme.fontBodyMd, 450, 0)
                }

                Row {
                    id: moves

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(4)

                    M3IconButton {
                        size: Theme.dp(40)
                        iconSize: Theme.dp(20)
                        variant: "tonal"
                        iconPath: "arrow_upward"
                        onClicked: LockStyle.nudge(insp.type, -1)
                    }

                    M3IconButton {
                        size: Theme.dp(40)
                        iconSize: Theme.dp(20)
                        variant: "tonal"
                        iconPath: "arrow_downward"
                        onClicked: LockStyle.nudge(insp.type, 1)
                    }

                }

            }

        }

        Row {
            spacing: Theme.dp(8)

            M3Button {
                variant: "tonal"
                destructive: true
                iconPath: "delete"
                text: I18n.tr("Remove")
                onClicked: {
                    var t = insp.type;
                    insp.editor.selected = "";
                    LockStyle.remove(t);
                }
            }

            M3Button {
                variant: "text"
                iconPath: "restart_alt"
                text: I18n.tr("Reset")
                enabled: LockStyle.hasOwnOpts(insp.type)
                onClicked: LockStyle.resetOpts(insp.type)
            }

        }

    }

}
