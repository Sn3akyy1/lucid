import QtQuick
import Quickshell
import qs
import qs.lucidicons

Column {
    id: page

    readonly property string home: Quickshell.env("HOME")
    spacing: Theme.dp(26)

    SettingCard {
        title: I18n.tr("SIZE")

        SettingRow {
            title: I18n.tr("Interface size")
            resetKey: "uiScale"
            description: I18n.tr("Scales the whole shell at once: bar, dock, panels, menus and the text in them. Applications and the screen's own scale are not affected.")
            showDivider: false
            stacked: true

            M3Slider {
                id: sizeSlider

                width: parent.width
                from: 0.75
                to: 1.25
                stepSize: 0.05
                stepLabels: ["75%", "80%", "85%", "90%", "95%", "100%", "105%", "110%", "115%", "120%", "125%"]
                value: Prefs.uiScale
                // applied on release: resizing live would pull this window out from under the pointer
                onDraggingChanged: {
                    var v = Math.round(sizeSlider.dragValue * 100) / 100;
                    if (!sizeSlider.dragging && v !== Prefs.uiScale)
                        Prefs.uiScale = v;

                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("SHAPE")

        SettingRow {
            title: I18n.tr("Corner rounding")
            resetKey: "cornerScale"
            description: I18n.tr("How round the whole shell is: cards, panels, menus, pills and buttons. Lower squares them off, higher rounds them further; avatars, dots and the like stay round.")
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 1.5
                stepSize: 0.25
                stepLabels: [I18n.tr("Square"), "25%", "50%", "75%", I18n.tr("As shipped"), "125%", "150%"]
                value: Prefs.cornerScale
                onMoved: (v) => {
                    return Prefs.cornerScale = Math.round(v * 100) / 100;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("SURFACES")

        SettingRow {
            title: I18n.tr("Glass")
            description: I18n.tr("How far the desktop shows through the shell, the terminal and your windows now has a page of its own.")

            M3Button {
                text: I18n.tr("Glass…")
                variant: "tonal"
                onClicked: Prefs.settingsRequested("glass")
            }

        }

        SettingRow {
            title: I18n.tr("Accent intensity")
            resetKey: "accentPunch"
            description: I18n.tr("Lifts the accent colour away from the wallpaper-derived original. 1.0 uses it exactly as generated.")
            stacked: true

            M3Slider {
                width: parent.width
                from: 1
                to: 2
                stepSize: 0.05
                decimals: 2
                value: Prefs.accentPunch
                onMoved: (v) => {
                    return Prefs.accentPunch = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Surface darkness")
            resetKey: "surfaceDarkness"
            description: I18n.tr("How far every panel is darkened beneath the theme's own surface colour. Auto follows the theme.")
            stacked: true

            Row {
                spacing: Theme.dp(16)
                width: parent.width

                M3Slider {
                    width: parent.width - resetDark.width - Theme.dp(16)
                    enabled: Prefs.surfaceDarkness >= 0
                    from: 0
                    to: 0.8
                    stepSize: 0.05
                    decimals: 2
                    value: Prefs.surfaceDarkness >= 0 ? Prefs.surfaceDarkness : Theme.pillDarkness
                    onMoved: (v) => {
                        return Prefs.surfaceDarkness = v;
                    }
                }

                M3Button {
                    id: resetDark

                    anchors.verticalCenter: parent.verticalCenter
                    text: Prefs.surfaceDarkness >= 0 ? I18n.tr("Auto") : I18n.tr("Manual")
                    variant: Prefs.surfaceDarkness >= 0 ? "tonal" : "filled"
                    onClicked: Prefs.surfaceDarkness = Prefs.surfaceDarkness >= 0 ? -1 : 0.3
                }

            }

        }

        SettingRow {
            title: I18n.tr("Accent tint")
            resetKey: "surfaceTint"
            description: I18n.tr("How much of the accent colour is mixed into every panel. A light palette comes out of the generator almost white, so Auto tints it and leaves dark panels flat.")
            showDivider: false
            stacked: true

            Row {
                spacing: Theme.dp(16)
                width: parent.width

                M3Slider {
                    width: parent.width - resetTint.width - Theme.dp(16)
                    enabled: Prefs.surfaceTint >= 0
                    from: 0
                    to: 1
                    stepSize: 0.05
                    decimals: 2
                    value: Prefs.surfaceTint >= 0 ? Prefs.surfaceTint : (Theme.isLight ? 0.7 : 0)
                    onMoved: (v) => {
                        return Prefs.surfaceTint = v;
                    }
                }

                M3Button {
                    id: resetTint

                    anchors.verticalCenter: parent.verticalCenter
                    text: Prefs.surfaceTint >= 0 ? I18n.tr("Auto") : I18n.tr("Manual")
                    variant: Prefs.surfaceTint >= 0 ? "tonal" : "filled"
                    onClicked: Prefs.surfaceTint = Prefs.surfaceTint >= 0 ? -1 : (Theme.isLight ? 0.7 : 0.2)
                }

            }

        }

    }

    SettingCard {
        title: I18n.tr("MOTION")

        SettingRow {
            title: I18n.tr("Animation speed")
            resetKey: "motionScale"
            description: I18n.tr("How fast the shell moves: panels, menus, the dock and the launcher. Further right is faster; all the way right, nothing animates. Windows and workspaces move with Hyprland, on the Windows page.")
            stacked: true

            SpeedSlider {
                width: parent.width
                lengths: [2, 1.333, 1, 0.8, 0.667, 0.5, 0.333, 0.25, 0]
                stepLabels: ["0.5x", "0.75x", I18n.tr("As shipped"), "1.25x", "1.5x", "2x", "3x", "4x", I18n.tr("Instant")]
                length: Prefs.motionScale
                onPicked: (l) => {
                    return Prefs.motionScale = l;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Jelly motion")
            resetKey: "jellyMotion"
            enabled: Prefs.motionScale > 0
            disabledReason: I18n.tr("Animation speed is set to Instant, so nothing moves.")
            description: I18n.tr("Panels, menus, the dock and the launcher wobble softly as they open and land, and dock icons, buttons and switches squish under the pointer.")

            M3Switch {
                checked: Prefs.jellyMotion
                enabled: Prefs.motionScale > 0
                onToggled: (v) => {
                    return Prefs.jellyMotion = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Wobble")
            resetKey: "jellyAmount"
            enabled: Prefs.jellyMotion && Prefs.motionScale > 0
            disabledReason: Prefs.motionScale > 0 ? I18n.tr("Turn on Jelly motion first.") : I18n.tr("Animation speed is set to Instant, so nothing moves.")
            description: I18n.tr("How far things bend, and how long they keep wobbling.")
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                enabled: Prefs.jellyMotion && Prefs.motionScale > 0
                from: 0.5
                to: 2
                stepSize: 0.25
                stepLabels: [I18n.tr("Subtle"), "75%", I18n.tr("As shipped"), "125%", "150%", "175%", I18n.tr("Bouncy")]
                value: Prefs.jellyAmount
                onMoved: (v) => {
                    return Prefs.jellyAmount = Math.round(v * 100) / 100;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("DESKTOP")

        SettingRow {
            title: I18n.tr("Selection box")
            resetKey: "desktopSelection"
            description: Prefs.desktopIcons ? I18n.tr("Drag across empty desktop to draw a box, the way it does on Windows and macOS. It selects the icons and the widgets it touches; hold Ctrl or Shift to add icons to what is already selected. Selected widgets move together when you drag any one of them; pinned widgets are left out. Click the desktop to let go.") : I18n.tr("Drag across empty desktop to draw a box, the way it does on Windows and macOS. Widgets it touches are selected and move together when you drag any one of them; pinned widgets are left out. Click the desktop to let go.")

            M3Switch {
                checked: Prefs.desktopSelection
                onToggled: (v) => {
                    return Prefs.desktopSelection = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Right-click menu")
            resetKey: "desktopMenu"
            description: I18n.tr("Right-click empty desktop for wallpaper and theme, the widgets you have placed, a screenshot and settings.")
            showDivider: false

            M3Switch {
                checked: Prefs.desktopMenu
                onToggled: (v) => {
                    return Prefs.desktopMenu = v;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("DESKTOP ICONS")

        SettingRow {
            title: I18n.tr("Show icons")
            resetKey: "desktopIcons"
            description: I18n.tr("What is in your Desktop folder sits on the wallpaper of the main display, with the drives you plug in. Widgets keep their space: an icon one covers steps to the nearest free cell and goes back when the widget moves. Select with a click or a box, drag into folders, the Trash or any app, and right-click for New Item, Open With, Get Info, tags, compress and more. Ctrl+Z undoes the last change.")

            M3Switch {
                checked: Prefs.desktopIcons
                onToggled: (v) => {
                    return Prefs.desktopIcons = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Icon theme")
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")
            description: Prefs.envLegacyIcons ? I18n.tr("Folders, files and apps are drawn by your icon theme, ") + (Prefs.envIconTheme !== "" ? Prefs.envIconTheme.replace(/_/g, " ") : I18n.tr("the system's")) + I18n.tr(", the same set your apps use. Change it on the Environment page.") : I18n.tr("Folders, files and apps are drawn with Lucid's %1 icons, in your wallpaper's colours. Pick another set on the Environment page, or turn on legacy icons there to use your GTK theme.", LucidIcons.nameOf(Prefs.envIconSet))

            M3Button {
                text: I18n.tr("Environment")
                variant: "tonal"
                enabled: Prefs.desktopIcons
                onClicked: Prefs.settingsRequested("environment")
            }

        }

        SettingRow {
            title: I18n.tr("Size")
            resetKey: "desktopIconSize"
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")

            M3Segmented {
                width: Math.max(Theme.dp(240), fitWidth)
                current: Prefs.desktopIconSize
                options: [{
                    "key": "small",
                    "label": I18n.tr("Small")
                }, {
                    "key": "medium",
                    "label": I18n.tr("Medium")
                }, {
                    "key": "large",
                    "label": I18n.tr("Large")
                }]
                onChosen: (key) => {
                    return Prefs.desktopIconSize = key;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Spacing")
            resetKey: "desktopIconSpacing"
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")
            description: I18n.tr("How far apart the icons sit. Names wrap to two lines either way.")

            M3Segmented {
                width: Math.max(Theme.dp(260), fitWidth)
                current: Prefs.desktopIconSpacing
                options: [{
                    "key": "compact",
                    "label": I18n.tr("Compact")
                }, {
                    "key": "normal",
                    "label": I18n.tr("Normal")
                }, {
                    "key": "roomy",
                    "label": I18n.tr("Roomy")
                }]
                onChosen: (key) => {
                    return Prefs.desktopIconSpacing = key;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Arrange by")
            resetKey: "desktopIconsSort"
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")
            description: I18n.tr("The order new icons take, and the one Arrange By on the desktop's menu puts everything back in. Folders come first.")

            M3Segmented {
                width: Math.max(Theme.dp(300), fitWidth)
                current: Prefs.desktopIconsSort
                options: [{
                    "key": "name",
                    "label": I18n.tr("Name")
                }, {
                    "key": "type",
                    "label": I18n.tr("Type")
                }, {
                    "key": "size",
                    "label": I18n.tr("Size")
                }, {
                    "key": "date",
                    "label": I18n.tr("Modified")
                }]
                onChosen: (key) => {
                    DesktopIcons.arrangeBy(key);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Start from")
            resetKey: "desktopIconsCorner"
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")
            description: I18n.tr("New icons fill the columns from this side of the screen, top to bottom.")

            M3Segmented {
                width: Math.max(Theme.dp(180), fitWidth)
                current: Prefs.desktopIconsCorner
                options: [{
                    "key": "left",
                    "label": I18n.tr("Left")
                }, {
                    "key": "right",
                    "label": I18n.tr("Right")
                }]
                onChosen: (key) => {
                    return Prefs.desktopIconsCorner = key;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Order")
            resetKey: "desktopIconsSortDesc"
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")
            description: I18n.tr("Folders stay first either way.")

            M3Segmented {
                width: Math.max(Theme.dp(240), fitWidth)
                current: Prefs.desktopIconsSortDesc ? "desc" : "asc"
                options: [{
                    "key": "asc",
                    "label": I18n.tr("Ascending")
                }, {
                    "key": "desc",
                    "label": I18n.tr("Descending")
                }]
                onChosen: (key) => {
                    Prefs.desktopIconsSortDesc = key === "desc";
                    Qt.callLater(DesktopIcons.arrange);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Auto arrange")
            resetKey: "desktopIconsAutoArrange"
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")
            description: I18n.tr("Keep every icon in order from the starting corner, the way Windows does. Off, each icon stays where you drop it.")

            M3Switch {
                checked: Prefs.desktopIconsAutoArrange
                onToggled: (v) => {
                    return Prefs.desktopIconsAutoArrange = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Spring-loaded folders")
            resetKey: "desktopIconsSpring"
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")
            description: I18n.tr("Hold a drag over a folder for a moment and it opens in your file manager, so you can drop deeper inside, as on a Mac.")

            M3Switch {
                checked: Prefs.desktopIconsSpring
                onToggled: (v) => {
                    return Prefs.desktopIconsSpring = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Open with")
            resetKey: "desktopIconsOpen"
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")

            M3Segmented {
                width: Math.max(Theme.dp(240), fitWidth)
                current: Prefs.desktopIconsOpen
                options: [{
                    "key": "double",
                    "label": I18n.tr("Double click")
                }, {
                    "key": "single",
                    "label": I18n.tr("Single click")
                }]
                onChosen: (key) => {
                    return Prefs.desktopIconsOpen = key;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Previews")
            resetKey: "desktopIconsThumbs"
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")
            description: I18n.tr("Pictures, videos, music with cover art and documents show what is in them, the way a file manager does, and share its thumbnails.")

            M3Switch {
                checked: Prefs.desktopIconsThumbs
                onToggled: (v) => {
                    return Prefs.desktopIconsThumbs = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("File extensions")
            resetKey: "desktopIconsHideExt"
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")
            description: Prefs.desktopIconsHideExt ? I18n.tr("Names leave off a short extension like .txt or .png; the whole name shows under the pointer and when selected.") : I18n.tr("Every name shows in full, extension and all.")

            M3Segmented {
                width: Math.max(Theme.dp(180), fitWidth)
                current: Prefs.desktopIconsHideExt ? "hide" : "show"
                options: [{
                    "key": "show",
                    "label": I18n.tr("Show")
                }, {
                    "key": "hide",
                    "label": I18n.tr("Hide")
                }]
                onChosen: (key) => {
                    return Prefs.desktopIconsHideExt = key === "hide";
                }
            }

        }

        SettingRow {
            title: I18n.tr("Hidden files")
            resetKey: "desktopIconsHidden"
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")
            description: I18n.tr("Files whose name starts with a dot, shown faded. Ctrl+H on the desktop flips this.")

            M3Switch {
                checked: Prefs.desktopIconsHidden
                onToggled: (v) => {
                    return Prefs.desktopIconsHidden = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Home folder")
            resetKey: "desktopIconsHome"
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")

            M3Switch {
                checked: Prefs.desktopIconsHome
                onToggled: (v) => {
                    return Prefs.desktopIconsHome = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Trash")
            resetKey: "desktopIconsTrash"
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")
            description: I18n.tr("Drop files on it to throw them away; right-click it to empty it.")

            M3Switch {
                checked: Prefs.desktopIconsTrash
                onToggled: (v) => {
                    return Prefs.desktopIconsTrash = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Drives")
            resetKey: "desktopIconsDrives"
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")
            description: I18n.tr("USB sticks, phones and other drives while they are mounted. Right-click one to eject it.")

            M3Switch {
                checked: Prefs.desktopIconsDrives
                onToggled: (v) => {
                    return Prefs.desktopIconsDrives = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Add an app")
            enabled: Prefs.desktopIcons
            disabledReason: I18n.tr("Turn on Show icons first.")
            description: I18n.tr("Puts a launcher for it on the desktop. Launchers that arrive any other way ask before they run the first time.")
            showDivider: false

            M3Button {
                text: I18n.tr("Choose\u2026")
                variant: "tonal"
                enabled: Prefs.desktopIcons
                onClicked: Prefs.appPickerRequested("::desktop")
            }

        }

    }

    SettingCard {
        title: I18n.tr("ON-SCREEN DISPLAY")

        SettingRow {
            title: I18n.tr("OSD style")
            resetKey: "osdStyle"
            description: I18n.tr("Where volume, brightness and lock-key changes show up. An island floats above the bottom edge; a notch rises out of it, its corners sweeping out like the dock's.")

            M3Segmented {
                width: Theme.dp(260)
                current: Prefs.osdStyle
                options: [{
                    "key": "island",
                    "label": I18n.tr("Island")
                }, {
                    "key": "notch",
                    "label": I18n.tr("Notch")
                }]
                onChosen: (key) => {
                    return Prefs.osdStyle = key;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Morph the dock")
            resetKey: "osdDockMorph"
            description: Prefs.osdDockMorph ? I18n.tr("With the dock a notch as well, the dock itself turns into the OSD and back. A dock tucked away rises out of the edge as the OSD.") : I18n.tr("The OSD rises as a notch of its own, and the dock steps down while it shows.")
            enabled: Prefs.osdNotch && Prefs.dockNotch
            disabledReason: I18n.tr("Only when the OSD and the dock are both notches - set OSD style to Notch above, and Dock style to Notch on the Dock page.")

            M3Switch {
                enabled: Prefs.osdNotch && Prefs.dockNotch
                checked: Prefs.osdDockMorph
                onToggled: (v) => {
                    Prefs.osdDockMorph = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Caps Lock")
            resetKey: "osdCapsLock"
            description: Prefs.osdCapsLock ? I18n.tr("A card shows ABC or abc as Caps Lock goes on or off.") : I18n.tr("Caps Lock changes without a card. Its sound has a switch of its own in Sound.")

            M3Switch {
                checked: Prefs.osdCapsLock
                onToggled: (v) => {
                    Prefs.osdCapsLock = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Num Lock")
            resetKey: "osdNumLock"
            description: Prefs.osdNumLock ? I18n.tr("A card shows 123 or arrows as Num Lock goes on or off.") : I18n.tr("Num Lock changes without a card.")
            showDivider: false

            M3Switch {
                checked: Prefs.osdNumLock
                onToggled: (v) => {
                    Prefs.osdNumLock = v;
                }
            }

        }

    }

}
