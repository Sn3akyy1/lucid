import QtQuick
import qs
import qs.lucidprefs

// the top of the dock's sheet: whether it shows at all, and the launcher opened out
// of it to see it with what is set below
SettingCard {
    SettingRow {
        title: I18n.tr("Show the dock")
        description: Prefs.surfaceLocked("dockEnabled") ? I18n.tr("Off while the bar is on the bottom edge. It comes back when the bar moves to the top.") : (Prefs.dockEnabled ? I18n.tr("Off, the dock goes, and the launcher opens from the bottom edge on its own.") : I18n.tr("The dock is switched off."))
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
        title: I18n.tr("Try the launcher")
        description: I18n.tr("Opens it out of the dock, so you can see it with the style and sizes below.")
        showDivider: false

        M3Button {
            text: I18n.tr("Open")
            variant: "tonal"
            onClicked: Edit.launcherRequested()
        }

    }

    SettingRow {
        title: I18n.tr("Move it")
        description: I18n.tr("On the desktop, drag the handle above the dock up to float it higher, or down into the bottom edge to make it a notch.")
        enabled: Prefs.dockEnabled
        showDivider: false
    }

}
