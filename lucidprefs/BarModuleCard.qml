import QtQuick
import qs

// one bar module's card on the Bar page: whether it shows, where the rest of
// its settings live, and the options it has of its own. every module's rows
// are here; only the picked one's are visible
SettingCard {
    id: card

    property string moduleId: ""
    readonly property var mod: Prefs.barModuleById[card.moduleId] || null
    readonly property var options: card.mod && card.mod.options ? card.mod.options : []
    readonly property string groupName: {
        const g = Prefs.barLayoutGroups;
        if (g.left.indexOf(card.moduleId) !== -1)
            return "left";

        return g.center.indexOf(card.moduleId) !== -1 ? "centre" : "right";
    }
    readonly property var pageNames: ({
        "workspaces": "Workspaces",
        "datetime": "Date & Time",
        "notifications": "Notifications"
    })
    readonly property bool barOn: Prefs.barEnabled
    readonly property bool away: !!card.mod && !!card.mod.when && Prefs.barModulesAway.indexOf(card.moduleId) !== -1
    title: card.mod ? card.mod.name : ""
    subtitle: card.mod ? card.mod.desc : ""
    visible: card.mod !== null

    SettingRow {
        id: showRow

        title: "Show in the bar"
        description: "In the " + card.groupName + " group. Drag it in the arrangement above to move it." + (card.away ? " Not in the bar right now: it shows " + card.mod.when + "." : "")
        enabled: card.barOn
        disabledReason: "The bar is switched off, so this module has nothing to appear in."
        showDivider: false

        M3Switch {
            enabled: showRow.enabled
            checked: card.mod ? Prefs[card.mod.key] === true : false
            onToggled: (v) => {
                if (card.mod)
                    Prefs[card.mod.key] = v;

            }
        }

    }

    SettingRow {
        id: moreRow

        visible: !!card.mod && !!card.mod.more
        title: "More settings"
        description: card.mod && card.mod.more ? card.mod.more : ""
        showDivider: false

        M3Button {
            visible: !!card.mod && !!card.mod.page
            text: card.mod && card.pageNames[card.mod.page] ? "Open " + card.pageNames[card.mod.page] : "Open"
            variant: "tonal"
            onClicked: Prefs.settingsRequested(card.mod.page)
        }

    }

    // privacy
    SettingRow {
        visible: card.moduleId === "privacy"
        title: "Watch"
        resetKey: "privacyWatch"
        description: "What makes the module show up. At least one stays on."
        stacked: true
        showDivider: false

        M3Chips {
            width: parent.width
            multi: true
            selectedKeys: String(Prefs.privacyWatch).split(",").filter((k) => {
                return k !== "";
            })
            options: [{
                "key": "mic",
                "label": "Microphone"
            }, {
                "key": "camera",
                "label": "Camera"
            }, {
                "key": "screen",
                "label": "Screen"
            }]
            onChosen: (key) => {
                const list = String(Prefs.privacyWatch).split(",").filter((k) => {
                    return k !== "";
                });
                const at = list.indexOf(key);
                if (at === -1)
                    list.push(key);
                else if (list.length > 1)
                    list.splice(at, 1);
                Prefs.privacyWatch = ["mic", "camera", "screen"].filter((k) => {
                    return list.indexOf(k) !== -1;
                }).join(",");
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "privacy"
        title: "Tell me when something starts"
        resetKey: "privacyToast"
        description: "A toast names the app the moment it starts using the microphone, the camera or the screen. Lucid's own recording, which you start yourself, is left out."
        showDivider: false

        M3Switch {
            checked: Prefs.privacyToast
            onToggled: (v) => {
                return Prefs.privacyToast = v;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "privacy"
        title: "Keep its place in the bar"
        resetKey: "privacyAlwaysShown"
        description: "A quiet shield stays when nothing is in use, so the modules beside it never shift."
        showDivider: false

        M3Switch {
            checked: Prefs.privacyAlwaysShown
            onToggled: (v) => {
                return Prefs.privacyAlwaysShown = v;
            }
        }

    }

    SettingRow {
        visible: card.options.length > 0
        title: "Reset this module"
        description: "Its options above go back to how they ship. Whether it shows and where it sits stay as they are."
        showDivider: false

        M3Button {
            text: "Reset"
            variant: "text"
            destructive: true
            enabled: card.options.some((k) => {
                return Prefs.isModified(k);
            })
            onClicked: Prefs.resetKeys(card.options)
        }

    }

}
