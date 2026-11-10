import QtQuick
import qs
import qs.lucidprefs

// the top of the dock's sheet: whether it shows at all, and the launcher opened out
// of it to see it with what is set below
SettingCard {
    SettingRow {
        title: "Show the dock"
        description: Prefs.surfaceLocked("dockEnabled") ? "Off while the bar is on the bottom edge. It comes back when the bar moves to the top." : (Prefs.dockEnabled ? "Off, the dock goes, and the launcher opens from the bottom edge on its own." : "The dock is switched off.")
        showDivider: false

        M3Switch {
            enabled: !Prefs.surfaceLocked("dockEnabled")
            checked: Prefs.dockEnabled
            onToggled: (v) => {
                return Prefs.setSurface("dockEnabled", v);
            }
        }

    }

    SettingRow {
        title: "Try the launcher"
        description: "Opens it out of the dock, so you can see it with the style and sizes below."
        showDivider: false

        M3Button {
            text: "Open"
            variant: "tonal"
            onClicked: Edit.launcherRequested()
        }

    }

    SettingRow {
        title: "Move it"
        description: "On the desktop, drag the handle above the dock up to float it higher, or down into the bottom edge to make it a notch."
        enabled: Prefs.dockEnabled
        showDivider: false
    }

}
