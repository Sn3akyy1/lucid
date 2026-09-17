import QtQuick
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
                required property string modelData
                readonly property var space: Specials.space(modelData)

                title: space.label
                resetKey: space.pref
                description: Specials.keysText(space.keys) + " " + page.blurbs[modelData]

                M3Switch {
                    checked: Specials.isOn(modelData)
                    onToggled: (v) => {
                        return Specials.setOn(modelData, v);
                    }
                }

            }

        }

    }

    SettingCard {
        title: "APPS"
        subtitle: "The key starts whichever of these is not running yet. Anything else you open while a workspace is up stays in it too."

        Repeater {
            model: ["music", "comms", "todo", "sysmon"]

            SettingRow {
                id: appsRow

                required property string modelData
                readonly property var space: Specials.space(modelData)
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
                resetKey: space.apps
                stacked: true
                enabled: Specials.isOn(modelData)
                disabledReason: space.label + " is switched off above, so its key does nothing."
                description: apps.length > 0 ? "" : "None of the " + page.kinds[modelData] + " Lucid knows are installed: " + page.known(modelData) + "."

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
            showDivider: false

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

    }

    SettingCard {
        title: "RESET"

        SettingRow {
            title: "Reset special workspaces"
            description: "Every workspace back on, each one back to the first of its apps that is installed, and the behaviour above back to how it ships."
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
