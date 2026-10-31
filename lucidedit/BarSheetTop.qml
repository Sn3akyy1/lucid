import QtQuick
import qs
import qs.lucidprefs

// the top of the bar's sheet: whether the bar shows at all, and every module with
// its switch and a way into its own sheet
Column {
    id: sheetTop

    // where a module sits, in words
    function placeOf(m) {
        if (Prefs[m.key] !== true)
            return "Not in the bar.";

        const zone = Prefs.barZoneOf(m.id);
        const where = zone === "centre" ? "In the middle." : (zone === "right" ? "On the right." : "On the left.");
        if (m.when && Prefs.barModulesAway.indexOf(m.id) !== -1)
            return where + " Hidden for now: it shows " + m.when + ".";

        return where;
    }

    spacing: Theme.dp(26)

    SettingCard {
        width: parent.width

        SettingRow {
            title: "Show the bar"
            description: Prefs.barEnabled ? "Off, the bar and everything on it goes, and windows take its space." : "The bar is switched off."
            showDivider: false

            M3Switch {
                checked: Prefs.barEnabled
                onToggled: (v) => {
                    return Prefs.setSurface("barEnabled", v);
                }
            }

        }

    }

    SettingCard {
        width: parent.width
        title: "MODULES"
        subtitle: "On the bar itself, drag a module to move it, or pull it down off the bar to take it out. The link between two neighbours joins them."
        visible: Prefs.barEnabled

        Repeater {
            model: Prefs.barModules

            SettingRow {
                id: modRow

                required property var modelData

                title: modRow.modelData.name
                description: sheetTop.placeOf(modRow.modelData)
                showDivider: false

                Row {
                    spacing: Theme.dp(4)

                    M3Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Prefs[modRow.modelData.key] === true
                        onToggled: (v) => {
                            return Prefs.setBarModuleShown(modRow.modelData.id, v);
                        }
                    }

                    M3IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.dp(36)
                        iconPath: "chevron_right"
                        onClicked: Edit.openSheet("module", modRow.modelData.id, "", Edit.sheetScreen)
                    }

                }

            }

        }

        SettingRow {
            title: "Start over"
            description: "Every module goes back where it ships, switched on or off the way it ships, and every join comes apart. Undo on the toolbar takes it back."
            showDivider: false

            M3Button {
                text: "Reset"
                variant: "text"
                destructive: true
                onClicked: Prefs.setBarDefaults()
            }

        }

    }

}
