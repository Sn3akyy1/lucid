import QtQuick
import Quickshell
import Quickshell.Io
import qs

Column {
    id: page

    // the map is drawn over this
    property string wallpaper: ""

    spacing: Theme.dp(26)
    // the header switch turns the whole layer off, so the page has nothing left to set
    enabled: Prefs.widgetsEnabled
    opacity: Prefs.widgetsEnabled ? 1 : 0.38

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

    FileView {
        path: Quickshell.env("HOME") + "/.cache/current_wallpaper"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: page.wallpaper = text().trim()
    }

    WidgetsMap {
        width: parent.width
        wallpaper: page.wallpaper
    }

    SettingCard {
        title: I18n.tr("ON THE DESKTOP")

        SettingRow {
            title: I18n.tr("Widget panel")
            description: I18n.tr("Every widget there is, to drag out onto the desktop or click in, the ones already out there, and layouts to start from or save. It's part of edit mode, under Widgets in its toolbar.")
            showDivider: false

            M3Button {
                text: I18n.tr("Open the panel")
                variant: "tonal"
                iconPath: "widgets"
                onClicked: {
                    Edit.enterFromSettings("widgets", "");
                    Widgets.openPanel(Monitors.mainScreen ? Monitors.mainScreen.name : "");
                }
            }

        }

        SettingRow {
            title: I18n.tr("Edit mode")
            description: I18n.tr("The desktop shades over and everything on it can be moved: widgets, the bar's modules and the dock. Right-click anything for its options.")
            showDivider: false

            M3Button {
                text: I18n.tr("Edit the desktop")
                variant: "tonal"
                iconPath: "edit"
                onClicked: Edit.enterFromSettings("widgets", "")
            }

        }

    }

    SettingCard {
        title: I18n.tr("BEHAVIOUR")

        SettingRow {
            title: I18n.tr("Snap while dragging")
            resetKey: "widgetSnap"
            description: I18n.tr("Widgets catch on the screen's edges and centre lines, and line up with each other, so a hand-placed arrangement still looks deliberate.")

            M3Switch {
                checked: Prefs.widgetSnap
                onToggled: (v) => {
                    return Prefs.widgetSnap = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Pin everything")
            resetKey: "widgetLockAll"
            description: I18n.tr("Locks every widget where it stands, including the ones that are not individually pinned. Useful once the layout is settled.")

            M3Switch {
                checked: Prefs.widgetLockAll
                onToggled: (v) => {
                    return Prefs.widgetLockAll = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Keep above windows")
            resetKey: "widgetOnTop"
            description: I18n.tr("Off, widgets live on the desktop and windows cover them. On, they float over everything - handy for a clock or a timer you always want in sight.")

            M3Switch {
                checked: Prefs.widgetOnTop
                onToggled: (v) => {
                    return Prefs.widgetOnTop = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Hide for fullscreen windows")
            resetKey: "widgetHideFullscreen"
            description: I18n.tr("Widgets step out of the way while something is running fullscreen, and come back when it is not.")
            showDivider: false

            M3Switch {
                checked: Prefs.widgetHideFullscreen
                onToggled: (v) => {
                    return Prefs.widgetHideFullscreen = v;
                }
            }

        }

    }

}
