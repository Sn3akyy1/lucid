import QtQuick
import Quickshell
import qs

Column {
    id: page

    readonly property string offReason: "This display is switched off below."

    function inches(key) {
        const d = Monitors.diagonalInches(key);
        return d > 0 ? d.toFixed(1) + "″" : "";
    }

    // the line under each output's name: who made it and what it is doing now
    function summary(key) {
        const o = Monitors.output(key);
        if (!o)
            return "";

        const bits = [];
        const made = [o.make, o.model].filter((x) => {
            return x !== "" && x.indexOf("0x") !== 0;
        }).join(" ");
        if (made !== "")
            bits.push(made);
        else if (o.description !== "")
            bits.push(o.description);

        if (page.inches(key) !== "")
            bits.push(page.inches(key));

        if (o.disabled)
            bits.push("switched off");
        else
            bits.push(o.width + " × " + o.height + " at " + Monitors.rateLabel(o.refresh) + (o.scale !== 1 ? ", scaled " + Math.round(o.scale * 100) + "%" : ""));

        if (o.focused && Monitors.liveCount > 1)
            bits.push("in use now");

        return bits.join("  ·  ");
    }

    // the display the map is pointed at, so its settings can be jumped to
    property string focusKey: ""

    // the pane this page is loaded into, whatever it is called there
    function paneFlick() {
        let p = page.parent;
        while (p) {
            if (p.contentY !== undefined && p.contentHeight !== undefined)
                return p;

            p = p.parent;
        }
        return null;
    }

    function reveal(key) {
        page.focusKey = key;
        const flick = page.paneFlick();
        if (!flick)
            return ;

        for (let i = 0; i < units.count; i++) {
            const unit = units.itemAt(i);
            if (!unit || unit.key !== key)
                continue;

            const y = unit.mapToItem(flick.contentItem, 0, 0).y;
            flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), y - 16));
            return ;
        }
    }

    // the displays left to right, so the chips read the way they are arranged
    readonly property var displayChips: Monitors.orderedKeys.map((k) => {
        return {
            "key": k,
            "label": Monitors.nameOf(k)
        };
    })

    spacing: 26

    SettingCard {
        visible: Monitors.moduleProbed && !Monitors.moduleInstalled

        SettingRow {
            title: "Nothing here will be applied"
            warning: "Display rules come from Lucid's Hyprland config, and yours does not load them. Run the installer with --with-hypr, or copy modules/monitors.lua from Lucid into your own hypr config. Everything below still records what you pick."
            showDivider: false
        }

    }

    SettingCard {
        visible: Monitors.probed && Monitors.liveCount === 0

        SettingRow {
            title: "No displays found"
            warning: "hyprctl reported no outputs at all, which usually means the shell is not talking to Hyprland."
            showDivider: false
        }

    }

    SettingCard {
        title: "ARRANGEMENT"
        subtitle: "Where each display sits next to the others. Windows and the pointer cross at the edges you line up here."
        visible: Monitors.liveCount > 0

        SettingRow {
            title: Monitors.liveCount > 1 ? "Drag a display to move it" : "This display"
            description: Monitors.liveCount > 1 ? "An edge dragged near another one snaps to it, so there are no gaps between them. Click one to jump to its settings." : "Click it to jump to its settings. With a second display plugged in, this is where you arrange them."
            stacked: true
            showDivider: false

            Column {
                width: parent.width
                spacing: 16

                MonitorMap {
                    width: parent.width
                    selected: page.focusKey
                    onPicked: (key) => page.reveal(key)
                }

                Row {
                    spacing: 8

                    M3Button {
                        text: "Arrange automatically"
                        variant: "text"
                        visible: Monitors.liveCount > 1
                        enabled: Monitors.keys.some((k) => {
                            return !Monitors.isAuto(k);
                        })
                        onClicked: Monitors.autoArrange()
                    }

                    M3Button {
                        text: "Identify"
                        variant: "text"
                        onClicked: Monitors.identify()
                    }

                }

            }

        }

    }

    Repeater {
        id: units

        model: Monitors.keys

        Column {
            id: unit

            required property string modelData
            readonly property string key: unit.modelData
            readonly property var out: Monitors.output(unit.key)
            readonly property bool on: Monitors.isOn(unit.key)

            width: parent ? parent.width : 0
            spacing: 12
            visible: unit.out !== null

            Column {
                width: parent.width
                spacing: 1

                Text {
                    leftPadding: 22
                    text: unit.out ? (Monitors.liveCount > 1 ? Monitors.numberFor(unit.key) + " · " + unit.out.name : unit.out.name) : ""
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitleSm
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.1
                }

                Text {
                    width: parent.width - 44
                    leftPadding: 22
                    text: page.summary(unit.key)
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    wrapMode: Text.WordWrap
                }

            }

            SettingCard {

                SettingRow {
                    id: resRow

                    readonly property var list: Monitors.resolutionsOf(unit.key)

                    title: "Resolution"
                    description: resRow.list.length > 1 ? "" : "The only mode this display offers."
                    stacked: true
                    enabled: unit.on
                    disabledReason: page.offReason

                    M3Chips {
                        width: parent.width
                        enabled: unit.on
                        interactive: resRow.list.length > 1
                        current: Monitors.currentRes(unit.key)
                        options: resRow.list.map((r) => {
                            return {
                                "key": r,
                                "label": Monitors.resLabel(r)
                            };
                        })
                        onChosen: (k) => {
                            return Monitors.setResolution(unit.key, k);
                        }
                    }

                }

                SettingRow {
                    id: rateRow

                    readonly property var rates: Monitors.ratesOf(unit.key, Monitors.currentRes(unit.key))

                    title: "Refresh rate"
                    description: rateRow.rates.length > 1 ? "" : "The only rate at this resolution."
                    stacked: true
                    enabled: unit.on
                    disabledReason: page.offReason

                    M3Chips {
                        width: parent.width
                        enabled: unit.on
                        interactive: rateRow.rates.length > 1
                        current: Monitors.selectedRate(unit.key)
                        options: rateRow.rates.map((hz) => {
                            return {
                                "key": hz,
                                "label": Monitors.rateLabel(hz)
                            };
                        })
                        onChosen: (k) => {
                            return Monitors.setRate(unit.key, k);
                        }
                    }

                }

                SettingRow {
                    id: scaleRow

                    readonly property real scale: Monitors.scaleOf(unit.key)
                    readonly property string room: Monitors.logicalSize(unit.key, scaleRow.scale)

                    title: "Scale"
                    description: {
                        const room = scaleRow.room !== "" ? scaleRow.room + " of room for windows" : "";
                        if (!Monitors.isCleanScale(unit.key, scaleRow.scale))
                            return room + ". This scale does not divide the panel evenly, so edges and small text may look soft.";

                        return room + ".";
                    }
                    stacked: true
                    enabled: unit.on
                    disabledReason: page.offReason

                    M3Chips {
                        width: parent.width
                        enabled: unit.on
                        current: scaleRow.scale
                        options: Monitors.scalesFor(unit.key).map((v) => {
                            return {
                                "key": v,
                                "label": Math.round(v * 100) + "%"
                            };
                        })
                        onChosen: (k) => {
                            return Monitors.setScale(unit.key, k);
                        }
                    }

                }

                SettingRow {
                    title: "Orientation"
                    description: "Which way up the picture is drawn, for a display that is physically turned."
                    stacked: true
                    enabled: unit.on
                    disabledReason: page.offReason

                    M3Segmented {
                        width: Math.min(parent.width, 340)
                        enabled: unit.on
                        current: Monitors.transformOf(unit.key)
                        options: Monitors.transforms.map((t) => {
                            return {
                                "key": t.key,
                                "label": t.short
                            };
                        })
                        onChosen: (k) => {
                            return Monitors.setTransform(unit.key, k);
                        }
                    }

                }

                SettingRow {
                    title: "Adaptive sync"
                    description: "Lets the display follow whatever frame rate it is being fed, which smooths out games. Some panels flicker on the desktop with it always on, which is what the middle setting is for."
                    stacked: true
                    enabled: unit.on
                    disabledReason: page.offReason

                    M3Segmented {
                        width: Math.min(parent.width, 400)
                        enabled: unit.on
                        current: Monitors.vrrOf(unit.key)
                        options: [{
                            "key": 0,
                            "label": "Off"
                        }, {
                            "key": 2,
                            "label": "Fullscreen only"
                        }, {
                            "key": 1,
                            "label": "Always"
                        }]
                        onChosen: (k) => {
                            return Monitors.setVrr(unit.key, k);
                        }
                    }

                }

                SettingRow {
                    id: mirrorRow

                    readonly property var others: Monitors.outputs.filter((o) => {
                        return o.key !== unit.key && Monitors.isOn(o.key);
                    })

                    title: "Mirror another display"
                    description: "Shows the same picture as the display you pick, at this one's own resolution. Its place in the arrangement above stops applying."
                    stacked: true
                    visible: Monitors.liveCount > 1
                    enabled: unit.on
                    disabledReason: page.offReason

                    M3Chips {
                        width: parent.width
                        enabled: unit.on
                        current: Monitors.mirrorOf(unit.key)
                        options: [{
                            "key": "",
                            "label": "Off"
                        }].concat(mirrorRow.others.map((o) => {
                            return {
                                "key": o.name,
                                "label": o.name
                            };
                        }))
                        onChosen: (k) => {
                            return Monitors.setMirror(unit.key, k);
                        }
                    }

                }

                SettingRow {
                    title: "Use this display"
                    description: "Switching it off leaves it black and moves its workspaces to the others."
                    visible: Monitors.liveCount > 1
                    enabled: Monitors.canTurnOff(unit.key)
                    disabledReason: "This is the only display left on, so it has to stay."

                    M3Switch {
                        checked: unit.on
                        enabled: Monitors.canTurnOff(unit.key)
                        onToggled: (v) => {
                            return Monitors.setOn(unit.key, v);
                        }
                    }

                }

                SettingRow {
                    title: "Back to automatic"
                    description: "Drops everything set for this display and lets Hyprland pick its mode, scale and place again."
                    visible: Monitors.isTouched(unit.key)
                    showDivider: false

                    M3Button {
                        text: "Reset"
                        variant: "text"
                        destructive: true
                        onClicked: Monitors.clear(unit.key)
                    }

                }

            }

        }

    }

    SettingCard {
        title: "SHELL"
        subtitle: "The bar, the dock, the volume popup and the toasts are one of each, so they sit together on one display unless you send the bar or the dock to another. The wallpaper, the desktop menu and the lock screen are drawn on every display either way."
        visible: Monitors.liveCount > 1

        SettingRow {
            title: "Put the shell on"
            resetKey: "monitorShellScreen"
            description: "Automatic leaves the choice to Hyprland, which is usually the display you were last on when the shell started. A display picked here is remembered by what it is, so it keeps the shell even if it comes back on another port. Widgets with no display of their own follow it too."
            stacked: true

            M3Chips {
                width: parent.width
                current: Monitors.shellKey
                options: [{
                    "key": "",
                    "label": "Automatic"
                }].concat(page.displayChips)
                onChosen: (k) => {
                    return Monitors.setShellScreen(k);
                }
            }

        }

        SettingRow {
            title: "The bar on its own"
            resetKey: "monitorBarScreen"
            description: "For a bar that belongs on a different display to the dock. Left alone it goes wherever the shell went."
            stacked: true

            M3Chips {
                width: parent.width
                current: Prefs.monitorBarScreen === "" ? "" : Monitors.keyOf(Monitors.barPlacement)
                options: [{
                    "key": "",
                    "label": "With the shell"
                }].concat(page.displayChips)
                onChosen: (k) => {
                    return Monitors.setBarScreen(k);
                }
            }

        }

        SettingRow {
            title: "The dock on its own"
            resetKey: "monitorDockScreen"
            description: "Same for the dock, and the launcher it opens into."
            stacked: true
            showDivider: false

            M3Chips {
                width: parent.width
                current: Prefs.monitorDockScreen === "" ? "" : Monitors.keyOf(Monitors.dockPlacement)
                options: [{
                    "key": "",
                    "label": "With the shell"
                }].concat(page.displayChips)
                onChosen: (k) => {
                    return Monitors.setDockScreen(k);
                }
            }

        }

    }

    SettingCard {
        title: "WORKSPACES"
        subtitle: "Workspaces 1 to " + Monitors.workspaceCount + " either open on whichever display you are on, or each belong to one display and always open there."
        visible: Monitors.liveCount > 1 || Monitors.workspacesSplit

        SettingRow {
            title: "Workspaces"
            resetKey: "monitorWorkspaces"
            description: {
                if (!Monitors.workspacesSplit)
                    return "Shared: a workspace opens on the display you are on when you switch to it.";

                const stray = Monitors.strayWorkspaces;
                return "Per display: each workspace opens on its own display, and each display starts on its lowest one." + (stray > 0 ? " " + stray + (stray === 1 ? " workspace belongs" : " workspaces belong") + " to a display that is not plugged in, so it opens wherever you are." : "");
            }
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, 320)
                current: Monitors.workspacesSplit ? "split" : "shared"
                options: [{
                    "key": "shared",
                    "label": "Shared"
                }, {
                    "key": "split",
                    "label": "Per display"
                }]
                onChosen: (key) => {
                    return Monitors.setWorkspaceMode(key);
                }
            }

        }

        Repeater {
            model: Monitors.workspacesSplit ? Monitors.workspaceKeys : []

            SettingRow {
                id: wsRow

                required property var modelData
                readonly property var mine: Monitors.workspacesOf(wsRow.modelData)

                title: Monitors.nameOf(wsRow.modelData)
                description: wsRow.mine.length > 0 ? "Starts on workspace " + wsRow.mine[0] + ". Pick a number to move that workspace here." : "No workspace of its own yet. Pick a number to move one here."
                stacked: true

                M3Chips {
                    width: parent.width
                    multi: true
                    selectedKeys: wsRow.mine.map((n) => {
                        return String(n);
                    })
                    options: Array.from({
                        "length": Monitors.workspaceCount
                    }, (_, i) => {
                        return {
                            "key": String(i + 1),
                            "label": String(i + 1)
                        };
                    })
                    onChosen: (k) => {
                        return Monitors.assignWorkspace(parseInt(k, 10), wsRow.modelData);
                    }
                }

            }

        }

        SettingRow {
            visible: Monitors.workspacesSplit && Monitors.workspaceKeys.length > 1
            title: "Split evenly"
            description: "Workspaces 1 to " + Monitors.workspaceCount + " in runs, from the leftmost display to the rightmost."
            showDivider: false

            M3Button {
                variant: "tonal"
                text: "Split"
                onClicked: Monitors.splitEvenly()
            }

        }

    }

    SettingCard {
        title: "RESET"
        visible: Monitors.liveCount > 0

        SettingRow {
            title: "Reset every display"
            description: "Every display back to its preferred mode, unscaled, placed automatically, and the shell back to wherever Hyprland puts it."
            showDivider: false

            M3Button {
                text: "Reset"
                variant: "text"
                destructive: true
                onClicked: Prefs.askReset("Reset every display?", "Every display goes back to its preferred resolution and refresh rate, scale 100%, upright, placed automatically and switched on. The shell goes back to Hyprland's choice of display.", Prefs.resetMonitorsToken)
            }

        }

    }

}
