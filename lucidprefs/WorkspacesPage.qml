import QtQuick
import QtQuick.Shapes
import qs

Column {
    id: page

    readonly property var blurbs: ({
        "special": "shows it, and puts away any other workspace that is up. " + Specials.keysText(Specials.stashKeys) + " parks the window you are in here, and sends it back out again.",
        "music": "puts your player over whatever you are doing.",
        "comms": "brings up chat and mail, out of the way until you want them.",
        "todo": "brings up your list, wherever you are.",
        "sysmon": "shows what the machine is up to."
    })
    readonly property var kinds: ({
        "music": "music players",
        "comms": "chat and mail apps",
        "todo": "to-do apps",
        "sysmon": "system monitors"
    })

    // the marks offered for a workspace you make, in the order they are shown
    readonly property var glyphChoices: ["apps", "layers", "web", "mail", "chat", "code", "terminal", "edit_note", "checklist", "content_paste", "music_note", "graphic_eq", "movie", "videocam", "tv", "photo_library", "sports_esports", "folder", "archive", "build", "settings", "monitor_heart", "host", "security", "print", "mic"].filter((g) => {
        return Specials.glyphs[g] !== undefined;
    })
    // "" hides the form, "+" is a new workspace, anything else the one being edited
    property string formKey: ""
    property string formName: ""
    property string formGlyph: "apps"
    readonly property bool formNew: page.formKey === "+"

    function openForm(key) {
        const s = key === "+" ? null : Specials.space(key);
        page.formName = s ? s.label : "";
        page.formGlyph = s ? s.glyph : "apps";
        page.formKey = key;
        nameField.focusInput();
    }

    function submitForm() {
        const name = page.formName.trim();
        if (name === "")
            return ;

        if (page.formNew) {
            const key = Specials.create(name, page.formGlyph);
            page.formKey = "";
            // straight on to its key, which is the one thing it cannot work without
            if (key !== "")
                Keybinds.newRequested(Specials.newBind(key));

        } else {
            Specials.rename(page.formKey, name, page.formGlyph);
            page.formKey = "";
        }
    }

    function blurb(key) {
        if (page.blurbs[key] !== undefined)
            return page.blurbs[key];

        const names = Specials.chosenNames(key);
        return names.length > 0 ? "brings up " + names.join(", ") + "." : "brings up the apps you give it below.";
    }

    function keyLine(key) {
        const keys = Specials.keysOf(key);
        return (keys.length > 0 ? Specials.keysText(keys) : "No key yet. Its key") + " " + page.blurb(key);
    }

    function known(key) {
        const names = [];
        for (const a of Specials.catalog[key] || []) {
            if (names.indexOf(a.name) === -1)
                names.push(a.name);

        }
        return names.length > 1 ? names.slice(0, -1).join(", ") + " or " + names[names.length - 1] : names.join("");
    }

    spacing: 26

    SettingCard {
        visible: Specials.moduleProbed && !Specials.moduleInstalled

        SettingRow {
            title: "The keys are not set up"
            warning: "These workspaces come with Lucid's Hyprland config, and yours does not load it. Run the installer with --with-hypr, or copy modules/specials.lua and the special workspace binds from Lucid's modules/binds.lua into your own."
            showDivider: false
        }

    }

    SettingCard {
        title: "WORKSPACES"
        subtitle: "Each one slides over the workspace you are on, and the same keys put it away again."

        Repeater {
            model: Specials.spaces.map((s) => {
                return s.key;
            })

            SettingRow {
                id: spaceRow

                required property string modelData
                // a deleted workspace's row outlives it for a moment
                readonly property var space: Specials.space(modelData) || {
                    "key": modelData,
                    "label": "",
                    "own": true,
                    "apps": ""
                }
                readonly property var bind: Specials.bindOf(modelData)

                title: space.label
                resetKey: space.own ? "" : space.pref
                description: page.keyLine(modelData)

                Row {
                    spacing: 4

                    M3Button {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Specials.keysOf(spaceRow.modelData).length === 0 && Keybinds.loaded && !Keybinds.missing
                        text: spaceRow.bind ? "Edit key" : "Set a key"
                        variant: "text"
                        onClicked: {
                            if (spaceRow.bind)
                                Keybinds.editRequested(spaceRow.bind.id);
                            else
                                Keybinds.newRequested(Specials.newBind(spaceRow.modelData));
                        }
                    }

                    M3IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: spaceRow.space.own === true
                        iconPath: "M5 19h1.425L16.2 9.225L14.775 7.8L5 17.575V19Zm-2 2v-4.25L16.2 3.575q0.3-0.275 0.6625-0.425t0.7625-0.15q0.4 0 0.775 0.15t0.65 0.45L20.425 5q0.3 0.275 0.4375 0.65T21 6.4q0 0.4-0.1375 0.7625T20.425 7.825L7.25 21H3ZM15.475 8.525l-0.7-0.725L16.2 9.225l-0.725-0.7Z"
                        onClicked: page.openForm(spaceRow.modelData)
                    }

                    M3IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: spaceRow.space.own === true
                        destructive: true
                        iconPath: "M7 21q-0.825 0-1.4125-0.5875T5 19V6H4V4h5V3h6v1h5v2h-1v13q0 0.825-0.5875 1.4125T17 21H7ZM17 6H7v13h10V6ZM9 17h2V8H9v9Zm4 0h2V8h-2v9ZM7 6v13V6Z"
                        onClicked: Prefs.askConfirm("Delete " + spaceRow.space.label + "?", "Its windows come back to the workspace you are on" + (spaceRow.bind ? ", and its key (" + Keybinds.tokens(spaceRow.bind.keys).join(" + ") + ") is removed from keybinds.json" : "") + ".", "Delete", "special-delete:" + spaceRow.modelData)
                    }

                    M3Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Specials.isOn(spaceRow.modelData)
                        onToggled: (v) => {
                            return Specials.setOn(spaceRow.modelData, v);
                        }
                    }

                }

            }

        }

        SettingRow {
            visible: page.formKey === ""
            title: "Make your own"
            description: "A workspace of your own, with its own key, mark and apps."
            showDivider: false

            M3Button {
                text: "New workspace"
                variant: "tonal"
                iconPath: "M11 13H5v-2h6V5h2v6h6v2h-6v6h-2v-6Z"
                onClicked: page.openForm("+")
            }

        }

        SettingRow {
            visible: page.formKey !== ""
            title: page.formNew ? "New workspace" : "Edit " + (Specials.space(page.formKey) || {
                "label": ""
            }).label
            description: page.formNew ? "A name, and the mark it shows in the bar. Its key comes next, and its apps are added below." : "A name, and the mark it shows in the bar."
            stacked: true
            showDivider: false

            Column {
                width: parent.width
                spacing: 16

                M3TextField {
                    id: nameField

                    width: Math.min(parent.width, 360)
                    placeholder: "Notes"
                    text: page.formName
                    commitOnBlur: false
                    error: page.formName.length > 0 && page.formName.trim() === ""
                    onEdited: (v) => {
                        return page.formName = v;
                    }
                    onAccepted: (v) => {
                        page.formName = v;
                        page.submitForm();
                    }
                    onCancelled: page.formKey = ""
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: page.glyphChoices

                        Rectangle {
                            id: glyphTile

                            required property string modelData
                            readonly property bool picked: page.formGlyph === modelData

                            width: 40
                            height: 40
                            radius: Theme.radiusSm
                            color: glyphTile.picked ? Theme.accent : (glyphArea.containsMouse ? Theme.bgHover : Theme.bgTile)

                            Item {
                                anchors.centerIn: parent
                                width: 22
                                height: 22

                                Shape {
                                    width: 24
                                    height: 24
                                    preferredRendererType: Shape.CurveRenderer

                                    ShapePath {
                                        strokeWidth: 0
                                        fillColor: glyphTile.picked ? Theme.fgAccent : Theme.subtext

                                        PathSvg {
                                            path: Specials.glyphPath(glyphTile.modelData)
                                        }

                                    }

                                    transform: Scale {
                                        xScale: 22 / 24
                                        yScale: 22 / 24
                                    }

                                }

                            }

                            MouseArea {
                                id: glyphArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.formGlyph = glyphTile.modelData
                            }

                        }

                    }

                }

                Row {
                    spacing: 8

                    M3Button {
                        text: page.formNew ? "Create" : "Save"
                        variant: "filled"
                        enabled: page.formName.trim() !== ""
                        onClicked: page.submitForm()
                    }

                    M3Button {
                        text: "Cancel"
                        variant: "text"
                        onClicked: page.formKey = ""
                    }

                }

            }

        }

    }

    SettingCard {
        title: "APPS"
        subtitle: "The key starts whichever of these is not running yet. Anything else you open while a workspace is up stays in it too."

        Repeater {
            model: ["music", "comms", "todo", "sysmon"].concat(Specials.ownSpaces.map((s) => {
                return s.key;
            }))

            SettingRow {
                id: appsRow

                required property string modelData
                // a deleted workspace's row outlives it for a moment
                readonly property var space: Specials.space(modelData) || {
                    "key": modelData,
                    "label": "",
                    "own": true,
                    "apps": ""
                }
                readonly property var apps: {
                    const out = (Specials.available[modelData] || []).map((a) => {
                        return a.id;
                    });
                    // an added app is only in the list while it is ticked
                    for (const id of Specials.chosen(modelData)) {
                        if (Specials.isCustom(id) && out.indexOf(id) === -1)
                            out.push(id);

                    }
                    return out;
                }

                title: space.label
                resetKey: space.own ? "" : space.apps
                stacked: true
                enabled: Specials.isOn(modelData)
                disabledReason: space.label + " is switched off above, so its key does nothing."
                description: apps.length > 0 ? "" : (space.own ? "Nothing yet. Add the apps its key should bring up." : "None of the " + page.kinds[modelData] + " Lucid knows are installed: " + page.known(modelData) + ".")

                Column {
                    width: parent.width
                    spacing: 14

                    Repeater {
                        model: appsRow.apps

                        CheckLine {
                            required property string modelData
                            readonly property var app: Specials.appById(appsRow.modelData, modelData)

                            label: app ? app.name : modelData
                            icon: Specials.iconOf(appsRow.modelData, modelData)
                            enabled: appsRow.enabled
                            checked: Specials.isChosen(appsRow.modelData, modelData)
                            onToggled: Specials.setChosen(appsRow.modelData, modelData, !checked)
                        }

                    }

                    M3Button {
                        text: "Add an app"
                        variant: "text"
                        iconPath: "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2Z"
                        enabled: appsRow.enabled
                        onClicked: Prefs.appPickerRequested(appsRow.modelData)
                    }

                }

            }

        }

    }

    SettingCard {
        title: "BEHAVIOUR"

        SettingRow {
            title: "Keep apps in their workspace"
            resetKey: "specialKeepApps"
            description: "The apps picked above always open inside their workspace, from the launcher and the dock too, and the key pulls them back in if you moved them out."

            M3Switch {
                checked: Prefs.specialKeepApps
                onToggled: (v) => {
                    return Prefs.specialKeepApps = v;
                }
            }

        }

        SettingRow {
            title: "Put away on workspace change"
            resetKey: "specialHideOnSwitch"
            description: "Switching to another workspace hides whatever is up, instead of carrying it along over the next one."

            M3Switch {
                checked: Prefs.specialHideOnSwitch
                onToggled: (v) => {
                    return Prefs.specialHideOnSwitch = v;
                }
            }

        }

        SettingRow {
            title: "Dim behind"
            resetKey: "specialDim"
            description: "How far the workspace underneath darkens while one is up."
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 60
                stepSize: 5
                suffix: "%"
                value: Math.round(Prefs.specialDim * 100)
                onMoved: (v) => {
                    return Prefs.specialDim = v / 100;
                }
            }

        }

        SettingRow {
            title: "Blur behind"
            resetKey: "specialBlur"
            description: "Blur the workspace underneath as well. It is redrawn blurred on every frame while one is up, so it costs more than dimming alone."

            M3Switch {
                checked: Prefs.specialBlur
                onToggled: (v) => {
                    return Prefs.specialBlur = v;
                }
            }

        }

        SettingRow {
            title: "Margin around"
            resetKey: "specialGaps"
            description: "Room between the windows and the edges of the screen, so what is underneath shows around them like a card. At 0 they keep the gaps of any other workspace."
            stacked: true
            showDivider: false

            M3Slider {
                width: parent.width
                from: 0
                to: 200
                stepSize: 10
                suffix: " px"
                value: Prefs.specialGaps
                onMoved: (v) => {
                    return Prefs.specialGaps = Math.round(v);
                }
            }

        }

    }

    SettingCard {
        title: "RESET"

        SettingRow {
            title: "Reset special workspaces"
            description: "Every workspace back on, each one back to the first of its apps that is installed, and the behaviour above back to how it ships. The workspaces you made stay as they are."
            showDivider: false

            M3Button {
                text: "Reset"
                variant: "text"
                destructive: true
                onClicked: Prefs.askReset("Reset special workspaces?", "Every workspace goes back on, each one back to the first of its apps that is installed, and the behaviour settings back to how they ship.", Prefs.resetSpecialsToken)
            }

        }

    }

}
