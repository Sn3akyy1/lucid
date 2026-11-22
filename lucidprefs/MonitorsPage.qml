import QtQuick
import Quickshell
import qs
import qs.lucidui

Column {
    id: page

    readonly property string offReason: I18n.tr("This display is switched off below.")

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
            bits.push(I18n.tr("switched off"));
        else
            bits.push(o.width + " × " + o.height + " at " + Monitors.rateLabel(o.refresh) + (o.scale !== 1 ? ", scaled " + Math.round(o.scale * 100) + "%" : ""));

        if (o.focused && Monitors.liveCount > 1)
            bits.push(I18n.tr("in use now"));

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

    spacing: Theme.dp(26)

    SettingCard {
        visible: Monitors.moduleProbed && !Monitors.moduleInstalled

        SettingRow {
            title: I18n.tr("Nothing here will be applied")
            warning: I18n.tr("Display rules come from Lucid's Hyprland config, and yours does not load them. Run the installer with --with-hypr, or copy modules/monitors.lua from Lucid into your own hypr config. Everything below still records what you pick.")
            showDivider: false
        }

    }

    SettingCard {
        visible: Monitors.probed && Monitors.liveCount === 0

        SettingRow {
            title: I18n.tr("No displays found")
            warning: I18n.tr("hyprctl reported no outputs at all, which usually means the shell is not talking to Hyprland.")
            showDivider: false
        }

    }

    SettingCard {
        title: I18n.tr("ARRANGEMENT")
        subtitle: I18n.tr("Where each display sits next to the others. Windows and the pointer cross at the edges you line up here.")
        visible: Monitors.liveCount > 0

        SettingRow {
            title: Monitors.liveCount > 1 ? I18n.tr("Drag a display to move it") : I18n.tr("This display")
            description: Monitors.liveCount > 1 ? I18n.tr("A display always lands against another one, never on top of it and with no gap between them. Pointing at one shows its number on the real display. Click one to pick it and move it with the arrow keys; double-click it to jump to its settings.") : I18n.tr("Double-click it to jump to its settings. With a second display plugged in, this is where you arrange them.")
            stacked: true
            showDivider: false

            Column {
                width: parent.width
                spacing: Theme.dp(16)

                MonitorMap {
                    id: monitorMap

                    width: parent.width
                    selected: page.focusKey
                    onPicked: (key) => page.focusKey = key
                    onOpened: (key) => page.reveal(key)
                }

                Text {
                    width: parent.width
                    visible: monitorMap.activeFocus && monitorMap.movable && monitorMap.placed.indexOf(page.focusKey) >= 0
                    text: monitorMap.dragging && monitorMap.byKeys ? I18n.tr("Enter puts it there, Escape puts it back.") : I18n.tr("The arrow keys move %1 round the others; with Shift they slide it along the edge it is on.", Monitors.shortLabel(page.focusKey))
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    wrapMode: Text.WordWrap
                }

                // the displays the map leaves out, with the way back into it
                Repeater {
                    model: Monitors.keys.filter((k) => {
                        return Monitors.output(k) !== null && (!Monitors.isOn(k) || Monitors.mirrorOf(k) !== "");
                    })

                    Row {
                        id: aside

                        required property string modelData
                        readonly property bool off: !Monitors.isOn(aside.modelData)

                        width: parent.width
                        spacing: Theme.dp(12)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.dp(34)
                            height: Theme.dp(22)
                            radius: Theme.shapeSm
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.outlineStrong
                            opacity: 0.8

                            Icon {
                                anchors.centerIn: parent
                                name: aside.off ? "visibility_off" : "screen_share"
                                size: Theme.dp(14)
                                color: Theme.subtext
                            }

                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.dp(46) - asideButton.width - Theme.dp(12)
                            text: aside.off ? I18n.tr("%1 (%2) is switched off.", Monitors.shortLabel(aside.modelData), Monitors.nameOf(aside.modelData)) : I18n.tr("%1 (%2) shows the same picture as %3.", Monitors.shortLabel(aside.modelData), Monitors.nameOf(aside.modelData), Monitors.mirrorOf(aside.modelData))
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBodyMd
                            wrapMode: Text.WordWrap
                        }

                        M3Button {
                            id: asideButton

                            anchors.verticalCenter: parent.verticalCenter
                            text: aside.off ? I18n.tr("Switch on") : I18n.tr("Stop mirroring")
                            variant: "tonal"
                            onClicked: {
                                if (aside.off)
                                    Monitors.setOn(aside.modelData, true);
                                else
                                    Monitors.setMirror(aside.modelData, "");
                            }
                        }

                    }

                }

                Row {
                    spacing: Theme.dp(8)

                    M3Button {
                        text: I18n.tr("Arrange automatically")
                        variant: "text"
                        visible: Monitors.liveCount > 1
                        enabled: Monitors.keys.some((k) => {
                            return !Monitors.isAuto(k);
                        })
                        onClicked: Monitors.autoArrange()
                    }

                    M3Button {
                        text: I18n.tr("Identify")
                        variant: "text"
                        onClicked: Monitors.identify()
                    }

                    M3Button {
                        text: I18n.tr("Settings for %1", Monitors.shortLabel(page.focusKey))
                        variant: "text"
                        visible: page.focusKey !== "" && Monitors.output(page.focusKey) !== null
                        onClicked: page.reveal(page.focusKey)
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
            spacing: Theme.dp(12)
            visible: unit.out !== null

            Column {
                width: parent.width
                spacing: 1

                Text {
                    leftPadding: Theme.dp(22)
                    text: unit.out ? (Monitors.liveCount > 1 ? Monitors.numberFor(unit.key) + " · " + unit.out.name : unit.out.name) : ""
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitleSm
                    font.variableAxes: Theme.axes(Theme.fontTitleSm, 600, 0)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.1
                }

                Text {
                    width: parent.width - Theme.dp(44)
                    leftPadding: Theme.dp(22)
                    text: page.summary(unit.key)
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    font.variableAxes: Theme.axes(Theme.fontBodyMd, 420, 0)
                    wrapMode: Text.WordWrap
                }

            }

            SettingCard {

                SettingRow {
                    id: resRow

                    readonly property var list: Monitors.resolutionsOf(unit.key)

                    title: I18n.tr("Resolution")
                    description: resRow.list.length > 1 ? "" : I18n.tr("The only mode this display offers.")
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

                    title: I18n.tr("Refresh rate")
                    description: rateRow.rates.length > 1 ? "" : I18n.tr("The only rate at this resolution.")
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

                    title: I18n.tr("Scale")
                    description: {
                        const room = scaleRow.room !== "" ? I18n.tr("%1 of room for windows", scaleRow.room) : "";
                        const wanted = Monitors.wantedScale(unit.key);
                        // the one picked does not fit this resolution, so another runs
                        if (Math.abs(wanted - scaleRow.scale) > 0.001)
                            return I18n.tr("%1. %2% does not divide this resolution evenly, so it runs at %3% here.", room, Math.round(wanted * 100), Math.round(scaleRow.scale * 100));

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
                    title: I18n.tr("Orientation")
                    description: I18n.tr("Which way up the picture is drawn, for a display that is physically turned.")
                    stacked: true
                    enabled: unit.on
                    disabledReason: page.offReason

                    M3Segmented {
                        width: Math.min(parent.width, Theme.dp(340))
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
                    title: I18n.tr("Adaptive sync")
                    description: I18n.tr("Lets the display follow whatever frame rate it is being fed, which smooths out games. Some panels flicker on the desktop with it always on, which is what the middle setting is for.")
                    stacked: true
                    enabled: unit.on
                    disabledReason: page.offReason

                    M3Segmented {
                        width: Math.min(parent.width, Theme.dp(400))
                        enabled: unit.on
                        current: Monitors.vrrOf(unit.key)
                        options: [{
                            "key": 0,
                            "label": I18n.tr("Off")
                        }, {
                            "key": 2,
                            "label": I18n.tr("Fullscreen only")
                        }, {
                            "key": 1,
                            "label": I18n.tr("Always")
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

                    title: I18n.tr("Mirror another display")
                    description: I18n.tr("Shows the same picture as the display you pick, at this one's own resolution. Its place in the arrangement above stops applying.")
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
                            "label": I18n.tr("Off")
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
                    title: I18n.tr("Use this display")
                    description: I18n.tr("Switching it off leaves it black and moves its workspaces to the others.")
                    visible: Monitors.liveCount > 1
                    enabled: Monitors.canTurnOff(unit.key)
                    disabledReason: I18n.tr("This is the only display left on, so it has to stay.")

                    M3Switch {
                        checked: unit.on
                        enabled: Monitors.canTurnOff(unit.key)
                        onToggled: (v) => {
                            return Monitors.setOn(unit.key, v);
                        }
                    }

                }

                SettingRow {
                    title: I18n.tr("Back to automatic")
                    description: I18n.tr("Drops everything set for this display and lets Hyprland pick its mode, scale and place again.")
                    visible: Monitors.isTouched(unit.key)
                    showDivider: false

                    M3Button {
                        text: I18n.tr("Reset")
                        variant: "text"
                        destructive: true
                        onClicked: Monitors.clear(unit.key)
                    }

                }

            }

        }

    }

    SettingCard {
        title: I18n.tr("SHELL")
        subtitle: I18n.tr("The bar, the dock, the volume popup and the toasts are one of each, so they sit together on one display unless you send the bar or the dock to another, or put a bar on every display. The wallpaper, the desktop menu and the lock screen are drawn on every display either way.")
        visible: Monitors.liveCount > 1

        SettingRow {
            title: I18n.tr("Put the shell on")
            resetKey: "monitorShellScreen"
            description: I18n.tr("Automatic leaves the choice to Hyprland, which is usually the display you were last on when the shell started. A display picked here is remembered by what it is, so it keeps the shell even if it comes back on another port. Widgets with no display of their own follow it too.")
            stacked: true

            M3Chips {
                width: parent.width
                current: Monitors.shellKey
                options: [{
                    "key": "",
                    "label": I18n.tr("Automatic")
                }].concat(page.displayChips)
                onChosen: (k) => {
                    return Monitors.setShellScreen(k);
                }
            }

        }

        SettingRow {
            title: I18n.tr("The bar on its own")
            resetKey: "monitorBarScreen"
            description: I18n.tr("For a bar that belongs on a different display to the dock, or one on every display. Left alone it goes wherever the shell went. With a bar everywhere, notification popups still come out of the shell's own display.")
            stacked: true

            M3Chips {
                width: parent.width
                current: Prefs.monitorBarScreen === "" ? "" : (Monitors.barEverywhere ? "*" : Monitors.keyOf(Monitors.barPlacement))
                options: [{
                    "key": "",
                    "label": I18n.tr("With the shell")
                }, {
                    "key": "*",
                    "label": I18n.tr("Every display")
                }].concat(page.displayChips)
                onChosen: (k) => {
                    return Monitors.setBarScreen(k);
                }
            }

        }

        SettingRow {
            title: I18n.tr("The dock on its own")
            resetKey: "monitorDockScreen"
            description: I18n.tr("Same for the dock, and the launcher it opens into.")
            stacked: true
            showDivider: false

            M3Chips {
                width: parent.width
                current: Prefs.monitorDockScreen === "" ? "" : Monitors.keyOf(Monitors.dockPlacement)
                options: [{
                    "key": "",
                    "label": I18n.tr("With the shell")
                }].concat(page.displayChips)
                onChosen: (k) => {
                    return Monitors.setDockScreen(k);
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("WORKSPACES")
        subtitle: I18n.tr("Workspaces 1 to %1 either open on whichever display you are on, or each belong to one display and always open there.", Monitors.workspaceCount)
        visible: Monitors.liveCount > 1 || Monitors.workspacesSplit

        SettingRow {
            title: I18n.tr("Workspaces")
            resetKey: "monitorWorkspaces"
            description: {
                if (!Monitors.workspacesSplit)
                    return I18n.tr("Shared: a workspace opens on the display you are on when you switch to it.");

                const stray = Monitors.strayWorkspaces;
                return I18n.tr("Per display: each workspace opens on its own display, and each display starts on its lowest one. Each set of displays keeps its own split, so plugging the same ones in again brings it back.") + (stray > 0 ? " " + stray + (stray === 1 ? I18n.tr(" workspace belongs") : I18n.tr(" workspaces belong")) + I18n.tr(" to a display that is not plugged in, so it opens wherever you are.") : "");
            }
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(320))
                current: Monitors.workspacesSplit ? "split" : "shared"
                options: [{
                    "key": "shared",
                    "label": I18n.tr("Shared")
                }, {
                    "key": "split",
                    "label": I18n.tr("Per display")
                }]
                onChosen: (key) => {
                    return Monitors.setWorkspaceMode(key);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Group by display")
            resetKey: "workspacesByDisplay"
            description: I18n.tr("The bar's workspace dots and the overview fall into one run per display, each under the display's number, and the accent follows the display you are on.")
            visible: Monitors.workspaceKeys.length > 1

            M3Switch {
                checked: Prefs.workspacesByDisplay
                onToggled: (v) => {
                    return Prefs.workspacesByDisplay = v;
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
                description: wsRow.mine.length > 0 ? I18n.tr("Starts on workspace %1. Pick a number to move that workspace here.", wsRow.mine[0]) : I18n.tr("No workspace of its own yet. Pick a number to move one here.")
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
            title: I18n.tr("Split evenly")
            description: I18n.tr("Workspaces 1 to %1 in runs, from the leftmost display to the rightmost.", Monitors.workspaceCount)
            showDivider: false

            M3Button {
                variant: "tonal"
                text: I18n.tr("Split")
                onClicked: Monitors.splitEvenly()
            }

        }

    }

    SettingCard {
        title: I18n.tr("NIGHT LIGHT")

        SettingRow {
            title: I18n.tr("Night light")
            description: NightLight.available ? I18n.tr("%1. Warms every display so evenings are easier on the eyes; hyprsunset does the tinting.", NightLight.status) : ""
            warning: NightLight.available ? "" : I18n.tr("hyprsunset is not installed, so there is nothing to warm the screen with.")

            M3Switch {
                checked: NightLight.active
                onToggled: (v) => {
                    return NightLight.set(v);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Warmth")
            resetKey: "nightLightTemp"
            description: I18n.tr("%1 K. Lower is warmer; 6500 K would leave the screen as it is.", NightLight.temperature)
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: (NightLight.maxTemp - NightLight.minTemp) / 100
                stepSize: 1
                showReadout: false
                value: (NightLight.maxTemp - NightLight.temperature) / 100
                onMoved: (v) => {
                    return Prefs.nightLightTemp = NightLight.maxTemp - Math.round(v) * 100;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Schedule")
            resetKey: "nightLightSchedule"
            description: {
                if (Prefs.nightLightSchedule === "sun") {
                    if (NightLight.sun.polar)
                        return I18n.tr("The sun doesn't set where you are today, so it runs 9 pm to 7 am.");

                    return I18n.tr("Sunset %1, sunrise %2", NightLight.clock(NightLight.sun.set), NightLight.clock(NightLight.sun.rise)) + (Loc.place !== "" ? " in " + Loc.place : "") + I18n.tr(". The place is the one Date and Time keeps.");
                }
                if (Prefs.nightLightSchedule === "custom")
                    return I18n.tr("On and off at the hours below.");

                return I18n.tr("Only when you turn it on. Turning it on or off during a schedule holds until the schedule next changes.");
            }
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(460))
                current: Prefs.nightLightSchedule
                options: [{
                    "key": "off",
                    "label": I18n.tr("By hand")
                }, {
                    "key": "sun",
                    "label": I18n.tr("Sunset to sunrise")
                }, {
                    "key": "custom",
                    "label": I18n.tr("Set hours")
                }]
                onChosen: (key) => {
                    return Prefs.nightLightSchedule = key;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Between")
            visible: Prefs.nightLightSchedule === "custom"
            description: I18n.tr("Written as 21:00. An end earlier than the start runs through midnight.")
            showDivider: false

            Row {
                spacing: Theme.dp(10)

                M3TextField {
                    id: nightFrom

                    width: Theme.dp(96)
                    placeholder: "21:00"
                    text: Prefs.minutesText(Prefs.nightLightFrom)
                    onAccepted: (v) => {
                        var m = Prefs.parseMinutes(v);
                        if (m >= 0)
                            Prefs.nightLightFrom = m;

                        nightFrom.text = Prefs.minutesText(Prefs.nightLightFrom);
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("to")
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                }

                M3TextField {
                    id: nightTo

                    width: Theme.dp(96)
                    placeholder: "07:00"
                    text: Prefs.minutesText(Prefs.nightLightTo)
                    onAccepted: (v) => {
                        var m = Prefs.parseMinutes(v);
                        if (m >= 0)
                            Prefs.nightLightTo = m;

                        nightTo.text = Prefs.minutesText(Prefs.nightLightTo);
                    }
                }

            }

        }

    }

    SettingCard {
        title: I18n.tr("RESET")
        visible: Monitors.liveCount > 0

        SettingRow {
            title: I18n.tr("Reset every display")
            description: I18n.tr("Every display back to its preferred mode, unscaled, placed automatically, and the shell back to wherever Hyprland puts it.")
            showDivider: false

            M3Button {
                text: I18n.tr("Reset")
                variant: "text"
                destructive: true
                onClicked: Prefs.askReset(I18n.tr("Reset every display?"), I18n.tr("Every display goes back to its preferred resolution and refresh rate, scale 100%, upright, placed automatically and switched on. The shell goes back to Hyprland's choice of display."), Prefs.resetMonitorsToken)
            }

        }

    }

}
