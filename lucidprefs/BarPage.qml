import QtQuick
import qs
import qs.lucidui

Column {
    id: page

    readonly property var zoneTitles: ({
        "left": "LEFT",
        "centre": "MIDDLE",
        "right": "RIGHT"
    })
    readonly property var zoneBlurbs: ({
        "left": "Runs outward from the left edge.",
        "centre": "Centred on the screen, and pushed aside when the sides run long.",
        "right": "Runs inward from the right edge."
    })

    // a drag never touches the arrangement until it is dropped: the list keeps
    // its order and shows where the row will land instead, so the row being
    // dragged is never destroyed out from under the pointer
    property string dragKey: ""
    property string dragFrom: ""
    property string dropZone: ""
    property int dropIndex: -1

    function beginDrag(key, from) {
        page.dragKey = key;
        page.dragFrom = from;
        page.dropZone = "";
        page.dropIndex = -1;
    }

    function aimDrop(zone, index) {
        if (page.dragKey === "")
            return ;

        page.dropZone = zone;
        page.dropIndex = index;
    }

    function endDrag() {
        const key = page.dragKey;
        const zone = page.dropZone;
        const at = page.dropIndex;
        page.dragKey = "";
        page.dragFrom = "";
        page.dropZone = "";
        page.dropIndex = -1;
        if (key === "" || zone === "")
            return ;

        // the write rebuilds the repeaters and destroys the row that is calling
        // this, so it cannot happen inside that row's own release handler
        page.pendingDrop = ({ "key": key, "zone": zone, "at": at });
        Qt.callLater(page.applyDrop);
    }

    property var pendingDrop: null

    function applyDrop() {
        const d = page.pendingDrop;
        page.pendingDrop = null;
        if (!d)
            return ;

        if (d.zone === "spare") {
            Prefs.barRemove(d.key);
            return ;
        }
        // barMove takes the key out of its zone first, so a target below where
        // it already sits in that same zone shifts up by one
        const cur = Prefs.barKeysOf(d.zone).indexOf(d.key);
        const target = (cur >= 0 && cur < d.at) ? d.at - 1 : d.at;
        if (cur === target)
            return ;

        Prefs.barMove(d.key, d.zone, target);
    }

    spacing: 26

    BarPreview {
        width: parent.width
    }

    SettingCard {
        title: "OPENING BEHAVIOUR"

        SettingRow {
            title: "Pop-up mode"
            description: "Modules stop morphing their own pill into a panel. The pill stays put in the bar and the panel appears below it as a detached pop-up."

            M3Switch {
                checked: Prefs.barPopupMode
                onToggled: (v) => {
                    return Prefs.barPopupMode = v;
                }
            }

        }

        SettingRow {
            title: "Pop-up distance"
            resetKey: "barPopupGap"
            description: "The gap between a module's pill and the panel it opens."
            enabled: Prefs.barPopupMode
            disabledReason: "Only applies in pop-up mode."
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                enabled: Prefs.barPopupMode
                from: 0
                to: 24
                stepSize: 1
                suffix: " px"
                value: Prefs.barPopupGap
                onMoved: (v) => {
                    return Prefs.barPopupGap = v;
                }
            }

        }

    }

    SettingCard {
        title: "LAYOUT"

        SettingRow {
            title: "Bar height"
            resetKey: "barHeight"
            description: "How tall each module's resting pill is."
            stacked: true

            M3Slider {
                width: parent.width
                from: 26
                to: 52
                stepSize: 1
                suffix: " px"
                value: Prefs.barHeight
                onMoved: (v) => {
                    return Prefs.barHeight = v;
                }
            }

        }

        SettingRow {
            title: "Distance from top"
            resetKey: "barTopMargin"
            description: "How far the bar floats below the top edge of the screen."
            enabled: !Prefs.barNotch
            disabledReason: "Notches sit flush against the screen edge by definition - switch back to islands on the General page to float the bar."
            stacked: true

            M3Slider {
                width: parent.width
                enabled: !Prefs.barNotch
                from: 0
                to: 48
                stepSize: 1
                suffix: " px"
                value: Prefs.barTopMargin
                onMoved: (v) => {
                    return Prefs.barTopMargin = v;
                }
            }

        }

        SettingRow {
            title: "Side margin"
            resetKey: "barSideMargin"
            description: "Inset from the left and right screen edges."
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 60
                stepSize: 1
                suffix: " px"
                value: Prefs.barSideMargin
                onMoved: (v) => {
                    return Prefs.barSideMargin = v;
                }
            }

        }

        SettingRow {
            title: "Edge blend"
            resetKey: "barNotchFlare"
            description: "How far a notched module's upper corners sweep out into the top of the screen. Only drawn where there is room for it - modules packed close together keep their square corners rather than leaving a spike of wallpaper between them."
            enabled: Prefs.barNotch
            disabledReason: "Islands float clear of the screen edge, so there is nothing to blend into - switch the bar to Notches on the General page."
            stacked: true

            M3Slider {
                width: parent.width
                enabled: Prefs.barNotch
                from: 0
                to: 32
                stepSize: 1
                suffix: " px"
                value: Prefs.barNotchFlare
                onMoved: (v) => {
                    return Prefs.barNotchFlare = v;
                }
            }

        }

        SettingRow {
            title: "Animation speed"
            resetKey: "barMotionScale"
            description: "Scales every transition in the bar - hovers, pills growing and shrinking, modules appearing and leaving - on top of the shell-wide Animation speed on the General page. Above 1.00x the bar moves more slowly than the rest of the shell."
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 2.5
                stepSize: 0.05
                decimals: 2
                suffix: "x"
                value: Prefs.barMotionScale
                onMoved: (v) => {
                    return Prefs.barMotionScale = v;
                }
            }

        }

        SettingRow {
            title: "Module spacing"
            resetKey: "barSpacing"
            description: "The gap between neighbouring pills."
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 24
                stepSize: 1
                suffix: " px"
                value: Prefs.barSpacing
                onMoved: (v) => {
                    return Prefs.barSpacing = v;
                }
            }

        }

        SettingRow {
            title: "Hover growth"
            resetKey: "barHoverGrow"
            description: "How far a pill swells under the pointer to show it opens. Capped at half the module spacing."
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 6
                stepSize: 1
                suffix: " px"
                value: Prefs.barHoverGrow
                onMoved: (v) => {
                    return Prefs.barHoverGrow = v;
                }
            }

        }

    }

    SettingCard {
        title: "MODULE LAYOUT"
        subtitle: "Each zone lays its modules out in the order below, left to right."

        SettingRow {
            title: "Middle clearance"
            resetKey: "barZoneGap"
            description: "How close the middle may come to either side before it gives way and slides along."
            stacked: true

            M3Slider {
                width: parent.width
                from: 8
                to: 80
                stepSize: 2
                suffix: " px"
                value: Prefs.barZoneGap
                onMoved: (v) => {
                    return Prefs.barZoneGap = v;
                }
            }

        }

        SettingRow {
            title: "Restore the shipped arrangement"
            description: "Puts every module back where Lucid ships it: workspaces, media and the tray on the left, the clock in the middle, notifications and system on the right."

            M3Button {
                text: "Restore"
                variant: "tonal"
                onClicked: Prefs.setBarDefaults()
            }

        }

    }

    Repeater {
        model: Prefs.barZones

        // the card is wrapped so an empty zone still has something to aim at,
        // and so the zone a row came from can be lifted above its neighbours
        // while that row is dragged across them
        Item {
            id: zoneHolder

            required property var modelData

            readonly property var keys: Prefs.barKeysOf(zoneHolder.modelData)

            width: parent.width
            implicitHeight: zoneCard.implicitHeight
            height: implicitHeight
            z: page.dragFrom === zoneHolder.modelData ? 5 : 0

            SettingCard {
                id: zoneCard

                width: parent.width
                title: page.zoneTitles[zoneHolder.modelData]
                subtitle: page.zoneBlurbs[zoneHolder.modelData]

                Repeater {
                    model: zoneHolder.keys

                    BarModuleRow {
                        required property var modelData
                        required property int index

                        host: page
                        zone: zoneHolder.modelData
                        slot: index
                        moduleKey: modelData
                        placed: true
                        first: index === 0
                        last: index === zoneHolder.keys.length - 1
                    }

                }

                // an empty zone still has to say so, or the card reads as broken
                Rectangle {
                    visible: zoneHolder.keys.length === 0
                    width: parent.width
                    height: 54
                    radius: 22
                    color: page.dropZone === zoneHolder.modelData ? Theme.alpha(Theme.accent, 0.2) : Theme.bgTile

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durFastEffects
                        }

                    }

                    LText {
                        anchors.centerIn: parent
                        role: "bodyMedium"
                        color: Theme.subtextDim
                        text: page.dropZone === zoneHolder.modelData ? "Drop it here" : "Nothing here yet"
                    }

                }

            }

            DropArea {
                anchors.fill: parent
                keys: ["lucid-bar-module"]
                // the rows aim for themselves; this only catches an empty zone
                enabled: zoneHolder.keys.length === 0

                onEntered: page.aimDrop(zoneHolder.modelData, 0)
                onPositionChanged: page.aimDrop(zoneHolder.modelData, 0)
            }

        }

    }

    Item {
        id: spareHolder

        readonly property bool targeted: page.dropZone === "spare"

        width: parent.width
        implicitHeight: spareCard.implicitHeight
        height: implicitHeight
        visible: Prefs.barUnusedKeys.length > 0 || page.dragKey !== ""
        z: page.dragFrom === "spare" ? 5 : 0

        SettingCard {
            id: spareCard

            width: parent.width
            title: "NOT IN THE BAR"
            subtitle: "Drag a module down here to take it out, or back up into a zone to put it in. The arrows and the buttons do the same thing."

            Repeater {
                model: Prefs.barUnusedKeys

                BarModuleRow {
                    required property var modelData
                    required property int index

                    host: page
                    zone: "spare"
                    slot: index
                    moduleKey: modelData
                    placed: false
                    first: index === 0
                    last: index === Prefs.barUnusedKeys.length - 1
                }

            }

            // somewhere to aim when every module is already in the bar
            Rectangle {
                visible: Prefs.barUnusedKeys.length === 0
                width: parent.width
                height: 54
                radius: 22
                color: spareHolder.targeted ? Theme.alpha(Theme.error, 0.2) : Theme.bgTile

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durFastEffects
                    }

                }

                LText {
                    anchors.centerIn: parent
                    role: "bodyMedium"
                    color: Theme.subtextDim
                    text: spareHolder.targeted ? "Drop it here to take it out of the bar" : "Every module is in the bar"
                }

            }

        }

        DropArea {
            anchors.fill: parent
            keys: ["lucid-bar-module"]

            onEntered: page.aimDrop("spare", 0)
            onPositionChanged: page.aimDrop("spare", 0)
        }

    }

    SettingCard {
        title: "NOTIFICATIONS"

        SettingRow {
            title: "Do not disturb"
            resetKey: "doNotDisturb"
            description: "Notifications are still collected in the list, but no popup is shown."

            M3Switch {
                checked: Prefs.doNotDisturb
                onToggled: (v) => {
                    return Prefs.doNotDisturb = v;
                }
            }

        }

        SettingRow {
            title: "Everything else"
            description: "How long a popup stays, quiet hours, sound and which applications may interrupt you all live on their own page."
            showDivider: false

            M3Button {
                text: "Notifications…"
                variant: "tonal"
                onClicked: Prefs.settingsRequested("notifications")
            }

        }

    }

    SettingCard {
        title: "SYSTEM MODULE"

        SettingRow {
            title: "Keyboard layout"
            resetKey: "showKbLayout"
            description: "Shows the active keyboard layout next to the network icon. Click it to switch to the next layout."

            M3Switch {
                checked: Prefs.showKbLayout
                onToggled: (v) => {
                    return Prefs.showKbLayout = v;
                }
            }

        }

        SettingRow {
            title: "Game mode: turn on"
            resetKey: "gameModeOnCmd"
            description: "Shell command the Game mode tile runs to switch it on (add the tile under Edit tiles in the control centre). Runs through bash, so pipes and && work."
            stacked: true

            M3TextField {
                width: parent.width
                placeholder: "e.g. sudo -n g15-gamemode on"
                text: Prefs.gameModeOnCmd
                onAccepted: (v) => {
                    return Prefs.gameModeOnCmd = v;
                }
            }

        }

        SettingRow {
            title: "Game mode: turn off"
            resetKey: "gameModeOffCmd"
            description: "Shell command run to switch game mode off again."
            stacked: true

            M3TextField {
                width: parent.width
                placeholder: "e.g. sudo -n g15-gamemode off"
                text: Prefs.gameModeOffCmd
                onAccepted: (v) => {
                    return Prefs.gameModeOffCmd = v;
                }
            }

        }

        SettingRow {
            title: "Game mode: status check"
            resetKey: "gameModeStatusCmd"
            description: "Optional. Exits 0 while game mode is on, so the toggle stays right when something else (a keybind, a script) changes it. Checked whenever the panel opens."
            showDivider: false
            stacked: true

            M3TextField {
                width: parent.width
                placeholder: "e.g. test -f /run/g15-gamemode.state"
                text: Prefs.gameModeStatusCmd
                onAccepted: (v) => {
                    return Prefs.gameModeStatusCmd = v;
                }
            }

        }

    }

}
