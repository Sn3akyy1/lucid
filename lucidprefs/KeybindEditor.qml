import QtQuick
import qs

// add or change one keybind, laid over the Settings window
Item {
    id: editor

    property bool shown: false
    property string editingId: ""
    property string keys: ""
    property string desc: ""
    property string category: ""
    property string kind: "exec"
    property string cmd: ""
    property string lua: ""
    property bool each: false
    property var opts: ({})
    // Hyprland is in the empty capture submap for as long as this is set
    property bool recording: false
    // a combo is in; the submap is left once every key is up again, so letting
    // go of Super does not reach a release bind like the launcher's
    property bool awaitingRelease: false
    property string heldMods: ""
    readonly property var optionList: [{
        "key": "locked",
        "label": "Works on the lock screen"
    }, {
        "key": "repeating",
        "label": "Repeats while held"
    }, {
        "key": "release",
        "label": "Fires on release"
    }, {
        "key": "mouse",
        "label": "Mouse drag"
    }, {
        "key": "non_consuming",
        "label": "Key still reaches the app"
    }]
    readonly property string actionText: editor.kind === "lua" ? editor.lua : editor.cmd
    readonly property bool canSave: editor.keys.trim() !== "" && editor.actionText.trim() !== "" && Keybinds.parseError === ""
    // live, against every other enabled bind
    readonly property string clash: {
        if (editor.keys.trim() === "")
            return "";

        var mine = Keybinds.combosOf({
            "keys": editor.keys,
            "each": editor.each ? "workspace" : ""
        });
        var names = [];
        for (var i = 0; i < Keybinds.binds.length; i++) {
            var b = Keybinds.binds[i];
            if (b.id === editor.editingId || b.enabled === false)
                continue;

            if (Keybinds.combosOf(b).some((c) => {
                return mine.indexOf(c) !== -1;
            }))
                names.push("“" + Keybinds.displayDesc(b) + "”");

        }
        return names.length ? "Already used by " + names.join(", ") + " — both would fire." : "";
    }
    readonly property string eachHint: {
        var placeholders = /\{key\}|\{n\}/.test(editor.keys + editor.actionText + editor.desc);
        if (!editor.each)
            return placeholders ? "{key} and {n} only mean something with this on." : "";

        if (editor.keys.indexOf("{key}") === -1)
            return "Put {key} where the number goes, as in SUPER + {key}.";

        return "{key} becomes 1…9 and 0; {n} becomes 1…10 in the action and description.";
    }

    signal dismissed()

    function open(id) {
        var b = id !== "" ? Keybinds.find(id) : null;
        editor.openWith(b, b ? b.id : "");
    }

    // a new bind with some fields already filled in; saving adds it
    function openNew(preset) {
        editor.openWith(preset || null, "");
    }

    function openWith(b, id) {
        // off whatever field had it, so the fields below take their new text
        editor.forceActiveFocus();
        editor.editingId = id;
        editor.keys = b ? String(b.keys || "") : "";
        editor.desc = b ? String(b.desc || "") : "";
        editor.category = b ? String(b.category || "") : "";
        editor.kind = b && b.type === "lua" ? "lua" : "exec";
        editor.cmd = b ? String(b.cmd || "") : "";
        editor.lua = b ? String(b.lua || "") : "";
        editor.each = !!b && b.each === "workspace";
        editor.opts = b && b.opts ? Object.assign({}, b.opts) : {};
        luaEdit.text = editor.lua;
        scroller.contentY = 0;
        editor.shown = true;
    }

    function dismiss() {
        editor.stopRecording();
        if (!editor.shown)
            return ;

        editor.shown = false;
        editor.dismissed();
    }

    function save() {
        if (!editor.canSave)
            return ;

        var entry = editor.editingId !== "" ? Object.assign({}, Keybinds.find(editor.editingId) || {}) : {};
        entry.id = editor.editingId;
        entry.keys = editor.keys.trim();
        entry.desc = editor.desc.trim();
        entry.category = editor.category.trim();
        entry.type = editor.kind;
        entry.cmd = editor.cmd.trim();
        entry.lua = editor.lua.trim();
        entry.each = editor.each ? "workspace" : "";
        entry.opts = editor.opts;
        if (Keybinds.upsert(entry) !== "")
            editor.dismiss();

    }

    function askDelete() {
        var b = Keybinds.find(editor.editingId);
        if (b)
            Prefs.askConfirm("Delete this keybind?", "“" + Keybinds.displayDesc(b) + "” (" + Keybinds.tokens(b.keys).join(" + ") + ") is removed from keybinds.json and Hyprland reloads without it.", "Delete", "keybind-delete:" + b.id);

    }

    function toggleOpt(key) {
        var o = Object.assign({}, editor.opts);
        if (o[key])
            delete o[key];
        else
            o[key] = true;
        editor.opts = o;
    }

    function setEach(on) {
        editor.each = on;
        // SUPER + 1 recorded first, then the repeat switched on
        if (on && /\+\s*[0-9]$/.test(editor.keys))
            editor.keys = editor.keys.replace(/[0-9]$/, "{key}");

    }

    function startRecording() {
        editor.heldMods = "";
        editor.awaitingRelease = false;
        editor.recording = true;
        Keybinds.startCapture();
        captureSink.forceActiveFocus();
    }

    function stopRecording() {
        releaseGuard.stop();
        if (!editor.recording)
            return ;

        editor.recording = false;
        editor.awaitingRelease = false;
        editor.heldMods = "";
        Keybinds.stopCapture();
        editor.forceActiveFocus();
    }

    // the modifiers down once this event is through
    function heldAfter(event, pressed) {
        var m = Keybinds.modsOf(event);
        var k = event.key;
        var mod = (k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R) ? "SUPER" : (k === Qt.Key_Control ? "CTRL" : (k === Qt.Key_Alt ? "ALT" : (k === Qt.Key_Shift ? "SHIFT" : "")));
        var at = m.indexOf(mod);
        if (mod !== "" && pressed && at === -1)
            m.push(mod);

        if (mod !== "" && !pressed && at !== -1)
            m.splice(at, 1);

        return m.join(" + ");
    }

    anchors.fill: parent
    visible: editor.opacity > 0.01
    opacity: editor.shown ? 1 : 0
    Keys.onEscapePressed: editor.dismiss()

    Connections {
        function onCapturingChanged() {
            if (!Keybinds.capturing && editor.recording) {
                editor.recording = false;
                editor.awaitingRelease = false;
                editor.heldMods = "";
                editor.forceActiveFocus();
            }
        }

        target: Keybinds
    }

    Timer {
        id: releaseGuard

        interval: 2500
        onTriggered: editor.stopRecording()
    }

    // every key goes here while recording
    Item {
        id: captureSink

        Keys.onPressed: (event) => {
            event.accepted = true;
            if (!editor.recording)
                return ;

            if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
                editor.stopRecording();
                return ;
            }
            var combo = Keybinds.comboFromEvent(event);
            if (combo === "") {
                if (!editor.awaitingRelease)
                    editor.heldMods = editor.heldAfter(event, true);

                return ;
            }
            if (editor.each)
                combo = combo.replace(/ \+ [0-9]$/, " + {key}");

            editor.keys = combo;
            editor.heldMods = "";
            editor.awaitingRelease = true;
            releaseGuard.restart();
        }
        Keys.onReleased: (event) => {
            event.accepted = true;
            if (!editor.recording || event.isAutoRepeat)
                return ;

            var left = editor.heldAfter(event, false);
            if (editor.awaitingRelease) {
                if (left === "")
                    editor.stopRecording();

            } else {
                editor.heldMods = left;
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.cShadow, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: editor.recording ? editor.stopRecording() : editor.dismiss()
        }

    }

    Rectangle {
        id: card

        readonly property int pad: 28

        anchors.centerIn: parent
        width: Math.min(640, editor.width - 48)
        height: Math.min(editor.height - 48, head.height + body.implicitHeight + 12 + foot.height)
        radius: Theme.shapeXl
        color: Theme.bgHigh
        scale: editor.shown ? 1 : 0.94
        clip: true

        // clicks on the card must not reach the dimmer
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: head

            width: parent.width
            height: 76

            Text {
                x: card.pad
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                text: editor.editingId === "" ? "New keybind" : "Edit keybind"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadlineSm
                font.weight: Font.Medium
            }

        }

        Flickable {
            id: scroller

            anchors.top: head.bottom
            anchors.bottom: foot.top
            anchors.left: parent.left
            anchors.right: parent.right
            contentWidth: width
            contentHeight: body.implicitHeight + 12
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body

                x: card.pad
                width: scroller.width - card.pad * 2
                spacing: 10

                SectionLabel {
                    text: "Keys"
                }

                Rectangle {
                    id: keysPreview

                    readonly property string shownKeys: editor.recording && !editor.awaitingRelease ? (editor.heldMods !== "" ? editor.heldMods + " + …" : "") : editor.keys

                    width: body.width
                    height: 74
                    radius: Theme.shapeLg
                    color: Theme.bgSunken
                    border.width: editor.recording ? 2 : 1
                    border.color: editor.recording ? Theme.accent : Theme.outline

                    KeyCombo {
                        anchors.centerIn: parent
                        visible: keysPreview.shownKeys !== ""
                        keys: keysPreview.shownKeys
                        capHeight: 38
                        fontSize: Theme.fontTitleSm
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: keysPreview.shownKeys === ""
                        text: editor.recording ? "Press the keys you want · Esc cancels" : "No keys yet"
                        color: editor.recording ? Theme.accent : Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyLg
                    }

                }

                Item {
                    width: body.width
                    height: 46

                    M3TextField {
                        anchors.left: parent.left
                        anchors.right: recordBtn.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        placeholder: editor.each ? "SUPER + {key}" : "SUPER + SHIFT + T"
                        text: editor.keys
                        enabled: !editor.recording
                        onEdited: (v) => {
                            editor.keys = v;
                        }
                    }

                    M3Button {
                        id: recordBtn

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: editor.recording ? "Stop" : "Record"
                        variant: editor.recording ? "filled" : "tonal"
                        iconPath: "M20 5H4c-1.1 0-1.99.9-1.99 2L2 17c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2Zm-9 3h2v2h-2V8Zm0 3h2v2h-2v-2ZM8 8h2v2H8V8Zm0 3h2v2H8v-2Zm-1 2H5v-2h2v2Zm0-3H5V8h2v2Zm9 7H8v-2h8v2Zm0-4h-2v-2h2v2Zm0-3h-2V8h2v2Zm3 3h-2v-2h2v2Zm0-3h-2V8h2v2Z"
                        onClicked: editor.recording ? editor.stopRecording() : editor.startRecording()
                    }

                }

                Text {
                    width: body.width
                    visible: editor.clash !== ""
                    text: editor.clash
                    color: Theme.error
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    wrapMode: Text.WordWrap
                }

                Item {
                    width: body.width
                    height: Math.max(eachSwitch.height, eachText.implicitHeight) + 8

                    M3Switch {
                        id: eachSwitch

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        checked: editor.each
                        onToggled: (v) => {
                            editor.setEach(v);
                        }
                    }

                    Column {
                        id: eachText

                        anchors.left: eachSwitch.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Repeat for workspaces 1–10"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBodyLg
                            font.weight: Font.Medium
                        }

                        Text {
                            width: parent.width
                            visible: editor.eachHint !== ""
                            text: editor.eachHint
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBodyMd
                            wrapMode: Text.WordWrap
                        }

                    }

                }

                SectionLabel {
                    text: "Description"
                }

                M3TextField {
                    width: body.width
                    placeholder: "What it does, the way the cheatsheet should say it"
                    text: editor.desc
                    onEdited: (v) => {
                        editor.desc = v;
                    }
                }

                SectionLabel {
                    text: "Category"
                }

                M3TextField {
                    width: body.width
                    placeholder: "One of these, or a new one"
                    text: editor.category
                    onEdited: (v) => {
                        editor.category = v;
                    }
                }

                Flow {
                    width: body.width
                    spacing: 6

                    Repeater {
                        model: Keybinds.categories

                        FilterChip {
                            required property string modelData

                            label: modelData
                            selected: editor.category.trim() === modelData
                            onClicked: editor.category = modelData
                        }

                    }

                }

                SectionLabel {
                    text: "Action"
                }

                M3Segmented {
                    width: 280
                    current: editor.kind
                    options: [{
                        "key": "exec",
                        "label": "Command"
                    }, {
                        "key": "lua",
                        "label": "Lua"
                    }]
                    onChosen: (key) => {
                        editor.kind = key;
                    }
                }

                M3TextField {
                    width: body.width
                    visible: editor.kind === "exec"
                    placeholder: "kitty, or anything you would run in a terminal"
                    text: editor.cmd
                    onEdited: (v) => {
                        editor.cmd = v;
                    }
                }

                Rectangle {
                    width: body.width
                    height: 156
                    visible: editor.kind === "lua"
                    radius: Theme.shapeLg
                    color: Theme.bgSunken
                    border.width: luaEdit.activeFocus ? 2 : 1
                    border.color: luaEdit.activeFocus ? Theme.accent : Theme.outlineStrong

                    Flickable {
                        id: luaFlick

                        function ensureVisible(r) {
                            if (luaFlick.contentY >= r.y)
                                luaFlick.contentY = r.y;
                            else if (luaFlick.contentY + luaFlick.height <= r.y + r.height)
                                luaFlick.contentY = r.y + r.height - luaFlick.height;
                        }

                        anchors.fill: parent
                        anchors.margins: 14
                        contentWidth: width
                        contentHeight: luaEdit.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        TextEdit {
                            id: luaEdit

                            width: luaFlick.width
                            color: Theme.text
                            font.family: "monospace"
                            font.pixelSize: Theme.fontBodyMd
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.fgAccent
                            onTextChanged: {
                                if (luaEdit.text !== editor.lua)
                                    editor.lua = luaEdit.text;

                            }
                            onCursorRectangleChanged: luaFlick.ensureVisible(luaEdit.cursorRectangle)
                            Keys.onTabPressed: (event) => {
                                luaEdit.insert(luaEdit.cursorPosition, "    ");
                                event.accepted = true;
                            }
                        }

                    }

                    Text {
                        x: 14
                        y: 14
                        visible: luaEdit.text === ""
                        text: "hl.dsp.window.close()"
                        color: Theme.subtextDim
                        font.family: "monospace"
                        font.pixelSize: Theme.fontBodyMd
                    }

                }

                Text {
                    width: body.width
                    text: editor.kind === "lua" ? "An expression giving a Hyprland dispatcher — hl.dsp.window.close(), hl.dsp.focus({ workspace = 3 }) — or function() … end, run on every press. fn (utils/functions.lua) and seq(a, b) are in scope." : "Runs through the shell, pipes and all."
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    wrapMode: Text.WordWrap
                }

                SectionLabel {
                    text: "Options"
                }

                Flow {
                    width: body.width
                    spacing: 6

                    Repeater {
                        model: editor.optionList

                        FilterChip {
                            required property var modelData

                            label: modelData.label
                            selected: !!editor.opts[modelData.key]
                            onClicked: editor.toggleOpt(modelData.key)
                        }

                    }

                }

            }

        }

        Item {
            id: foot

            anchors.bottom: parent.bottom
            width: parent.width
            height: 76

            M3Button {
                anchors.left: parent.left
                anchors.leftMargin: card.pad - 8
                anchors.verticalCenter: parent.verticalCenter
                visible: editor.editingId !== ""
                enabled: Keybinds.parseError === ""
                text: "Delete"
                variant: "text"
                destructive: true
                onClicked: editor.askDelete()
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: card.pad
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                M3Button {
                    text: "Cancel"
                    variant: "text"
                    onClicked: editor.dismiss()
                }

                M3Button {
                    text: "Save"
                    variant: "filled"
                    enabled: editor.canSave
                    onClicked: editor.save()
                }

            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeEmphasized
                easing.overshoot: Theme.emphasizedOvershoot
            }

        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: Theme.easeStandard
        }

    }

    component SectionLabel: Text {
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontTitleSm
        font.weight: Font.DemiBold
        topPadding: 8
    }

    // m3 filter chip: outlined at rest, tonal with a check once picked
    component FilterChip: Rectangle {
        id: chip

        property string label: ""
        property bool selected: false

        signal clicked()

        height: 34
        width: chipRow.implicitWidth + 26
        radius: Theme.shapeSm
        color: chip.selected ? Theme.secondaryContainer : "transparent"
        border.width: chip.selected ? 0 : 1
        border.color: Theme.outlineStrong

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: chip.selected ? Theme.fgSecondaryContainer : Theme.text
            opacity: chipArea.pressed ? Theme.statePressed : (chipArea.containsMouse ? Theme.stateHover : 0)
        }

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.selected
                text: "✓"
                color: Theme.fgSecondaryContainer
                font.pixelSize: Theme.fontLabelLg
                font.weight: Font.Bold
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chip.selected ? Theme.fgSecondaryContainer : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.weight: Font.Medium
            }

        }

        MouseArea {
            id: chipArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }

    }

}
