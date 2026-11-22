import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.lucidicons

// one bar module's options, in edit mode's sheet: whether it shows, its looks,
// where the rest of its settings live, and the options it has of its own. every
// module's rows are here; only its own are visible
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
        "bar": I18n.tr("Bar"),
        "workspaces": I18n.tr("Workspaces"),
        "datetime": I18n.tr("Date & Time"),
        "notifications": I18n.tr("Notifications")
    })
    readonly property bool barOn: Prefs.barEnabled
    readonly property bool away: !!card.mod && !!card.mod.when && Prefs.barModulesAway.indexOf(card.moduleId) !== -1
    // the power module's actions: the picked ones in their order, then the rest
    readonly property var powerCatalogue: [{
        "id": "lock",
        "label": I18n.tr("Lock")
    }, {
        "id": "suspend",
        "label": I18n.tr("Suspend")
    }, {
        "id": "hibernate",
        "label": I18n.tr("Hibernate"),
        "note": I18n.tr("only where the machine can")
    }, {
        "id": "logout",
        "label": I18n.tr("Log out")
    }, {
        "id": "reboot",
        "label": I18n.tr("Restart")
    }, {
        "id": "shutdown",
        "label": I18n.tr("Shut down")
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

    // one of the user's own tiles brought into view, its name ready to change
    function revealOwnTile(key) {
        let flick = card.parent;
        while (flick && (flick.contentY === undefined || flick.contentHeight === undefined))
            flick = flick.parent;
        for (let i = 0; i < ownTileRepeater.count; i++) {
            const ed = ownTileRepeater.itemAt(i);
            if (!ed || ed.key !== key)
                continue;

            if (flick) {
                const y = ed.mapToItem(flick.contentItem, 0, 0).y;
                flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), y - Theme.dp(90)));
            }
            ed.flash();
            return ;
        }
    }

    // a part of the card a link can land on, or null for its top
    function partItem(name) {
        return ({
            "layout": layoutRow,
            "owntiles": ownTilesRow,
            "gamemode": gameModeRow
        })[name] || null;
    }

    // the part Prefs.openBarModule asked for, until the card has scrolled to it
    property string pendingPart: ""
    property int revealTries: 0

    function askReveal() {
        if (Prefs.barModulePart === "")
            return ;

        card.pendingPart = Prefs.barModulePart;
        card.revealTries = 0;
        revealLater.restart();
        // every card that heard it has it now (edit mode has a sheet per display)
        Qt.callLater(() => {
            return Prefs.barModulePart = "";
        });
    }

    // scrolls whatever holds the card (edit mode's sheet) to the part asked for
    function revealPart() {
        const part = card.partItem(card.pendingPart);
        let flick = card.parent;
        while (flick && (flick.contentY === undefined || flick.contentHeight === undefined))
            flick = flick.parent;
        const y = part && flick ? part.mapToItem(flick.contentItem, 0, 0).y : 0;
        // the sheet lays itself out once its window shows; until then the part sits at 0
        if (y <= 0 && part && flick && ++card.revealTries < 30)
            return ;

        revealLater.stop();
        card.pendingPart = "";
        if (y > 0)
            flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), y - Theme.dp(24)));

    }

    Component.onCompleted: card.askReveal()

    Timer {
        id: revealLater

        interval: 60
        repeat: true
        onTriggered: card.revealPart()
    }

    Connections {
        function onBarModulePartChanged() {
            card.askReveal();
        }

        target: Prefs
    }

    function setPower(list) {
        Prefs.powerModuleActions = list.join(",");
    }

    // the sheet's header names it already
    visible: card.mod !== null

    SettingRow {
        id: showRow

        title: I18n.tr("Show in the bar")
        description: (Prefs[card.mod ? card.mod.key : ""] === true ? I18n.tr("In the %1 group. Drag it along the bar to move it, or down off the bar to take it out.", card.groupName) : I18n.tr("Switched on, it goes back where it was.")) + (card.away ? I18n.tr(" Not in the bar right now: it shows %1.", card.mod.when) : "")
        enabled: card.barOn
        disabledReason: I18n.tr("The bar is switched off, so this module has nothing to appear in.")
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
        title: I18n.tr("In the bar")
        description: I18n.tr("How it looks until you open it.")
        stacked: true
        showDivider: false

        Flow {
            id: styleFlow

            // the widest sample sets every tile's width, so the row stays even
            readonly property int tileWidth: {
                let w = 0;
                for (let i = 0; i < styleFlow.children.length; i++) w = Math.max(w, styleFlow.children[i].needWidth || 0)
                return w;
            }

            width: parent.width
            spacing: Theme.dp(10)

            Repeater {
                model: card.mod && card.mod.styles ? card.mod.styles : []

                BarStyleTile {
                    required property var modelData

                    moduleId: card.moduleId
                    prefKey: card.mod ? card.mod.style : ""
                    style: modelData
                    minWidth: styleFlow.tileWidth
                }

            }

        }

    }

    SettingRow {
        visible: !!card.mod && !!card.mod.panelStyles
        title: I18n.tr("Opened")
        description: I18n.tr("How its panel looks.")
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
    SettingRow {
        visible: card.moduleId === "workspaces"
        title: I18n.tr("How many")
        resetKey: "workspacesShown"
        description: I18n.tr("The ones it always shows. A workspace past them still shows up while it exists.")
        stacked: true
        showDivider: false

        M3Slider {
            width: parent.width
            from: 1
            to: 10
            stepSize: 1
            value: Prefs.workspacesShown
            onMoved: (v) => {
                return Prefs.workspacesShown = Math.round(v);
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "workspaces"
        title: I18n.tr("Wheel to switch")
        resetKey: "workspacesWheel"
        description: I18n.tr("The wheel over it moves to the next or the previous workspace.")
        showDivider: false

        M3Switch {
            checked: Prefs.workspacesWheel
            onToggled: (v) => {
                return Prefs.workspacesWheel = v;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "workspaces"
        title: I18n.tr("Use legacy workspace")
        resetKey: "workspacesLegacy"
        description: I18n.tr("The overview grows out of the module in the middle of the screen, instead of sliding down from the top.")
        showDivider: false

        M3Switch {
            checked: Prefs.workspacesLegacy
            onToggled: (v) => {
                return Prefs.workspacesLegacy = v;
            }
        }

    }

    // clock
    SettingRow {
        id: clockDate

        visible: card.moduleId === "clock"
        title: I18n.tr("Date")
        resetKey: "clockDateFormat"
        description: I18n.tr("How the date reads beside or under the time.")
        enabled: Prefs.clockShowDate
        disabledReason: I18n.tr("The date is switched off on the Date & Time page.")
        stacked: true
        showDivider: false

        M3Segmented {
            width: Math.min(parent.width, Theme.dp(520))
            enabled: clockDate.enabled
            current: Prefs.clockDateFormat
            options: [{
                "key": "dayMonth",
                "label": Loc.now().toLocaleDateString(I18n.locale, I18n.tr("ddd, dd/MM"))
            }, {
                "key": "short",
                "label": Loc.now().toLocaleDateString(I18n.locale, I18n.tr("ddd d"))
            }, {
                "key": "long",
                "label": Loc.now().toLocaleDateString(I18n.locale, I18n.tr("ddd d MMM"))
            }, {
                "key": "numeric",
                "label": Loc.now().toLocaleDateString(I18n.locale, I18n.locale.dateFormat(Locale.ShortFormat))
            }]
            onChosen: (key) => {
                return Prefs.clockDateFormat = key;
            }
        }

    }

    // media
    SettingRow {
        visible: card.moduleId === "media"
        title: I18n.tr("Hide it when nothing plays")
        resetKey: "mediaHideIdle"
        description: I18n.tr("Off, it says Nothing playing; on, it leaves the bar until a player starts.")
        showDivider: false

        M3Switch {
            checked: Prefs.mediaHideIdle
            onToggled: (v) => {
                return Prefs.mediaHideIdle = v;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "media"
        title: I18n.tr("Artist before the title")
        resetKey: "mediaArtist"
        description: I18n.tr("The panel always names both.")
        showDivider: false

        M3Switch {
            checked: Prefs.mediaArtist
            onToggled: (v) => {
                return Prefs.mediaArtist = v;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "media"
        title: I18n.tr("Longest the track gets")
        resetKey: "mediaTitleWidth"
        description: I18n.tr("A longer one scrolls while it plays.")
        enabled: Prefs.mediaStyle !== "compact"
        disabledReason: I18n.tr("Compact shows no track.")
        stacked: true
        showDivider: false

        M3Slider {
            width: parent.width
            enabled: Prefs.mediaStyle !== "compact"
            from: 80
            to: 320
            stepSize: 10
            suffix: " px"
            value: Prefs.mediaTitleWidth
            onMoved: (v) => {
                return Prefs.mediaTitleWidth = Math.round(v);
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "media"
        title: I18n.tr("Play button")
        resetKey: "mediaPlayButton"
        description: I18n.tr("Off, a click opens the player and the panel has the buttons.")
        showDivider: false

        M3Switch {
            checked: Prefs.mediaPlayButton
            onToggled: (v) => {
                return Prefs.mediaPlayButton = v;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "media"
        title: I18n.tr("Wheel for the volume")
        resetKey: "mediaWheelVolume"
        description: I18n.tr("The wheel over it turns the player's own volume up or down.")
        showDivider: false

        M3Switch {
            checked: Prefs.mediaWheelVolume
            onToggled: (v) => {
                return Prefs.mediaWheelVolume = v;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "media"
        title: I18n.tr("Lyrics button")
        resetKey: "mediaLyrics"
        description: I18n.tr("In the panel, beside Identify: the words of the song, from lrclib.net, looked up only while the page is open.")
        showDivider: false

        M3Switch {
            checked: Prefs.mediaLyrics
            onToggled: (v) => {
                return Prefs.mediaLyrics = v;
            }
        }

    }

    // notifications
    // system: what its pill shows, then the panel
    SettingRow {
        visible: card.moduleId === "system"
        title: I18n.tr("In the bar")
        resetKey: "systemBarItems"
        description: I18n.tr("What the module shows before it is opened. A click on the keyboard layout switches to the next one. At least one stays on.")
        stacked: true
        showDivider: false

        M3Chips {
            id: barItemChips

            // the keyboard layout predates the list and keeps its own pref
            readonly property var items: String(Prefs.systemBarItems).split(",").filter((k) => {
                return k !== "";
            })

            width: parent.width
            multi: true
            selectedKeys: (Prefs.showKbLayout ? ["kb"] : []).concat(barItemChips.items)
            options: [{
                "key": "kb",
                "label": I18n.tr("Keyboard layout")
            }, {
                "key": "wifi",
                "label": I18n.tr("Network")
            }, {
                "key": "bluetooth",
                "label": I18n.tr("Bluetooth")
            }, {
                "key": "volume",
                "label": I18n.tr("Volume")
            }, {
                "key": "level",
                "label": I18n.tr("Volume level")
            }, {
                "key": "mic",
                "label": I18n.tr("Microphone")
            }, {
                "key": "battery",
                "label": I18n.tr("Battery")
            }]
            onChosen: (key) => {
                const on = barItemChips.selectedKeys.indexOf(key) !== -1;
                if (on && barItemChips.selectedKeys.length === 1)
                    return ;

                if (key === "kb") {
                    Prefs.showKbLayout = !on;
                    return ;
                }
                const list = on ? barItemChips.items.filter((k) => {
                    return k !== key;
                }) : barItemChips.items.concat([key]);
                Prefs.systemBarItems = ["wifi", "bluetooth", "volume", "level", "mic", "battery"].filter((k) => {
                    return list.indexOf(k) !== -1;
                }).join(",");
            }
        }

    }

    SettingRow {
        id: layoutRow

        visible: card.moduleId === "system"
        title: I18n.tr("Layout")
        resetKey: "systemBlocks"
        resetVisible: Prefs.isModified("systemBlocks") || Prefs.isModified("systemGrid") || Prefs.isModified("systemBlockStyles")
        resetAction: "prefs:systemBlocks,systemGrid,systemBlockStyles"
        description: I18n.tr("The control centre stays one column until you lay it out as a bento grid in its own editor: the panel lifts off the bar to the middle of the display, with everything you can add on its left and each block's looks, size and contents on its right. A reset brings the column back.")
        stacked: true
        showDivider: false

        M3Button {
            text: I18n.tr("Open the editor")
            iconPath: "edit"
            variant: "filled"
            onClicked: Edit.requestStudio("system", Edit.sheetScreen)
        }

    }

    SettingRow {
        visible: card.moduleId === "system"
        title: I18n.tr("Cards behind every block")
        resetKey: "systemBlockCards"
        description: I18n.tr("Media and the gauges always sit on a card; on, the tiles and the sliders get one too, for an even bento look.")
        showDivider: false

        M3Switch {
            checked: Prefs.systemBlockCards
            onToggled: (v) => {
                return Prefs.systemBlockCards = v;
            }
        }

    }

    SettingRow {
        id: ownTilesRow

        visible: card.moduleId === "system"
        title: I18n.tr("Your own tiles")
        resetKey: "systemOwnTiles"
        description: I18n.tr("Tiles that run commands of yours, for what Lucid has no tile for: a VPN, a server, a script. With only the first command a tap runs it; give one to turn it off too and it is a switch, kept right by the check when something else changes it. They run through bash, so pipes and && work. A new one goes onto the panel with the small tiles, and the shelf above holds it when it is off.")
        stacked: true
        showDivider: false

        Column {
            width: parent.width
            spacing: Theme.dp(8)

            Repeater {
                id: ownTileRepeater

                model: Prefs.systemOwnTileList

                OwnTileEditor {
                    required property var modelData

                    tile: modelData
                }

            }

            M3Button {
                text: I18n.tr("Add a tile")
                iconPath: "add"
                variant: "tonal"
                onClicked: Prefs.addSystemOwnTile()
            }

        }

    }

    SettingRow {
        visible: card.moduleId === "system"
        title: I18n.tr("Header buttons")
        resetKey: "systemHeaderButtons"
        description: I18n.tr("Beside the date, in this order.")
        stacked: true
        showDivider: false

        OrderedPicker {
            width: parent.width
            value: Prefs.systemHeaderButtons
            catalogue: [{
                "id": "edit",
                "label": I18n.tr("Edit"),
                "note": I18n.tr("opens the layout editor")
            }, {
                "id": "settings",
                "label": I18n.tr("Settings")
            }, {
                "id": "lock",
                "label": I18n.tr("Lock")
            }, {
                "id": "power",
                "label": I18n.tr("Power"),
                "note": I18n.tr("suspend, restart, shut down")
            }]
            onPicked: (v) => {
                return Prefs.systemHeaderButtons = v;
            }
        }

    }

    SettingRow {
        id: gameModeRow

        visible: card.moduleId === "system"
        title: I18n.tr("Game mode: turn on")
        resetKey: "gameModeOnCmd"
        description: I18n.tr("Left empty, with the command below, game mode is Lucid's own: animations, blur, shadows, rounded corners and gaps go off, and come back as they were. Or give a shell command of your own for the Game mode tile (add it from the shelf in the System module's layout); it runs through bash, so pipes and && work.")
        stacked: true
        showDivider: false

        M3TextField {
            width: parent.width
            placeholder: I18n.tr("Lucid's own, or e.g. sudo -n g15-gamemode on")
            text: Prefs.gameModeOnCmd
            onAccepted: (v) => {
                return Prefs.gameModeOnCmd = v;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "system"
        title: I18n.tr("Game mode: turn off")
        resetKey: "gameModeOffCmd"
        description: I18n.tr("The command that switches your own game mode off again. Leave both empty for Lucid's.")
        stacked: true
        showDivider: false

        M3TextField {
            width: parent.width
            placeholder: I18n.tr("Lucid's own, or e.g. sudo -n g15-gamemode off")
            text: Prefs.gameModeOffCmd
            onAccepted: (v) => {
                return Prefs.gameModeOffCmd = v;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "system"
        title: I18n.tr("Game mode: status check")
        resetKey: "gameModeStatusCmd"
        description: I18n.tr("Optional, and not needed for Lucid's own. Exits 0 while your game mode is on, so the toggle stays right when something else (a keybind, a script) changes it. Checked whenever the panel opens.")
        showDivider: false
        stacked: true

        M3TextField {
            width: parent.width
            placeholder: I18n.tr("e.g. test -f /run/g15-gamemode.state")
            text: Prefs.gameModeStatusCmd
            onAccepted: (v) => {
                return Prefs.gameModeStatusCmd = v;
            }
        }

    }

    // system tray
    SettingRow {
        visible: card.moduleId === "tray"
        title: I18n.tr("Icon colours")
        resetKey: "trayIconColor"
        description: I18n.tr("As each app draws them, or in the shell's colours: grey from the text, or one of the palette's colours. Their light and shade stay either way. An app Lucid has its own icon for shows that instead, unless legacy icons are on.")
        stacked: true
        showDivider: false

        M3Segmented {
            width: Math.min(parent.width, Theme.dp(600))
            current: Prefs.trayIconColor
            options: [{
                "key": "original",
                "label": I18n.tr("Original")
            }, {
                "key": "grey",
                "label": I18n.tr("Grey")
            }, {
                "key": "secondary",
                "label": I18n.tr("Secondary")
            }, {
                "key": "tertiary",
                "label": I18n.tr("Tertiary")
            }, {
                "key": "accent",
                "label": I18n.tr("Accent")
            }]
            onChosen: (key) => {
                return Prefs.trayIconColor = key;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "tray"
        title: I18n.tr("Apps in the tray")
        resetKey: "trayHidden"
        description: SystemTray.items.values.length > 0 ? I18n.tr("The ones running now. One switched off stays out of the bar and the panel until you switch it back on.") : I18n.tr("Nothing is in the tray right now. Apps show up here while they run.")
        stacked: true
        showDivider: false

        Column {
            width: parent.width
            spacing: Theme.dp(6)

            Repeater {
                model: card.moduleId === "tray" ? SystemTray.items.values : []

                Rectangle {
                    id: trayRow

                    required property var modelData
                    // an app whose job the bar does elsewhere (blueman, the system
                    // module's bluetooth) is never in the tray
                    readonly property bool builtin: Tray.isBuiltin(trayRow.modelData)
                    readonly property bool shownInBar: !Tray.isHidden(trayRow.modelData)
                    readonly property string lucidSlot: Tray.slotOf(trayRow.modelData)

                    width: parent.width
                    height: Theme.dp(52)
                    radius: Theme.radiusMd
                    color: Theme.bgSunken

                    Item {
                        id: trayRowIcon

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.dp(14)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(24)
                        height: Theme.dp(24)
                        opacity: trayRow.shownInBar ? 1 : 0.4

                        // never off the main thread: an icon theme source loaded
                        // asynchronously takes the whole shell down
                        Image {
                            anchors.fill: parent
                            visible: trayRow.lucidSlot === ""
                            source: trayRow.lucidSlot === "" ? Tray.iconSource(trayRow.modelData.icon) : ""
                            sourceSize.width: Theme.dp(24) * 2
                            sourceSize.height: Theme.dp(24) * 2
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            asynchronous: false
                        }

                        Loader {
                            anchors.centerIn: parent
                            active: trayRow.lucidSlot !== ""

                            sourceComponent: TonalIcon {
                                size: Theme.dp(24)
                                slot: trayRow.lucidSlot
                            }

                        }

                    }

                    Column {
                        anchors.left: trayRowIcon.right
                        anchors.leftMargin: Theme.dp(12)
                        anchors.right: trayRowSwitch.left
                        anchors.rightMargin: Theme.dp(12)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: Tray.nameOf(trayRow.modelData)
                            color: trayRow.shownInBar ? Theme.text : Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBodyLg
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: trayRow.builtin
                            text: I18n.tr("In the system module instead")
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            elide: Text.ElideRight
                        }

                    }

                    M3Switch {
                        id: trayRowSwitch

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.dp(12)
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: !trayRow.builtin
                        checked: trayRow.shownInBar
                        onToggled: (v) => {
                            return Tray.setHidden(trayRow.modelData, !v);
                        }
                    }

                }

            }

        }

    }

    // privacy
    SettingRow {
        visible: card.moduleId === "privacy"
        title: I18n.tr("Watch")
        resetKey: "privacyWatch"
        description: I18n.tr("What makes the module show up. At least one stays on.")
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
                "label": I18n.tr("Microphone")
            }, {
                "key": "camera",
                "label": I18n.tr("Camera")
            }, {
                "key": "screen",
                "label": I18n.tr("Screen")
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
        title: I18n.tr("Tell me when something starts")
        resetKey: "privacyToast"
        description: I18n.tr("A toast names the app the moment it starts using the microphone, the camera or the screen. Lucid's own recording, which you start yourself, is left out.")
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
        title: I18n.tr("Keep its place in the bar")
        resetKey: "privacyAlwaysShown"
        description: I18n.tr("A quiet shield stays when nothing is in use, so the modules beside it never shift.")
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
        title: I18n.tr("Actions")
        resetKey: "powerModuleActions"
        description: I18n.tr("The ones switched on show in the panel, top to bottom in this order. At least one stays.")
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
        title: I18n.tr("Ask twice")
        resetKey: "powerModuleConfirm"
        description: I18n.tr("Log out, restart and shut down wait for a second click within three seconds, so a stray one does nothing.")
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
        title: I18n.tr("Show how long it has been up")
        resetKey: "powerModuleUptime"
        description: I18n.tr("The time since the machine started, at the top of the panel.")
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
        title: I18n.tr("Shows")
        resetKey: "windowModuleText"
        description: I18n.tr("What the pill reads in the bar, or only the app's icon. The panel always has both.")
        stacked: true
        showDivider: false

        M3Segmented {
            width: Math.min(parent.width, Theme.dp(480))
            current: Prefs.windowModuleText
            options: [{
                "key": "title",
                "label": I18n.tr("Title")
            }, {
                "key": "app",
                "label": I18n.tr("App name")
            }, {
                "key": "both",
                "label": I18n.tr("Both")
            }, {
                "key": "icon",
                "label": I18n.tr("Icon only")
            }]
            onChosen: (key) => {
                return Prefs.windowModuleText = key;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "window"
        title: I18n.tr("Longest it gets")
        resetKey: "windowModuleWidth"
        description: I18n.tr("A longer title is cut short with an ellipsis.")
        enabled: Prefs.windowModuleText !== "icon"
        disabledReason: I18n.tr("It shows only the icon.")
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
        visible: card.moduleId === "apps"
        title: I18n.tr("Show running applications")
        resetKey: "dockShowRunning"
        description: I18n.tr("Apps open but not pinned follow the pinned ones. The same setting as the dock's.")
        showDivider: false

        M3Switch {
            checked: Prefs.dockShowRunning
            onToggled: (v) => {
                return Prefs.dockShowRunning = v;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "apps"
        title: I18n.tr("Running indicator")
        resetKey: "dockShowIndicators"
        description: I18n.tr("A dot under an open app, stretched into a bar for the one in focus. The same setting as the dock's.")
        showDivider: false

        M3Switch {
            checked: Prefs.dockShowIndicators
            onToggled: (v) => {
                return Prefs.dockShowIndicators = v;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "apps"
        title: I18n.tr("Tooltips")
        resetKey: "dockShowTooltips"
        description: I18n.tr("The app's name, and how many windows it has, over its icon. The same setting as the dock's.")
        showDivider: false

        M3Switch {
            checked: Prefs.dockShowTooltips
            onToggled: (v) => {
                return Prefs.dockShowTooltips = v;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "apps"
        title: I18n.tr("Icon tiles")
        resetKey: "dockIconTiles"
        description: I18n.tr("Each icon on a tile of its own. The same setting as the dock's.")
        showDivider: false

        M3Switch {
            checked: Prefs.dockIconTiles
            onToggled: (v) => {
                return Prefs.dockIconTiles = v;
            }
        }

    }

    SettingRow {
        visible: card.moduleId === "window"
        title: I18n.tr("Scroll to switch windows")
        resetKey: "windowModuleScroll"
        description: I18n.tr("The wheel over the pill moves the focus through the windows on the workspace.")
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
        title: I18n.tr("Middle click closes it")
        resetKey: "windowModuleMiddleClose"
        description: I18n.tr("Like closing a browser tab: the window in focus closes on a middle click on the pill.")
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
        title: I18n.tr("More settings")
        description: card.mod && card.mod.more ? card.mod.more : ""
        showDivider: false

        M3Button {
            visible: !!card.mod && !!card.mod.page
            text: card.mod && card.pageNames[card.mod.page] ? I18n.tr("Open %1", card.pageNames[card.mod.page]) : I18n.tr("Open")
            variant: "tonal"
            onClicked: Prefs.settingsRequested(card.mod.page)
        }

    }

    SettingRow {
        visible: card.options.length > 0
        title: I18n.tr("Reset this module")
        description: I18n.tr("Its options above go back to how they ship. Whether it shows and where it sits stay as they are.")
        showDivider: false

        M3Button {
            text: I18n.tr("Reset")
            variant: "text"
            destructive: true
            enabled: card.options.some((k) => {
                return Prefs.isModified(k);
            })
            onClicked: Prefs.resetKeys(card.options)
        }

    }

}
