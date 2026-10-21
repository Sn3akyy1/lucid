import QtQuick
import Quickshell
import qs

Column {
    id: page

    readonly property string home: Quickshell.env("HOME")
    spacing: Theme.dp(26)

    SettingCard {
        title: "SIZE"

        SettingRow {
            title: "Interface size"
            resetKey: "uiScale"
            description: "Scales the whole shell at once: bar, dock, panels, menus and the text in them. Applications and the screen's own scale are not affected."
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
        title: "SHAPE"

        SettingRow {
            title: "Corner rounding"
            resetKey: "cornerScale"
            description: "How round the whole shell is: cards, panels, menus, pills and buttons. Lower squares them off, higher rounds them further; avatars, dots and the like stay round."
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 1.5
                stepSize: 0.25
                stepLabels: ["Square", "25%", "50%", "75%", "As shipped", "125%", "150%"]
                value: Prefs.cornerScale
                onMoved: (v) => {
                    return Prefs.cornerScale = Math.round(v * 100) / 100;
                }
            }

        }

    }

    SettingCard {
        title: "SURFACES"

        SettingRow {
            title: "Glass"
            description: "How far the desktop shows through the shell, the terminal and your windows now has a page of its own."

            M3Button {
                text: "Glass…"
                variant: "tonal"
                onClicked: Prefs.settingsRequested("glass")
            }

        }

        SettingRow {
            title: "Accent intensity"
            resetKey: "accentPunch"
            description: "Lifts the accent colour away from the wallpaper-derived original. 1.0 uses it exactly as generated."
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
            title: "Surface darkness"
            resetKey: "surfaceDarkness"
            description: "How far every panel is darkened beneath the theme's own surface colour. Auto follows the theme."
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
                    text: Prefs.surfaceDarkness >= 0 ? "Auto" : "Manual"
                    variant: Prefs.surfaceDarkness >= 0 ? "tonal" : "filled"
                    onClicked: Prefs.surfaceDarkness = Prefs.surfaceDarkness >= 0 ? -1 : 0.3
                }

            }

        }

        SettingRow {
            title: "Accent tint"
            resetKey: "surfaceTint"
            description: "How much of the accent colour is mixed into every panel. A light palette comes out of the generator almost white, so Auto tints it and leaves dark panels flat."
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
                    text: Prefs.surfaceTint >= 0 ? "Auto" : "Manual"
                    variant: Prefs.surfaceTint >= 0 ? "tonal" : "filled"
                    onClicked: Prefs.surfaceTint = Prefs.surfaceTint >= 0 ? -1 : (Theme.isLight ? 0.7 : 0.2)
                }

            }

        }

    }

    SettingCard {
        title: "MOTION"

        SettingRow {
            title: "Animation speed"
            resetKey: "motionScale"
            description: "Scales every transition in the shell. 1.00x is the shipped speed; drag to 0 for no animation at all."
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 2
                stepSize: 0.25
                decimals: 2
                suffix: "x"
                value: Prefs.motionScale
                onMoved: (v) => {
                    return Prefs.motionScale = v;
                }
            }

        }

    }

    SettingCard {
        title: "DESKTOP"

        SettingRow {
            title: "Selection box"
            resetKey: "desktopSelection"
            description: Prefs.desktopIcons ? "Drag across empty desktop to draw a box, the way it does on Windows and macOS. It selects the icons and the widgets it touches; hold Ctrl or Shift to add icons to what is already selected. Selected widgets move together when you drag any one of them; pinned widgets are left out. Click the desktop to let go." : "Drag across empty desktop to draw a box, the way it does on Windows and macOS. Widgets it touches are selected and move together when you drag any one of them; pinned widgets are left out. Click the desktop to let go."

            M3Switch {
                checked: Prefs.desktopSelection
                onToggled: (v) => {
                    return Prefs.desktopSelection = v;
                }
            }

        }

        SettingRow {
            title: "Right-click menu"
            resetKey: "desktopMenu"
            description: "Right-click empty desktop for wallpaper and theme, the widgets you have placed, a screenshot and settings."
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
        title: "DESKTOP ICONS"

        SettingRow {
            title: "Show icons"
            resetKey: "desktopIcons"
            description: "What is in your Desktop folder sits on the wallpaper of the main display, with the drives you plug in. Widgets keep their space: an icon one covers steps to the nearest free cell and goes back when the widget moves. Select with a click or a box, drag into folders, the Trash or any app, and right-click for New Item, Open With, Get Info, tags, compress and more. Ctrl+Z undoes the last change."

            M3Switch {
                checked: Prefs.desktopIcons
                onToggled: (v) => {
                    return Prefs.desktopIcons = v;
                }
            }

        }

        SettingRow {
            title: "Icon theme"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."
            description: "Folders, files and apps are drawn by your icon theme, " + (Prefs.envIconTheme !== "" ? Prefs.envIconTheme.replace(/_/g, " ") : "the system's") + ", the same set your apps use. Change it on the Environment page."

            M3Button {
                text: "Environment"
                variant: "tonal"
                enabled: Prefs.desktopIcons
                onClicked: Prefs.settingsRequested("environment")
            }

        }

        SettingRow {
            title: "Size"
            resetKey: "desktopIconSize"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."

            M3Segmented {
                width: Math.max(Theme.dp(240), fitWidth)
                current: Prefs.desktopIconSize
                options: [{
                    "key": "small",
                    "label": "Small"
                }, {
                    "key": "medium",
                    "label": "Medium"
                }, {
                    "key": "large",
                    "label": "Large"
                }]
                onChosen: (key) => {
                    return Prefs.desktopIconSize = key;
                }
            }

        }

        SettingRow {
            title: "Spacing"
            resetKey: "desktopIconSpacing"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."
            description: "How far apart the icons sit. Names wrap to two lines either way."

            M3Segmented {
                width: Math.max(Theme.dp(260), fitWidth)
                current: Prefs.desktopIconSpacing
                options: [{
                    "key": "compact",
                    "label": "Compact"
                }, {
                    "key": "normal",
                    "label": "Normal"
                }, {
                    "key": "roomy",
                    "label": "Roomy"
                }]
                onChosen: (key) => {
                    return Prefs.desktopIconSpacing = key;
                }
            }

        }

        SettingRow {
            title: "Arrange by"
            resetKey: "desktopIconsSort"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."
            description: "The order new icons take, and the one Arrange By on the desktop's menu puts everything back in. Folders come first."

            M3Segmented {
                width: Math.max(Theme.dp(300), fitWidth)
                current: Prefs.desktopIconsSort
                options: [{
                    "key": "name",
                    "label": "Name"
                }, {
                    "key": "type",
                    "label": "Type"
                }, {
                    "key": "size",
                    "label": "Size"
                }, {
                    "key": "date",
                    "label": "Modified"
                }]
                onChosen: (key) => {
                    DesktopIcons.arrangeBy(key);
                }
            }

        }

        SettingRow {
            title: "Start from"
            resetKey: "desktopIconsCorner"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."
            description: "New icons fill the columns from this side of the screen, top to bottom."

            M3Segmented {
                width: Math.max(Theme.dp(180), fitWidth)
                current: Prefs.desktopIconsCorner
                options: [{
                    "key": "left",
                    "label": "Left"
                }, {
                    "key": "right",
                    "label": "Right"
                }]
                onChosen: (key) => {
                    return Prefs.desktopIconsCorner = key;
                }
            }

        }

        SettingRow {
            title: "Order"
            resetKey: "desktopIconsSortDesc"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."
            description: "Folders stay first either way."

            M3Segmented {
                width: Math.max(Theme.dp(240), fitWidth)
                current: Prefs.desktopIconsSortDesc ? "desc" : "asc"
                options: [{
                    "key": "asc",
                    "label": "Ascending"
                }, {
                    "key": "desc",
                    "label": "Descending"
                }]
                onChosen: (key) => {
                    Prefs.desktopIconsSortDesc = key === "desc";
                    Qt.callLater(DesktopIcons.arrange);
                }
            }

        }

        SettingRow {
            title: "Auto arrange"
            resetKey: "desktopIconsAutoArrange"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."
            description: "Keep every icon in order from the starting corner, the way Windows does. Off, each icon stays where you drop it."

            M3Switch {
                checked: Prefs.desktopIconsAutoArrange
                onToggled: (v) => {
                    return Prefs.desktopIconsAutoArrange = v;
                }
            }

        }

        SettingRow {
            title: "Spring-loaded folders"
            resetKey: "desktopIconsSpring"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."
            description: "Hold a drag over a folder for a moment and it opens in your file manager, so you can drop deeper inside, as on a Mac."

            M3Switch {
                checked: Prefs.desktopIconsSpring
                onToggled: (v) => {
                    return Prefs.desktopIconsSpring = v;
                }
            }

        }

        SettingRow {
            title: "Open with"
            resetKey: "desktopIconsOpen"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."

            M3Segmented {
                width: Math.max(Theme.dp(240), fitWidth)
                current: Prefs.desktopIconsOpen
                options: [{
                    "key": "double",
                    "label": "Double click"
                }, {
                    "key": "single",
                    "label": "Single click"
                }]
                onChosen: (key) => {
                    return Prefs.desktopIconsOpen = key;
                }
            }

        }

        SettingRow {
            title: "Previews"
            resetKey: "desktopIconsThumbs"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."
            description: "Pictures, videos, music with cover art and documents show what is in them, the way a file manager does, and share its thumbnails."

            M3Switch {
                checked: Prefs.desktopIconsThumbs
                onToggled: (v) => {
                    return Prefs.desktopIconsThumbs = v;
                }
            }

        }

        SettingRow {
            title: "File extensions"
            resetKey: "desktopIconsHideExt"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."
            description: Prefs.desktopIconsHideExt ? "Names leave off a short extension like .txt or .png; the whole name shows under the pointer and when selected." : "Every name shows in full, extension and all."

            M3Segmented {
                width: Math.max(Theme.dp(180), fitWidth)
                current: Prefs.desktopIconsHideExt ? "hide" : "show"
                options: [{
                    "key": "show",
                    "label": "Show"
                }, {
                    "key": "hide",
                    "label": "Hide"
                }]
                onChosen: (key) => {
                    return Prefs.desktopIconsHideExt = key === "hide";
                }
            }

        }

        SettingRow {
            title: "Hidden files"
            resetKey: "desktopIconsHidden"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."
            description: "Files whose name starts with a dot, shown faded. Ctrl+H on the desktop flips this."

            M3Switch {
                checked: Prefs.desktopIconsHidden
                onToggled: (v) => {
                    return Prefs.desktopIconsHidden = v;
                }
            }

        }

        SettingRow {
            title: "Home folder"
            resetKey: "desktopIconsHome"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."

            M3Switch {
                checked: Prefs.desktopIconsHome
                onToggled: (v) => {
                    return Prefs.desktopIconsHome = v;
                }
            }

        }

        SettingRow {
            title: "Trash"
            resetKey: "desktopIconsTrash"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."
            description: "Drop files on it to throw them away; right-click it to empty it."

            M3Switch {
                checked: Prefs.desktopIconsTrash
                onToggled: (v) => {
                    return Prefs.desktopIconsTrash = v;
                }
            }

        }

        SettingRow {
            title: "Drives"
            resetKey: "desktopIconsDrives"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."
            description: "USB sticks, phones and other drives while they are mounted. Right-click one to eject it."

            M3Switch {
                checked: Prefs.desktopIconsDrives
                onToggled: (v) => {
                    return Prefs.desktopIconsDrives = v;
                }
            }

        }

        SettingRow {
            title: "Add an app"
            enabled: Prefs.desktopIcons
            disabledReason: "Turn on Show icons first."
            description: "Puts a launcher for it on the desktop. Launchers that arrive any other way ask before they run the first time."
            showDivider: false

            M3Button {
                text: "Choose\u2026"
                variant: "tonal"
                enabled: Prefs.desktopIcons
                onClicked: Prefs.appPickerRequested("::desktop")
            }

        }

    }

    SettingCard {
        title: "SCREENSHOTS"

        SettingRow {
            title: "After a capture"
            resetKey: "shotPreview"
            description: Prefs.shotPreview === "preview" ? "A card in the corner shows it, to open, mark up, drag into an app, find in its folder or delete. Recordings get one too." : (Prefs.shotPreview === "notify" ? "A notification says where it went. Screenshots are on the clipboard either way." : "Nothing shows. Screenshots are still copied to the clipboard.")

            M3Segmented {
                width: Math.max(Theme.dp(300), fitWidth)
                current: Prefs.shotPreview
                options: [{
                    "key": "preview",
                    "label": "Preview"
                }, {
                    "key": "notify",
                    "label": "Notification"
                }, {
                    "key": "none",
                    "label": "Nothing"
                }]
                onChosen: (key) => {
                    return Prefs.shotPreview = key;
                }
            }

        }

        SettingRow {
            title: "Preview stays for"
            resetKey: "shotPreviewSeconds"
            enabled: Prefs.shotPreview === "preview"
            description: "Resting the pointer on the card holds it for as long as you like."
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                enabled: Prefs.shotPreview === "preview"
                from: 3
                to: 20
                stepSize: 1
                suffix: " s"
                value: Prefs.shotPreviewSeconds
                onMoved: (v) => {
                    return Prefs.shotPreviewSeconds = v;
                }
            }

        }

    }

    SettingCard {
        title: "ON-SCREEN DISPLAY"

        SettingRow {
            title: "OSD style"
            resetKey: "osdStyle"
            description: "Where volume, brightness and lock-key changes show up. Islands float above the bottom edge; Notches rise out of it, with the dock's curved corners at their sides."

            M3Segmented {
                width: Theme.dp(260)
                current: Prefs.osdStyle
                options: [{
                    "key": "island",
                    "label": "Islands"
                }, {
                    "key": "notch",
                    "label": "Notches"
                }]
                onChosen: (key) => {
                    return Prefs.osdStyle = key;
                }
            }

        }

        SettingRow {
            title: "Caps Lock"
            resetKey: "osdCapsLock"
            description: Prefs.osdCapsLock ? "A card shows ABC or abc as Caps Lock goes on or off." : "Caps Lock changes without a card. Its sound has a switch of its own in Sound."

            M3Switch {
                checked: Prefs.osdCapsLock
                onToggled: (v) => {
                    Prefs.osdCapsLock = v;
                }
            }

        }

        SettingRow {
            title: "Num Lock"
            resetKey: "osdNumLock"
            description: Prefs.osdNumLock ? "A card shows 123 or arrows as Num Lock goes on or off." : "Num Lock changes without a card."
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
