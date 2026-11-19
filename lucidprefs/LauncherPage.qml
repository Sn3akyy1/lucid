import QtQuick
import qs

Column {
    id: page

    spacing: Theme.dp(26)

    SettingCard {
        title: I18n.tr("PANEL")

        SettingRow {
            title: I18n.tr("Width")
            resetKey: "launcherWidth"
            description: I18n.tr("How wide the panel opens. Wider fits longer application names and the whole mode set at once.")
            stacked: true

            M3Segmented {
                width: parent.width
                current: Prefs.launcherWidth
                options: [{
                    "key": "compact",
                    "label": I18n.tr("Compact")
                }, {
                    "key": "standard",
                    "label": I18n.tr("Standard")
                }, {
                    "key": "wide",
                    "label": I18n.tr("Wide")
                }]
                onChosen: (k) => {
                    return Prefs.launcherWidth = k;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Content size")
            resetKey: "launcherContentScale"
            description: I18n.tr("Scales everything inside the panel together \u2014 the head, the search field, the icons and the text \u2014 and the panel with it. Separate from the shell-wide font scale on the General page.")
            stacked: true

            M3Slider {
                width: parent.width
                from: 80
                to: 140
                stepSize: 5
                suffix: "%"
                value: Math.round(Prefs.launcherContentScale * 100)
                onMoved: (v) => {
                    return Prefs.launcherContentScale = v / 100;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Search field")
            resetKey: "launcherSearchPosition"
            description: I18n.tr("At the bottom it lands where the panel grows from, right above the dock. At the top the results read downward from it, the way Material's search view is laid out.")
            stacked: true

            M3Segmented {
                width: parent.width
                current: Prefs.launcherSearchPosition
                options: [{
                    "key": "bottom",
                    "label": I18n.tr("Bottom")
                }, {
                    "key": "top",
                    "label": I18n.tr("Top")
                }]
                onChosen: (k) => {
                    return Prefs.launcherSearchPosition = k;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Row height")
            resetKey: "launcherDensity"
            description: I18n.tr("Comfortable gives each result the full 56dp Material list row. Compact trims it so more results fit before the panel has to scroll.")
            stacked: true

            M3Segmented {
                width: parent.width
                current: Prefs.launcherDensity
                options: [{
                    "key": "comfortable",
                    "label": I18n.tr("Comfortable")
                }, {
                    "key": "compact",
                    "label": I18n.tr("Compact")
                }]
                onChosen: (k) => {
                    return Prefs.launcherDensity = k;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Mode bar")
            resetKey: "launcherModeBar"
            description: I18n.tr("The head of the panel: the mark, the modes as one row of pills, and what the results add up to. Tab walks the modes, Ctrl and a digit jumps straight to one, and the prefixes work either way.")
            showDivider: false

            M3Switch {
                checked: Prefs.launcherModeBar
                onToggled: (v) => {
                    return Prefs.launcherModeBar = v;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("RESULTS")

        SettingRow {
            title: I18n.tr("Frequent applications first")
            resetKey: "launcherFrequentFirst"
            description: I18n.tr("With nothing typed, the applications you open most are grouped above the full alphabetical list.")

            M3Switch {
                checked: Prefs.launcherFrequentFirst
                onToggled: (v) => {
                    return Prefs.launcherFrequentFirst = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Show what Return will do")
            resetKey: "launcherActionHints"
            description: I18n.tr("The selected row says whether Return opens it, copies it or applies it.")

            M3Switch {
                checked: Prefs.launcherActionHints
                onToggled: (v) => {
                    return Prefs.launcherActionHints = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Settings in results")
            resetKey: "launcherSettingsResults"
            description: I18n.tr("Searching also looks through this app's own pages, so a setting is one search away rather than a hunt through the rail.")

            M3Switch {
                checked: Prefs.launcherSettingsResults
                onToggled: (v) => {
                    return Prefs.launcherSettingsResults = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Open windows")
            resetKey: "launcherWindows"
            description: I18n.tr("A search also finds the windows you have open, by their app or their title, ranked with the apps. Return switches to it.")

            M3Switch {
                checked: Prefs.launcherWindows
                onToggled: (v) => {
                    return Prefs.launcherWindows = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Application actions")
            resetKey: "launcherAppActions"
            description: I18n.tr("What an app offers besides opening, such as New Private Window: listed under it when you type its name, and found on their own from three letters.")

            M3Switch {
                checked: Prefs.launcherAppActions
                onToggled: (v) => {
                    return Prefs.launcherAppActions = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("A line under each application")
            resetKey: "launcherAppDescriptions"
            description: I18n.tr("What the app says it is, from its desktop entry, under its name.")

            M3Switch {
                checked: Prefs.launcherAppDescriptions
                onToggled: (v) => {
                    return Prefs.launcherAppDescriptions = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Calculator")
            resetKey: "launcherCalculator"
            description: I18n.tr("Type a sum and the answer takes a card above the results, set in display type. Return copies it.")
            showDivider: false

            M3Switch {
                checked: Prefs.launcherCalculator
                onToggled: (v) => {
                    return Prefs.launcherCalculator = v;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("POWER BUTTONS")

        SettingRow {
            title: I18n.tr("Power buttons by the search field")
            resetKey: "launcherPowerChips"
            description: I18n.tr("Round buttons at the end of the search field while nothing is typed. Restart, shut down and log out turn red on the first press and act on the second.")

            M3Switch {
                checked: Prefs.launcherPowerChips
                onToggled: (v) => {
                    return Prefs.launcherPowerChips = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Which buttons")
            resetKey: "launcherPowerButtons"
            description: I18n.tr("They keep this order whatever order you pick them in.")
            enabled: Prefs.launcherPowerChips
            disabledReason: I18n.tr("The power buttons are switched off.")
            stacked: true
            showDivider: false

            M3Chips {
                width: parent.width
                multi: true
                enabled: Prefs.launcherPowerChips
                selectedKeys: String(Prefs.launcherPowerButtons).split(",").filter((k) => {
                    return k !== "";
                })
                options: Power.actions.map((a) => {
                    return {
                        "key": a.id,
                        "label": a.label
                    };
                })
                onChosen: (key) => {
                    const list = String(Prefs.launcherPowerButtons).split(",").filter((k) => {
                        return k !== "" && k !== key;
                    });
                    if (String(Prefs.launcherPowerButtons).split(",").indexOf(key) === -1)
                        list.push(key);

                    Prefs.launcherPowerButtons = Power.actions.map((a) => {
                        return a.id;
                    }).filter((id) => {
                        return list.indexOf(id) !== -1;
                    }).join(",");
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("HIDDEN APPLICATIONS")

        SettingRow {
            title: I18n.tr("Left out of the results")
            description: Prefs.hiddenLauncherApps.length === 0 ? I18n.tr("Nothing is hidden. Hover any application in the launcher and press the eye to drop it from the list \u2014 entries the system already marks as hidden, or as belonging to another desktop, never show in the first place.") : I18n.tr("Applications you dropped from the launcher. Pick one to bring it back. They still launch from the dock and still match a running window.")
            stacked: true
            showDivider: Prefs.hiddenLauncherApps.length > 0

            M3Chips {
                width: parent.width
                visible: Prefs.hiddenLauncherApps.length > 0
                multi: true
                selectedKeys: Prefs.hiddenLauncherApps
                options: Prefs.hiddenLauncherApps.map((id) => {
                    return {
                        "key": id,
                        "label": Prefs.launcherAppLabel(id)
                    };
                })
                onChosen: (k) => {
                    return Prefs.setLauncherHidden(k, false);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Show them all again")
            description: I18n.tr("Empties the list in one go.")
            visible: Prefs.hiddenLauncherApps.length > 0
            showDivider: false

            M3Button {
                text: I18n.tr("Show all")
                variant: "text"
                onClicked: Prefs.launcherHiddenApps = ""
            }

        }

    }

    SettingCard {
        title: I18n.tr("SEARCH")

        SettingRow {
            title: I18n.tr("Prefixes")
            description: I18n.tr("> commands  ·  : emoji  ·  ? the web  ·  $ run a command line. Type one at the start of the field, or pick the mode from the head.")
            stacked: true
        }

        SettingRow {
            title: I18n.tr("Offer a web search")
            resetKey: "launcherWebRow"
            description: I18n.tr("End every search with a row that looks it up on the web, or opens it if it is an address.")

            M3Switch {
                checked: Prefs.launcherWebRow
                onToggled: (v) => {
                    return Prefs.launcherWebRow = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Open typed addresses first")
            resetKey: "launcherAddressFirst"
            description: I18n.tr("Something that reads as an address, like example.com, gets a row of its own at the top when no app or window matches it better.")

            M3Switch {
                checked: Prefs.launcherAddressFirst
                onToggled: (v) => {
                    return Prefs.launcherAddressFirst = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Power actions in results")
            resetKey: "launcherPowerSearch"
            description: I18n.tr("Lock, suspend, log out, restart and shut down turn up when you type them, from three letters. Restart, shut down and log out ask for a second Return.")

            M3Switch {
                checked: Prefs.launcherPowerSearch
                onToggled: (v) => {
                    return Prefs.launcherPowerSearch = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Search engine")
            resetKey: "launcherSearchEngine"
            description: I18n.tr("Used by the web row and the ? prefix.")
            stacked: true
            showDivider: false

            M3Segmented {
                width: parent.width
                current: Prefs.launcherSearchEngine
                options: [{
                    "key": "duckduckgo",
                    "label": I18n.tr("DuckDuckGo")
                }, {
                    "key": "google",
                    "label": I18n.tr("Google")
                }, {
                    "key": "brave",
                    "label": I18n.tr("Brave")
                }, {
                    "key": "startpage",
                    "label": I18n.tr("Startpage")
                }, {
                    "key": "kagi",
                    "label": I18n.tr("Kagi")
                }]
                onChosen: (k) => {
                    return Prefs.launcherSearchEngine = k;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("CLIPBOARD")

        SettingRow {
            title: I18n.tr("Clipboard history")
            description: I18n.tr("Keeps what you copy so the launcher can hand it back. Type > clip in the launcher, or pick Clipboard History from the command list. Needs cliphist installed.")
            enabled: Clip.available
            disabledReason: I18n.tr("cliphist is not installed. Install it and the history starts recording straight away.")

            M3Switch {
                checked: Prefs.clipboardEnabled && Clip.available
                enabled: Clip.available
                onToggled: (v) => {
                    return Prefs.clipboardEnabled = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Clear clipboard history")
            description: I18n.tr("Discards every entry cliphist has stored, including images.")
            enabled: Clip.available
            showDivider: false

            M3Button {
                text: I18n.tr("Clear history")
                variant: "text"
                destructive: true
                enabled: Clip.available
                onClicked: Prefs.askConfirm(I18n.tr("Clear clipboard history?"), I18n.tr("Every entry cliphist has stored is discarded, images included. This cannot be undone."), I18n.tr("Clear"), Prefs.clearClipboardToken)
            }

        }

    }

}
