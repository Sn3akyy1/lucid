import QtQuick
import qs

Column {
    id: page

    spacing: 26

    SettingCard {
        title: "PANEL"

        SettingRow {
            title: "Width"
            resetKey: "launcherWidth"
            description: "How wide the panel opens. Wider fits longer application names and the whole mode set at once."
            stacked: true

            M3Segmented {
                width: parent.width
                current: Prefs.launcherWidth
                options: [{
                    "key": "compact",
                    "label": "Compact"
                }, {
                    "key": "standard",
                    "label": "Standard"
                }, {
                    "key": "wide",
                    "label": "Wide"
                }]
                onChosen: (k) => {
                    return Prefs.launcherWidth = k;
                }
            }

        }

        SettingRow {
            title: "Content size"
            resetKey: "launcherContentScale"
            description: "Scales everything inside the panel together \u2014 the head, the search field, the icons and the text \u2014 and the panel with it. Separate from the shell-wide font scale on the General page."
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
            title: "Search field"
            resetKey: "launcherSearchPosition"
            description: "At the bottom it lands where the panel grows from, right above the dock. At the top the results read downward from it, the way Material's search view is laid out."
            stacked: true

            M3Segmented {
                width: parent.width
                current: Prefs.launcherSearchPosition
                options: [{
                    "key": "bottom",
                    "label": "Bottom"
                }, {
                    "key": "top",
                    "label": "Top"
                }]
                onChosen: (k) => {
                    return Prefs.launcherSearchPosition = k;
                }
            }

        }

        SettingRow {
            title: "Row height"
            resetKey: "launcherDensity"
            description: "Comfortable gives each result the full 56dp Material list row. Compact trims it so more results fit before the panel has to scroll."
            stacked: true

            M3Segmented {
                width: parent.width
                current: Prefs.launcherDensity
                options: [{
                    "key": "comfortable",
                    "label": "Comfortable"
                }, {
                    "key": "compact",
                    "label": "Compact"
                }]
                onChosen: (k) => {
                    return Prefs.launcherDensity = k;
                }
            }

        }

        SettingRow {
            title: "Mode bar"
            resetKey: "launcherModeBar"
            description: "The head of the panel: the mark, the modes as one row of pills, and what the results add up to. Tab walks the modes, Ctrl and a digit jumps straight to one, and the prefixes work either way."
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
        title: "RESULTS"

        SettingRow {
            title: "Frequent applications first"
            resetKey: "launcherFrequentFirst"
            description: "With nothing typed, the applications you open most are grouped above the full alphabetical list."

            M3Switch {
                checked: Prefs.launcherFrequentFirst
                onToggled: (v) => {
                    return Prefs.launcherFrequentFirst = v;
                }
            }

        }

        SettingRow {
            title: "Show what Return will do"
            resetKey: "launcherActionHints"
            description: "The selected row says whether Return opens it, copies it or applies it."

            M3Switch {
                checked: Prefs.launcherActionHints
                onToggled: (v) => {
                    return Prefs.launcherActionHints = v;
                }
            }

        }

        SettingRow {
            title: "Settings in results"
            resetKey: "launcherSettingsResults"
            description: "Searching also looks through this app's own pages, so a setting is one search away rather than a hunt through the rail."

            M3Switch {
                checked: Prefs.launcherSettingsResults
                onToggled: (v) => {
                    return Prefs.launcherSettingsResults = v;
                }
            }

        }

        SettingRow {
            title: "Calculator"
            resetKey: "launcherCalculator"
            description: "Type a sum and the answer takes a card above the results, set in display type. Return copies it."
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
        title: "HIDDEN APPLICATIONS"

        SettingRow {
            title: "Left out of the results"
            description: Prefs.hiddenLauncherApps.length === 0 ? "Nothing is hidden. Hover any application in the launcher and press the eye to drop it from the list \u2014 entries the system already marks as hidden, or as belonging to another desktop, never show in the first place." : "Applications you dropped from the launcher. Pick one to bring it back. They still launch from the dock and still match a running window."
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
            title: "Show them all again"
            description: "Empties the list in one go."
            visible: Prefs.hiddenLauncherApps.length > 0
            showDivider: false

            M3Button {
                text: "Show all"
                variant: "text"
                onClicked: Prefs.launcherHiddenApps = ""
            }

        }

    }

    SettingCard {
        title: "SEARCH"

        SettingRow {
            title: "Prefixes"
            description: "> commands  ·  : emoji  ·  ? the web  ·  $ run a command line. Type one at the start of the field, or pick the mode from the head."
            stacked: true
        }

        SettingRow {
            title: "Offer a web search"
            resetKey: "launcherWebRow"
            description: "End every search with a row that looks it up on the web, or opens it if it is an address."

            M3Switch {
                checked: Prefs.launcherWebRow
                onToggled: (v) => {
                    return Prefs.launcherWebRow = v;
                }
            }

        }

        SettingRow {
            title: "Search engine"
            resetKey: "launcherSearchEngine"
            description: "Used by the web row and the ? prefix."
            stacked: true
            showDivider: false

            M3Segmented {
                width: parent.width
                current: Prefs.launcherSearchEngine
                options: [{
                    "key": "duckduckgo",
                    "label": "DuckDuckGo"
                }, {
                    "key": "google",
                    "label": "Google"
                }, {
                    "key": "brave",
                    "label": "Brave"
                }, {
                    "key": "startpage",
                    "label": "Startpage"
                }, {
                    "key": "kagi",
                    "label": "Kagi"
                }]
                onChosen: (k) => {
                    return Prefs.launcherSearchEngine = k;
                }
            }

        }

    }

    SettingCard {
        title: "CLIPBOARD"

        SettingRow {
            title: "Clipboard history"
            description: "Keeps what you copy so the launcher can hand it back. Type > clip in the launcher, or pick Clipboard History from the command list. Needs cliphist installed."
            enabled: Clip.available
            disabledReason: "cliphist is not installed. Install it and the history starts recording straight away."

            M3Switch {
                checked: Prefs.clipboardEnabled && Clip.available
                enabled: Clip.available
                onToggled: (v) => {
                    return Prefs.clipboardEnabled = v;
                }
            }

        }

        SettingRow {
            title: "Clear clipboard history"
            description: "Discards every entry cliphist has stored, including images."
            enabled: Clip.available
            showDivider: false

            M3Button {
                text: "Clear history"
                variant: "text"
                destructive: true
                enabled: Clip.available
                onClicked: Prefs.askConfirm("Clear clipboard history?", "Every entry cliphist has stored is discarded, images included. This cannot be undone.", "Clear", Prefs.clearClipboardToken)
            }

        }

    }

}
