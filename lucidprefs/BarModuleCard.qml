import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs

// one bar module's card on the Bar page: whether it shows, where the rest of
// its settings live, and the options it has of its own. every module's rows
// are here; only the picked one's are visible
SettingCard {
    id: card

    property string moduleId: ""
    readonly property var mod: Prefs.barModuleById[card.moduleId] || null
    // what Reset puts back: its own options and its styles
    readonly property var options: card.mod ? (card.mod.options || []).concat(card.mod.style ? [card.mod.style] : [], card.mod.panelStyle ? [card.mod.panelStyle] : []) : []
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
    // the power module's actions: the picked ones in their order, then the rest
    readonly property var powerCatalogue: [{
        "id": "lock",
        "label": "Lock"
    }, {
        "id": "suspend",
        "label": "Suspend"
    }, {
        "id": "hibernate",
        "label": "Hibernate",
        "note": "only where the machine can"
    }, {
        "id": "logout",
        "label": "Log out"
    }, {
        "id": "reboot",
        "label": "Restart"
    }, {
        "id": "shutdown",
        "label": "Shut down"
    }]
    readonly property var powerOn: String(Prefs.powerModuleActions || "").split(",").filter((id) => {
        return card.powerCatalogue.some((a) => {
            return a.id === id;
        });
    })
    readonly property var powerRows: card.powerOn.concat(card.powerCatalogue.map((a) => {
        return a.id;
    }).filter((id) => {
        return card.powerOn.indexOf(id) === -1;
    }))

    function setPower(list) {
        Prefs.powerModuleActions = list.join(",");
    }

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
                    Prefs.setBarModuleShown(card.moduleId, v);

            }
        }

    }

    // how it looks, closed in the bar and opened; the bar changes as you pick
    SettingRow {
        visible: !!card.mod && !!card.mod.styles
        title: "In the bar"
        description: "How it looks until you open it."
        stacked: true
        showDivider: false

        Flow {
            width: parent.width
            spacing: Theme.dp(10)

            Repeater {
                model: card.mod && card.mod.styles ? card.mod.styles : []

                BarStyleTile {
                    required property var modelData

                    moduleId: card.moduleId
                    prefKey: card.mod ? card.mod.style : ""
                    style: modelData
                }

            }

        }

    }

    SettingRow {
        visible: !!card.mod && !!card.mod.panelStyles
        title: "Opened"
        description: "How its panel looks."
        stacked: true
        showDivider: false

        Flow {
            width: parent.width
            spacing: Theme.dp(10)

            Repeater {
                model: card.mod && card.mod.panelStyles ? card.mod.panelStyles : []

                BarStyleTile {
                    required property var modelData

                    moduleId: card.moduleId
                    prefKey: card.mod ? card.mod.panelStyle : ""
                    style: modelData
                    panel: true
                }

            }

        }

    }

    // workspaces
    // clock
    // media
    // notifications
    // system
    // system tray
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

    // power
    SettingRow {
        visible: card.moduleId === "power"
        title: "Actions"
        resetKey: "powerModuleActions"
        description: "The ones switched on show in the panel, top to bottom in this order. At least one stays."
        stacked: true
        showDivider: false

        Column {
            width: parent.width
            spacing: Theme.dp(6)

            Repeater {
                model: card.powerRows

                Rectangle {
                    id: powerItem

                    required property string modelData
                    required property int index
                    readonly property var action: card.powerCatalogue.find((a) => {
                        return a.id === powerItem.modelData;
                    })
                    readonly property int at: card.powerOn.indexOf(powerItem.modelData)
                    readonly property bool on: powerItem.at !== -1

                    width: parent.width
                    height: Theme.dp(52)
                    radius: Theme.radiusMd
                    color: Theme.bgSunken

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.dp(16)
                        anchors.right: powerTools.left
                        anchors.rightMargin: Theme.dp(10)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: powerItem.action ? powerItem.action.label : powerItem.modelData
                            color: powerItem.on ? Theme.text : Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBodyLg
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: !!(powerItem.action && powerItem.action.note)
                            width: parent.width
                            text: powerItem.action && powerItem.action.note ? powerItem.action.note : ""
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelSm
                        }

                    }

                    Row {
                        id: powerTools

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.dp(12)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.dp(2)

                        M3IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            size: Theme.dp(34)
                            enabled: powerItem.on && powerItem.at > 0
                            iconPath: "arrow_upward"
                            onClicked: {
                                const l = card.powerOn.slice();
                                l.splice(powerItem.at, 1);
                                l.splice(powerItem.at - 1, 0, powerItem.modelData);
                                card.setPower(l);
                            }
                        }

                        M3IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            size: Theme.dp(34)
                            enabled: powerItem.on && powerItem.at < card.powerOn.length - 1
                            iconPath: "arrow_downward"
                            onClicked: {
                                const l = card.powerOn.slice();
                                l.splice(powerItem.at, 1);
                                l.splice(powerItem.at + 1, 0, powerItem.modelData);
                                card.setPower(l);
                            }
                        }

                        M3Switch {
                            anchors.verticalCenter: parent.verticalCenter
                            enabled: !powerItem.on || card.powerOn.length > 1
                            checked: powerItem.on
                            onToggled: (v) => {
                                const l = card.powerOn.filter((id) => {
                                    return id !== powerItem.modelData;
                                });
                                if (v)
                                    l.push(powerItem.modelData);

                                card.setPower(l);
                            }
                        }

                    }

                }

            }

        }

    }

    SettingRow {
        visible: card.moduleId === "power"
        title: "Ask twice"
        resetKey: "powerModuleConfirm"
        description: "Log out, restart and shut down wait for a second click within three seconds, so a stray one does nothing."
        showDivider: false

        M3Switch {
            checked: Prefs.powerModuleConfirm
            onToggled: (v) => {
                return Prefs.powerModuleConfirm = v;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "power"
        title: "Show how long it has been up"
        resetKey: "powerModuleUptime"
        description: "The time since the machine started, at the top of the panel."
        showDivider: false

        M3Switch {
            checked: Prefs.powerModuleUptime
            onToggled: (v) => {
                return Prefs.powerModuleUptime = v;
            }
        }

    }

    // active window
    SettingRow {
        id: windowText

        visible: card.moduleId === "window"
        title: "Shows"
        resetKey: "windowModuleText"
        description: "What the pill reads in the bar, or only the app's icon. The panel always has both."
        stacked: true
        showDivider: false

        M3Segmented {
            width: Math.min(parent.width, Theme.dp(480))
            current: Prefs.windowModuleText
            options: [{
                "key": "title",
                "label": "Title"
            }, {
                "key": "app",
                "label": "App name"
            }, {
                "key": "both",
                "label": "Both"
            }, {
                "key": "icon",
                "label": "Icon only"
            }]
            onChosen: (key) => {
                return Prefs.windowModuleText = key;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "window"
        title: "Longest it gets"
        resetKey: "windowModuleWidth"
        description: "A longer title is cut short with an ellipsis."
        enabled: Prefs.windowModuleText !== "icon"
        disabledReason: "It shows only the icon."
        stacked: true
        showDivider: false

        M3Slider {
            width: parent.width
            enabled: Prefs.windowModuleText !== "icon"
            from: 120
            to: 480
            stepSize: 10
            suffix: " px"
            value: Prefs.windowModuleWidth
            onMoved: (v) => {
                return Prefs.windowModuleWidth = Math.round(v);
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "window"
        title: "Scroll to switch windows"
        resetKey: "windowModuleScroll"
        description: "The wheel over the pill moves the focus through the windows on the workspace."
        showDivider: false

        M3Switch {
            checked: Prefs.windowModuleScroll
            onToggled: (v) => {
                return Prefs.windowModuleScroll = v;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "window"
        title: "Middle click closes it"
        resetKey: "windowModuleMiddleClose"
        description: "Like closing a browser tab: the window in focus closes on a middle click on the pill."
        showDivider: false

        M3Switch {
            checked: Prefs.windowModuleMiddleClose
            onToggled: (v) => {
                return Prefs.windowModuleMiddleClose = v;
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
